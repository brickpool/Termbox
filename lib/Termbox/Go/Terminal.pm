# ------------------------------------------------------------------------
#
#   Terminal Termbox implementation
#
#   Code based on termbox-go v1.1.1, 21 April 2021
#
#   Copyright (C) 2012 termbox-go authors
#
# ------------------------------------------------------------------------
#   Author: 2024,2025 J. Schneider
# ------------------------------------------------------------------------

package Termbox::Go::Terminal;

# ------------------------------------------------------------------------
# Boilerplate ------------------------------------------------------------
# ------------------------------------------------------------------------

use 5.014;
use strict;
use warnings;

# version '...'
use version;
our $version = version->declare('v1.1.1');
our $VERSION = version->declare('v0.3.0_3');

# authority '...'
our $authority = 'github:nsf';
our $AUTHORITY = 'github:brickpool';

# ------------------------------------------------------------------------
# Imports ----------------------------------------------------------------
# ------------------------------------------------------------------------

require bytes; # not use, see https://perldoc.perl.org/bytes
use Carp qw( croak );
use English qw( -no_match_vars );
use Fcntl;
use Params::Util qw(
  _STRING
  _INVOCANT
  _NUMBER
  _NONNEGINT
  _SCALAR0
);
use POSIX qw(
  :errno_h
  :termios_h
  !tcsetattr
  !tcgetattr
);
use threads;
use threads::shared;
use Thread::Queue 3.07;
use Time::HiRes ();
use Unicode::EastAsianWidth;

use Termbox::Go::Common qw(
  :all
  !:keys
  !:mode
  !:attr
);
use Termbox::Go::Devel qw(
  __FUNCTION__
  usage
);
use Termbox::Go::Terminal::Backend qw( :all );
use Termbox::Go::Terminfo qw( :func );
use Termbox::Go::Terminfo::Builtin qw( :index );
use Termbox::Go::WCWidth qw( wcwidth );

# ------------------------------------------------------------------------
# Exports ----------------------------------------------------------------
# ------------------------------------------------------------------------

=head1 EXPORTS

Nothing per default, but can export the following per request:

  :all

    :api
      Init
      Close
      Interrupt
      Flush
      SetCursor
      HideCursor
      SetCell
      GetCell
      SetChar
      SetFg
      SetBg
      CellBuffer
      ParseEvent
      PollRawEvent
      PollEvent
      Size
      Clear
      SetInputMode
      SetOutputMode
      Sync

=cut

use Exporter qw( import );

our @EXPORT_OK = qw(
);

our %EXPORT_TAGS = (

  api => [qw(
    Init
    Close
    Interrupt
    Flush
    SetCursor
    HideCursor
    SetCell
    GetCell
    SetChar
    SetFg
    SetBg
    CellBuffer
    ParseEvent
    PollRawEvent
    PollEvent
    Size
    Clear
    SetInputMode
    SetOutputMode
    Sync
  )],

);

# add all the other %EXPORT_TAGS ":class" tags to the ":all" class and
# @EXPORT_OK, deleting duplicates
{
  my %seen;
  push
    @EXPORT_OK,
      grep {!$seen{$_}++} @{$EXPORT_TAGS{$_}}
        foreach keys %EXPORT_TAGS;
  push
    @{$EXPORT_TAGS{all}},
      @EXPORT_OK;
}

# ------------------------------------------------------------------------
# Constants --------------------------------------------------------------
# ------------------------------------------------------------------------

# Error Codes
use if !exists(&POSIX::EOVERFLOW), 'constant', EOVERFLOW => 79;

# ------------------------------------------------------------------------
# Functions --------------------------------------------------------------
# ------------------------------------------------------------------------

# Initializes termbox library. This function should be called before any other 
# functions. After successful initialization, the library must be finalized 
# using L</Close> function.
#
# Example usage:
#
#  my $err = Init();
#  if ($err != 0) {
#    die "Error: $err"
#  }
#  Close();
#
sub Init { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  if ($IsInit) {
    return 0;
  }

  my $err;

  use open IO => ':raw'; # https://github.com/Perl/perl5/issues/17665
  if ($OSNAME eq "openbsd" || $OSNAME eq "freebsd") {
    $err = sysopen($out, "/dev/tty", O_RDWR, 0) ? 0 : $!+0;
    if ($err != 0) {
      return $err;
    }
    *IN = $out;
    $in = fileno($out);
  } else {
    $err = sysopen($out, "/dev/tty", O_WRONLY, 0) ? 0 : $!+0;
    if ($err != 0) {
      return $err;
    }
    $err = sysopen(IN, "/dev/tty", O_RDONLY, 0) ? 0 : $!+0;
    $err = $!+0;
    if ($err != 0) {
      return $err;
    }
    $in = fileno(\*IN);
  }

  # Note: the following statement was not verified when porting to perl
  #
  # fileno clears the O_NONBLOCK flag. On systems where in and out are the
  # same file descriptor (see above), that would be a problem, because
  # the in file descriptor needs to be nonblocking. Save the fileno return
  # value here so that we won't need to call fileno later after the in file
  # descriptor has been made nonblocking (see below).
  $outfd = fileno($out);

  $err = setup_term() ? 0 : $!+0;
  if ($err != 0) {
    $@ = sprintf("termbox: error while reading terminfo data: %s", $!);
    return $err;
  }

  $SIG{'WINCH'} = sub {
    $sigwinch->pending() or $sigwinch->enqueue(TRUE);
  };
  $SIG{'IO'} = sub {
    $sigio->pending() or $sigio->enqueue(TRUE);
  };

  $err = fcntl(IN, F_SETFL, O_ASYNC|O_NONBLOCK) ? 0 : $!+0;
  if ($err != 0) {
    return $err;
  }
  $err = fcntl(IN, F_SETOWN, $PID) ? 0 : $!+0;
  if ($OSNAME ne "darwin" && $err != 0) {
    return $err;
  }

  $err = tcgetattr($outfd, $orig_tios);
  if ($err != 0) {
    return $err;
  }

  my $tios = { %$orig_tios };
  $tios->{Iflag} &= ~(IGNBRK | BRKINT | PARMRK |
    ISTRIP | INLCR | IGNCR | ICRNL | IXON);
  $tios->{Lflag} &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
  $tios->{Cflag} &= ~(CSIZE | PARENB);
  $tios->{Cflag} |= CS8;
  $tios->{Cc}->[VMIN] = 1;
  $tios->{Cc}->[VTIME] = 0;

  $err = tcsetattr($outfd, $tios);
  if ($err != 0) {
    return $err;
  }

  syswrite($out, $funcs->[t_enter_ca]);
  syswrite($out, $funcs->[t_enter_keypad]);
  syswrite($out, $funcs->[t_hide_cursor]);
  syswrite($out, $funcs->[t_clear_screen]);

  ($termw, $termh) = get_term_size($outfd);
  $back_buffer->init($termw, $termh);
  $front_buffer->init($termw, $termh);
  $back_buffer->clear();
  # Do not clear the front buffer to avoid artifacts.
  # $front_buffer->clear();

  threads->create(sub {
    use bytes;
    my $buf = "\0" x 128;
    for (;;) {
      select: {
        case: $sigio->dequeue_nb() and do {
          for (;;) {
            my $n = sysread(IN, $buf, 128) // 0;
            my $err = $!+0;
            if ($err == EAGAIN || $err == EWOULDBLOCK) {
              last;
            }
            select: {
              my $ie;
              case: ($ie = input_event(substr($buf, 0, $n), $err)) and do {
                $input_comm->enqueue($ie);
                substr($buf, $n, 128) = "\0" x 128;
              };
              case: $quit->dequeue_nb() and do {
                return 0;
              };
            }
          }
        };
        case: $quit->dequeue_nb() and do {
          return 0;
        };
      }
    }
  })->detach();

  $IsInit = TRUE;
  return 0;
}

# Interrupt an in-progress call to L</PollEvent> by causing it to return
# EventInterrupt.  Note that this function will block until the L</PollEvent>
# function has successfully been interrupted.
sub Interrupt { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  $interrupt_comm->enqueue({});
  return 0;
}

# Finalizes termbox library, should be called after successful initialization 
# when termbox's functionality isn't required anymore.
sub Close { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  if (!$IsInit) {
    return $! = EBADF;
  }

  $quit->enqueue(1);
  syswrite($out, $funcs->[t_show_cursor]);
  syswrite($out, $funcs->[t_sgr0]);
  syswrite($out, $funcs->[t_clear_screen]);
  syswrite($out, $funcs->[t_exit_ca]);
  syswrite($out, $funcs->[t_exit_keypad]);
  syswrite($out, $funcs->[t_exit_mouse]);
  tcsetattr($outfd, $orig_tios);

  $SIG{'WINCH'} = 'DEFAULT';
  $SIG{'IO'} = 'DEFAULT';

  close($out);
  close(IN);

  # reset the state, so that on next Init() it will work again
  $termw = 0;
  $termh = 0;
  $input_mode = InputEsc;
  $out = undef;
  $in = 0;
  $lastfg = attr_invalid;
  $lastbg = attr_invalid;
  $lastx = coord_invalid;
  $lasty = coord_invalid;
  $cursor_x = cursor_hidden;
  $cursor_y = cursor_hidden;
  $foreground = ColorDefault;
  $background = ColorDefault;
  $IsInit = FALSE;
  return 0;
}

# Synchronizes the internal back buffer with the terminal.
sub Flush { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  # invalidate cursor position
  $lastx = coord_invalid;
  $lasty = coord_invalid;

  update_size_maybe();

  for (my $y = 0; $y < $front_buffer->{height}; $y++) {
    my $line_offset = $y * $front_buffer->{width};
    for (my $x = 0; $x < $front_buffer->{width}; ) {
      my $cell_offset = $line_offset + $x;
      my $back = $back_buffer->{cells}->[$cell_offset];
      my $front = $front_buffer->{cells}->[$cell_offset];
      if ($back->{Ch} < ord(' ')) {
        $back->{Ch} = ord(' ');
      }
      my $w = wcwidth($back->{Ch});
      my $ch = chr($back->{Ch});
      utf8::upgrade($ch);
      if ($w <= 0 || $w == 2 && $ch =~ /\p{InEastAsianAmbiguous}/) {
        $w = 1;
      }
      if ( $back->{Ch} == $front->{Ch}
        && $back->{Fg} == $front->{Fg}
        && $back->{Bg} == $front->{Bg}
      ) {
        $x += $w;
        next;
      }
      $front = { %$back };
      send_attr($back->{Fg}, $back->{Bg});

      if ($w == 2 && $x == $front_buffer->{width} - 1) {
        # there's not enough space for 2-cells unicode,
        # let's just put a space in there
        send_char($x, $y, ' ');
      } else {
        send_char($x, $y, $ch);
        if ($w == 2) {
          my $next = $cell_offset + 1;
          $front_buffer->{cells}->[$next] = Cell{
            Ch => 0,
            Fg => $back->{Fg},
            Bg => $back->{Bg},
          };
        }
      }
      $x += $w;
    }
  }
  if (!is_cursor_hidden($cursor_x, $cursor_y)) {
    write_cursor($cursor_x, $cursor_y);
  }
  return flush() ? $!+0 : 0;
}

# Sets the position of the cursor. See also L</HideCursor>.
sub SetCursor { # $errno ($x, $y)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my ($x, $y) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                ? EINVAL
        : @_ > 2                ? E2BIG
        : !defined(_NUMBER($x)) ? EINVAL
        : !defined(_NUMBER($y)) ? EINVAL
        : undef
        ;

  if (is_cursor_hidden($cursor_x, $cursor_y) && !is_cursor_hidden($x, $y)) {
    $outbuf->print($funcs->[t_show_cursor]);
  }

  if (!is_cursor_hidden($cursor_x, $cursor_y) && is_cursor_hidden($x, $y)) {
    $outbuf->print($funcs->[t_hide_cursor]);
  }

  ($cursor_x, $cursor_y) = ($x, $y);
  if (!is_cursor_hidden($cursor_x, $cursor_y)) {
    write_cursor($cursor_x, $cursor_y)
  }
  return 0;
}

# The shortcut for L<SetCursor(-1, -1)|/SetCursor>.
sub HideCursor { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  return SetCursor(cursor_hidden, cursor_hidden);
}

# Changes cell's parameters in the internal back buffer at the specified
# position.
sub SetCell { # $errno ($x, $y, $ch, $fg, $bg)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my ($x, $y, $ch, $fg, $bg) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 5                    ? EINVAL
        : @_ > 5                    ? E2BIG
        : !defined(_NONNEGINT($x))  ? EINVAL
        : !defined(_NONNEGINT($y))  ? EINVAL
        : !defined(_STRING($ch))    ? EINVAL
        : !defined(_NONNEGINT($fg)) ? EINVAL
        : !defined(_NONNEGINT($bg)) ? EINVAL
        : undef
        ;

  if ($x >= $back_buffer->{width}) {
    return $! = EOVERFLOW;
  }
  if ($y >= $back_buffer->{height}) {
    return $! = EOVERFLOW;
  }

  $back_buffer->{cells}->[$y*$back_buffer->{width} + $x] 
    = Cell(ord($ch), $fg, $bg);
  return 0;
}

# Returns the specified cell from the internal back buffer.
sub GetCell { # \%Cell ($x, $y)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my ($x, $y) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                    ? EINVAL
        : @_ > 2                    ? E2BIG
        : !defined(_NONNEGINT($x))  ? EINVAL
        : !defined(_NONNEGINT($y))  ? EINVAL
        : undef
        ;

  return { %{$back_buffer->{cells}->[$y*$back_buffer->{width} + $x]} };
}

# Changes cell's character (utf8) in the internal back buffer at 
# the specified position.
sub SetChar { # $errno ($x, $y, $ch)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my ($x, $y, $ch) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 3                    ? EINVAL
        : @_ > 3                    ? E2BIG
        : !defined(_NONNEGINT($x))  ? EINVAL
        : !defined(_NONNEGINT($y))  ? EINVAL
        : !defined(_STRING($ch))    ? EINVAL
        : undef
        ;

  if ($x >= $back_buffer->{width}) {
    return $! = EOVERFLOW;
  }
  if ($y >= $back_buffer->{height}) {
    return $! = EOVERFLOW;
  }

  $back_buffer->{cells}->[$y*$back_buffer->{width} + $x]->{Ch} = ord($ch);
  return 0;
}

# Changes cell's foreground attributes in the internal back buffer at
# the specified position.
sub SetFg { # $errno ($x, $y, $fg)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my ($x, $y, $fg) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 3                    ? EINVAL
        : @_ > 3                    ? E2BIG
        : !defined(_NONNEGINT($x))  ? EINVAL
        : !defined(_NONNEGINT($y))  ? EINVAL
        : !defined(_NONNEGINT($fg)) ? EINVAL
        : undef
        ;

  if ($x >= $back_buffer->{width}) {
    return $! = EOVERFLOW;
  }
  if ($y >= $back_buffer->{height}) {
    return $! = EOVERFLOW;
  }

  $back_buffer->{cells}->[$y*$back_buffer->{width} + $x]->{Fg} = $fg;
  return 0;
}

# Changes cell's background attributes in the internal back buffer at
# the specified position.
sub SetBg { # $errno ($x, $y, $bg)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my ($x, $y, $bg) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 3                    ? EINVAL
        : @_ > 3                    ? E2BIG
        : !defined(_NONNEGINT($x))  ? EINVAL
        : !defined(_NONNEGINT($y))  ? EINVAL
        : !defined(_NONNEGINT($bg)) ? EINVAL
        : undef
        ;

  if ($x >= $back_buffer->{width}) {
    return $! = EOVERFLOW;
  }
  if ($y >= $back_buffer->{height}) {
    return $! = EOVERFLOW;
  }

  $back_buffer->{cells}->[$y*$back_buffer->{width} + $x]->{Bg} = $bg;
  return 0;
}

# Returns a slice into the termbox's back buffer. You can get its dimensions
# using L</Size> function. The slice remains valid as long as no L</Clear> or
# L</Flush> function calls were made after call to this function.
sub CellBuffer { # \@ ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  return $back_buffer->{cells};
}

# After getting a raw event from PollRawEvent function call, you can parse it
# again into an ordinary one using termbox logic. That is parse an event as
# termbox would do it. Returned event in addition to usual Event struct fields
# sets N field to the amount of bytes used within C<data> slice. If the length
# of C<data> slice is zero or event cannot be parsed for some other reason, the
# function will return a special event type: EventNone.
#
# B<IMPORTANT>: EventNone may contain a non-zero N, which means you should skip
# these bytes, because termbox cannot recognize them.
#
# B<NOTE>: This API is experimental and may change in future.
sub ParseEvent { # \%event ($data)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my $data = \$_[0];
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                    ? EINVAL
        : @_ > 1                    ? E2BIG
        : !defined(_SCALAR0($data)) ? EINVAL
        : undef
        ;

  my $event = Event{Type => EventKey};
  my $status = extract_event($data, $event, FALSE);
  if ($status != event_extracted) {
    return Event{Type => EventNone, N => $event->{N}};
  }
  return $event;
}

# Wait for an event and return it. This is a blocking function call. Instead
# of EventKey and EventMouse it returns EventRaw events. Raw event is written
# into C<data> slice and Event's N field is set to the amount of bytes written.
# The minimum required length of the C<data> slice is 1. This requirement may
# vary on different platforms.
#
# B<NOTE>: This API is experimental and may change in future.
sub PollRawEvent { # \%event ($data)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my $data = \$_[0];
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                    ? EINVAL
        : @_ > 1                    ? E2BIG
        : !defined(_SCALAR0($data)) ? EINVAL
        : undef
        ;

  if (!length(_STRING($_[0]))) {
    croak('length($data) >= 1 is a requirement');
  }

  my $event = Event();
  if (extract_raw_event($data, $event)) {
    return $event;
  }

  for (;;) {
    select: {
      case: $input_comm->pending() and do {
        my $ev = $input_comm->dequeue();
        if ($ev->{err}) {
          return Event{Type => EventError, Err => $ev->{err}};
        }
        $inbuf .= $ev->{data} // '';
        if (extract_raw_event($data, $event)) {
          return $event;
        }
      };
      case: $interrupt_comm->dequeue_nb() and do {
        $event->{Type} = EventInterrupt;
        return $event;
      };
      case: $sigwinch->dequeue_nb() and do {
        $event->{Type} = EventResize;
        ($event->{Width}, $event->{Height}) = get_term_size($outfd);
        return $event;
      };
    }
  }
}

# Wait for an event and return it. This is a blocking function call.
sub PollEvent { # \%Event ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  # Constant governing macOS specific behavior. See https://github.com/nsf/termbox-go/issues/132
  # This is an arbitrary delay which hopefully will be enough time for any lagging
  # partial escape sequences to come through.
  use constant esc_wait_delay => 100/1000; # 100 ms

  my $event = Event();
  my $esc_timeout = 0;
  my $esc_wait_timer = FALSE;

  # try to extract event from input buffer, return on success
  $event->{Type} = EventKey;
  my $status = extract_event(\$inbuf, $event, TRUE);
  if ($event->{N} != 0) {
    $inbuf = bytes::substr($inbuf, $event->{N});
  }
  if ($status == event_extracted) {
    return $event;
  } elsif ($status == esc_wait) {
    $esc_wait_timer = TRUE;
    $esc_timeout = Time::HiRes::time() + esc_wait_delay;
  }

  for (;;) {
    select: {
      case: $input_comm->pending() and do {
        my $ev = $input_comm->dequeue();
        if ($esc_wait_timer) {
          $esc_wait_timer = FALSE;
        }

        if ($ev->{err}) {
          return Event{Type => EventError, Err => $ev->{err}};
        }

        $inbuf .= $ev->{data} // '';
        $status = extract_event(\$inbuf, $event, TRUE);
        if ($event->{N} != 0) {
          $inbuf = bytes::substr($inbuf, $event->{N});
        }
        if ($status == event_extracted) {
          return $event;
        } elsif ($status == esc_wait) {
          $esc_wait_timer = TRUE;
          $esc_timeout = Time::HiRes::time() + esc_wait_delay;
        }
      };
      case: ($esc_wait_timer && Time::HiRes::time() > $esc_timeout) and do {
        $esc_wait_timer = FALSE;
        $status = extract_event(\$inbuf, $event, FALSE);
        if ($event->{N} != 0) {
          $inbuf = bytes::substr($inbuf, $event->{N});
        }
        if ($status == event_extracted) {
          return $event
        }
      };
      case: $interrupt_comm->dequeue_nb() and do {
        $event->{Type} = EventInterrupt;
        return $event;
      };
      case: $sigwinch->dequeue_nb() and do {
        $event->{Type} = EventResize;
        ($event->{Width}, $event->{Height}) = get_term_size($outfd);
        return $event;
      };
    }
  }
}

# Returns the size of the internal back buffer (which is mostly the same as
# terminal's window size in characters). But it doesn't always match the size
# of the terminal window, after the terminal size has changed, the internal back
# buffer will get in sync only after L</Clear> or L</Flush> function calls.
sub Size { # $x, $y ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  return ($termw, $termh);
}

# Clears the internal back buffer.
sub Clear { # $errno ($fg, $bg)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my ($fg, $bg) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                    ? EINVAL
        : @_ > 2                    ? E2BIG
        : !defined(_NONNEGINT($fg)) ? EINVAL
        : !defined(_NONNEGINT($bg)) ? EINVAL
        : undef
        ;

  ($foreground, $background) = ($fg, $bg);
  my $err = update_size_maybe() ? 0 : $!+0;
  $back_buffer->clear();
  return $err;
}

# Sets termbox input mode. Termbox has two input modes:
#
# 1. Esc input mode. When ESC sequence is in the buffer and it doesn't match
# any known sequence. ESC means 'KeyEsc'. This is the default input mode.
#
# 2. Alt input mode. When ESC sequence is in the buffer and it doesn't match
# any known sequence. ESC enables 'ModAlt' modifier for the next keyboard event.
#
# Both input modes can be OR'ed with Mouse mode. Setting Mouse mode bit up will
# enable mouse button press/release and drag events.
#
# If I<$mode> is 'InputCurrent', returns the current input mode. See also 
# 'Input*' constants.
sub SetInputMode { # $current ($mode)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my ($mode) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                      ? EINVAL
        : @_ > 1                      ? E2BIG
        : !defined(_NONNEGINT($mode)) ? EINVAL
        : undef
        ;

  if ($mode == InputCurrent) {
    return $input_mode;
  }
  if (($mode & (InputEsc | InputAlt)) == 0) {
    $mode |= InputEsc;
  }
  if (($mode & (InputEsc | InputAlt)) == (InputEsc | InputAlt)) {
    $mode &= ~InputAlt;
  }
  if ($mode & InputMouse) {
    syswrite($out, $funcs->[t_enter_mouse]);
  } else {
    syswrite($out, $funcs->[t_exit_mouse]);
  }

  return $input_mode = $mode;
}

# Sets the termbox output mode. Termbox has four output options:
#
# 1. OutputNormal => [1..8]
#    This mode provides 8 different colors:
#        black, red, green, yellow, blue, magenta, cyan, white
#    Shortcut: ColorBlack, ColorRed, ...
#    Attributes: AttrBold, AttrUnderline, AttrReverse
#
#    Example usage:
#        SetCell($x, $y, '@', ColorBlack | AttrBold, ColorRed);
#
# 2. Output256 => [1..256]
#    In this mode you can leverage the 256 terminal mode:
#    0x01 - 0x08: the 8 colors as in OutputNormal
#    0x09 - 0x10: Color* | AttrBold
#    0x11 - 0xe8: 216 different colors
#    0xe9 - 0x1ff: 24 different shades of grey
#
#    Example usage:
#        SetCell($x, $y, '@', 184, 240);
#        SetCell($x, $y, '@', 0xb8, 0xf0);
#
# 3. Output216 => [1..216]
#    This mode supports the 3rd range of the 256 mode only.
#    But you don't need to provide an offset.
#
# 4. OutputGrayscale => [1..26]
#    This mode supports the 4th range of the 256 mode
#    and black and white colors from 3th range of the 256 mode
#    But you don't need to provide an offset.
#
# In all modes, 0x00 represents the default color.
#
# C<perl examples/output.pl> to see its impact on your terminal.
#
# If I<$mode> is 'OutputCurrent', it returns the current output mode.
#
# Note that this may return a different OutputMode than the one requested,
# as the requested mode may not be available on the target platform.
sub SetOutputMode { # $current ($mode)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my ($mode) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                      ? EINVAL
        : @_ > 1                      ? E2BIG
        : !defined(_NONNEGINT($mode)) ? EINVAL
        : undef
        ;

  return $output_mode = $mode;
}

# Sync comes handy when something causes desync between termbox's understanding
# of a terminal buffer and the reality. Such as a third party process. Sync
# forces a complete resync between the termbox and a terminal, it may not be
# visually pretty though. 
sub Sync { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  $front_buffer->clear();
  my $err = send_clear() ? 0 : $!+0;
  if ($err != 0) {
    return $err;
  }

  return Flush();
}

1;

__END__

=head1 NAME

Termbox::Go::Terminal - Terminal Termbox implementation

=head1 DESCRIPTION

This document describes the Termbox library for Perl, for the use of *nix 
terminal applications.

The advantage of the Termbox library is the use of an standard. Termbox
contains a few functions with which terminal applications can be 
developed with high portability and interoperability. 

=head1 COPYRIGHT AND LICENCE

 This file is part of the port of Termbox.
 
 Copyright (C) 2012 by termbox-go authors
 
 This library content was taken from the termbox-go implementation of Termbox
 which is licensed under MIT licence.
 
 Permission is hereby granted, free of charge, to any person obtaining a
 copy of this software and associated documentation files (the "Software"),
 to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense,
 and/or sell copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

=head1 AUTHORS

=over

=item * 2024,2025 by J. Schneider L<https://github.com/brickpool/>

=back

=head1 DISCLAIMER OF WARRANTIES
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 DEALINGS IN THE SOFTWARE.

=head1 REQUIRES

L<5.014|http://metacpan.org/release/DAPM/perl-5.14.4>

L<Params::Util> 

L<Unicode::EastAsianWidth>

=head1 SEE ALSO

L<Go termbox implementation|http://godoc.org/github.com/nsf/termbox-go>

=cut


#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 SUBROUTINES

=head2 CellBuffer

 my \@arrayref = CellBuffer();

Returns a slice into the termbox's back buffer. You can get its dimensions
using L</Size> function. The slice remains valid as long as no L</Clear> or
L</Flush> function calls were made after call to this function.


=head2 Clear

 my $errno = Clear($fg, $bg);

Clears the internal back buffer.


=head2 Close

 my $errno = Close();

Finalizes termbox library, should be called after successful initialization
when termbox's functionality isn't required anymore.


=head2 Flush

 my $errno = Flush();

Synchronizes the internal back buffer with the terminal.


=head2 GetCell

 my \%Cell = GetCell($x, $y);

Returns the specified cell from the internal back buffer.


=head2 HideCursor

 my $errno = HideCursor();

The shortcut for L<SetCursor(-1, -1)|/SetCursor>.


=head2 Init

 my $errno = Init();

Initializes termbox library. This function should be called before any other
functions. After successful initialization, the library must be finalized
using L</Close> function.

Example usage:

 my $err = Init();
 if ($err != 0) {
   die "Error: $err"
 }
 Close();



=head2 Interrupt

 my $errno = Interrupt();

Interrupt an in-progress call to L</PollEvent> by causing it to return
EventInterrupt.  Note that this function will block until the L</PollEvent>
function has successfully been interrupted.


=head2 ParseEvent

 my \%event = ParseEvent($data);

After getting a raw event from PollRawEvent function call, you can parse it
again into an ordinary one using termbox logic. That is parse an event as
termbox would do it. Returned event in addition to usual Event struct fields
sets N field to the amount of bytes used within C<data> slice. If the length
of C<data> slice is zero or event cannot be parsed for some other reason, the
function will return a special event type: EventNone.

B<IMPORTANT>: EventNone may contain a non-zero N, which means you should skip
these bytes, because termbox cannot recognize them.

B<NOTE>: This API is experimental and may change in future.


=head2 PollEvent

 my \%Event = PollEvent();

Wait for an event and return it. This is a blocking function call.


=head2 PollRawEvent

 my \%event = PollRawEvent($data);

Wait for an event and return it. This is a blocking function call. Instead
of EventKey and EventMouse it returns EventRaw events. Raw event is written
into C<data> slice and Event's N field is set to the amount of bytes written.
The minimum required length of the C<data> slice is 1. This requirement may
vary on different platforms.

B<NOTE>: This API is experimental and may change in future.


=head2 SetBg

 my $errno = SetBg($x, $y, $bg);

Changes cell's background attributes in the internal back buffer at
the specified position.


=head2 SetCell

 my $errno = SetCell($x, $y, $ch, $fg, $bg);

Changes cell's parameters in the internal back buffer at the specified
position.


=head2 SetChar

 my $errno = SetChar($x, $y, $ch);

Changes cell's character (utf8) in the internal back buffer at
the specified position.


=head2 SetCursor

 my $errno = SetCursor($x, $y);

Sets the position of the cursor. See also L</HideCursor>.


=head2 SetFg

 my $errno = SetFg($x, $y, $fg);

Changes cell's foreground attributes in the internal back buffer at
the specified position.


=head2 SetInputMode

 my $current = SetInputMode($mode);

Sets termbox input mode. Termbox has two input modes:

1. Esc input mode. When ESC sequence is in the buffer and it doesn't match
any known sequence. ESC means 'KeyEsc'. This is the default input mode.

2. Alt input mode. When ESC sequence is in the buffer and it doesn't match
any known sequence. ESC enables 'ModAlt' modifier for the next keyboard event.

Both input modes can be OR'ed with Mouse mode. Setting Mouse mode bit up will
enable mouse button press/release and drag events.

If I<$mode> is 'InputCurrent', returns the current input mode. See also
'Input*' constants.


=head2 SetOutputMode

 my $current = SetOutputMode($mode);

Sets the termbox output mode. Termbox has four output options:

1. OutputNormal => [1..8]
   This mode provides 8 different colors:
       black, red, green, yellow, blue, magenta, cyan, white
   Shortcut: ColorBlack, ColorRed, ...
   Attributes: AttrBold, AttrUnderline, AttrReverse

   Example usage:
       SetCell($x, $y, '@', ColorBlack | AttrBold, ColorRed);

2. Output256 => [1..256]
   In this mode you can leverage the 256 terminal mode:
   0x01 - 0x08: the 8 colors as in OutputNormal
   0x09 - 0x10: Color* | AttrBold
   0x11 - 0xe8: 216 different colors
   0xe9 - 0x1ff: 24 different shades of grey

   Example usage:
       SetCell($x, $y, '@', 184, 240);
       SetCell($x, $y, '@', 0xb8, 0xf0);

3. Output216 => [1..216]
   This mode supports the 3rd range of the 256 mode only.
   But you don't need to provide an offset.

4. OutputGrayscale => [1..26]
   This mode supports the 4th range of the 256 mode
   and black and white colors from 3th range of the 256 mode
   But you don't need to provide an offset.

In all modes, 0x00 represents the default color.

C<perl examples/output.pl> to see its impact on your terminal.

If I<$mode> is 'OutputCurrent', it returns the current output mode.

Note that this may return a different OutputMode than the one requested,
as the requested mode may not be available on the target platform.


=head2 Size

 my ($x, $y) = Size();

Returns the size of the internal back buffer (which is mostly the same as
terminal's window size in characters). But it doesn't always match the size
of the terminal window, after the terminal size has changed, the internal back
buffer will get in sync only after L</Clear> or L</Flush> function calls.


=head2 Sync

 my $errno = Sync();

Sync comes handy when something causes desync between termbox's understanding
of a terminal buffer and the reality. Such as a third party process. Sync
forces a complete resync between the termbox and a terminal, it may not be
visually pretty though.



=cut

