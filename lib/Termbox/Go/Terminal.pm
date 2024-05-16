# ------------------------------------------------------------------------
#
#   Terminal Termbox implementation
#
#   Code based on termbox-go v1.1.1, 21 April 2021
#
#   Copyright (C) 2012 termbox-go authors
#
# ------------------------------------------------------------------------
#   Author: 2024 J. Schneider
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
our $VERSION = version->declare('v0.2.0_0');

# authority '...'
our $authority = 'github:nsf';
our $AUTHORITY = 'github:brickpool';

# ------------------------------------------------------------------------
# Imports ----------------------------------------------------------------
# ------------------------------------------------------------------------

use Carp qw( croak );
use English qw( -no_match_vars );
use Fcntl;
use IO::File;
use Params::Util qw(
  _STRING
  _INVOCANT
  _NUMBER
  _NONNEGINT
);
use POSIX qw(
  :errno_h
  :termios_h
  !tcsetattr
  !tcgetattr
);
use threads;
use threads::shared;
use Thread::Queue;

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

  $out = IO::File->new() or return $!+0;
  if ($OSNAME eq "openbsd" || $OSNAME eq "freebsd") {
    $err = $out->open("/dev/tty", O_RDWR, 0) ? 0 : $!+0;
    if ($err != 0) {
      return $err;
    }
    $in = fileno($out);
  } else {
    $err = $out->open("/dev/tty", O_WRONLY, 0) ? 0 : $!+0;
    if ($err != 0) {
      return $err;
    }
    $in = POSIX::open("/dev/tty", &POSIX::O_RDONLY, 0);
    $err = $!+0;
    if ($err != 0) {
      return $err;
    }
  }
  $out->binmode(':raw');

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
    lock($sigwinch); 
    my $n = $sigwinch->pending();
    $sigwinch->enqueue(TRUE) if defined($n) && $n == 0;
  };

  if ($^O eq 'MSWin32') {
    # https://stackoverflow.com/a/73571717
    # https://metacpan.org/pod/Win32::PowerShell::IPC#PeekNamedPipe

    threads->create(sub {
      eval {
        require Win32;
        require Win32::API;
        require Win32API::File;
      } or return;
      my $peek_named_pipe = Win32::API->new("kernel32", 'PeekNamedPipe', 
        'NPIPPP', 'N') or return;
      my $hInput = Win32API::File::FdGetOsFHandle($in);
      if (!$hInput || $hInput == Win32API::File::INVALID_HANDLE_VALUE()) {
        return;
      }
      my $uFileType = Win32API::File::GetFileType($hInput);
      for (;;) {
        my $bytesAvailable = 0;
        switch: for ($uFileType) {
          case: $_ == Win32API::File::FILE_TYPE_DISK() and do {
            # ReadFile($hFile, $opBuffer, $lBytes, $olBytesRead, $pOverlapped)
            last;
          };
          case: $_ == Win32API::File::FILE_TYPE_PIPE() and do {
            # PeekNamedPipe(hInput, NULL, NULL, NULL, &bytesAvailable, NULL)
            my $lpTotalBytesAvail = pack('L', 0);
            $peek_named_pipe->Call($hInput, undef, 0, undef, $lpTotalBytesAvail, undef)
              or return;
            $bytesAvailable = unpack('L', $lpTotalBytesAvail);
            last;
          };
          default: {
            return;
          }
        }
        if ($bytesAvailable > 0) {
          lock($sigio); 
          my $n = $sigio->pending();
          $sigwinch->enqueue(TRUE) if defined($n) && $n == 0;
        } else {
          # nothing to read
          Win32::Sleep(20);
        }
      }
    })->detach();

  } else {

    $SIG{'IO'} = sub {
      lock($sigio); 
      my $n = $sigio->pending();
      $sigwinch->enqueue(TRUE) if defined($n) && $n == 0;
    };

  }

  my $in_fh = IO::File->new_from_fd($in, 'r') or return $!+0;
  $err = fcntl($in_fh, F_SETFL, O_ASYNC|O_NONBLOCK) ? 0 : $!+0;
  if ($err != 0) {
    return $err;
  }
  $err = fcntl($in_fh, F_SETOWN, $PID) ? 0 : $!+0;
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

  $out->print($funcs->[t_enter_ca]);
  $out->print($funcs->[t_enter_keypad]);
  $out->print($funcs->[t_hide_cursor]);
  $out->print($funcs->[t_clear_screen]);

  ($termw, $termh) = get_term_size($outfd);
  $back_buffer->init($termw, $termh);
  $front_buffer->init($termw, $termh);
  $back_buffer->clear();
  $front_buffer->clear();

  threads->create(sub {
    use bytes;
    my $buf = "\0" x 128;
    my $ie;
    for (;;) {
      select: {
        case: $sigio->dequeue_nb() and do {
          for (;;) {
            my $n = POSIX::read($in, $buf, 128) // 0;
            my $err = $!+0;
            if ($err == EAGAIN || $err == EWOULDBLOCK) {
              last;
            }
            select: {
              case: ($ie = input_event(substr($buf, 0, $n), $err)) and do {
                lock $input_comm;
                $input_comm->enqueue($ie);
                substr($buf, $n, 128) = "\0" x 128;
              };
              case: $quit->dequeue_nb() and do {
                return;
              };
            }
          }
        };
        case: $quit->dequeue_nb() and do {
          return;
        };
      }
    }
  })->detach();

  $IsInit = TRUE;
  return 0;
}

# Interrupt an in-progress call to PollEvent by causing it to return
# EventInterrupt.  Note that this function will block until the PollEvent
# function has successfully been interrupted.
sub Interrupt { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  lock $interrupt_comm;
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
  $out->print($funcs->[t_show_cursor]);
  $out->print($funcs->[t_sgr0]);
  $out->print($funcs->[t_clear_screen]);
  $out->print($funcs->[t_exit_ca]);
  $out->print($funcs->[t_exit_keypad]);
  $out->print($funcs->[t_exit_mouse]);
  tcsetattr($outfd, $orig_tios);

  $out->close();
  POSIX::close($in);

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
  $SIG{'WINCH'} = $SIG{'IO'} = 'DEFAULT';
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
      my $ch = utf8::upgrade(chr($back->{Ch}));
      if ($w <= 0 || $w == 2 && $ch =~ /\p{InEastAsianAmbiguous}/) {
        $w = 1;
      }
      if ( $back->{Ch} != $front->{Ch}
        || $back->{Fg} != $front->{Fg}
        || $back->{Bg} != $front->{Bg}
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

  return 0;
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

  return 0;
}

# The shortcut for SetCursor(-1, -1).
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

  if ($x < 0 || $x >= $back_buffer->{width}) {
    return $! = (EINVAL, EOVERFLOW)[$x < 0];
  }
  if ($y < 0 || $y >= $back_buffer->{height}) {
    return $! = (EINVAL, EOVERFLOW)[$y < 0];
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

  if ($x < 0 || $x >= $back_buffer->{width}) {
    return $! = (EINVAL, EOVERFLOW)[$x < 0];
  }
  if ($y < 0 || $y >= $back_buffer->{height}) {
    return $! = (EINVAL, EOVERFLOW)[$y < 0];
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

  if ($x < 0 || $x >= $back_buffer->{width}) {
    return $! = (EINVAL, EOVERFLOW)[$x < 0];
  }
  if ($y < 0 || $y >= $back_buffer->{height}) {
    return $! = (EINVAL, EOVERFLOW)[$y < 0];
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

  if ($x < 0 || $x >= $back_buffer->{width}) {
    return $! = (EINVAL, EOVERFLOW)[$x < 0];
  }
  if ($y < 0 || $y >= $back_buffer->{height}) {
    return $! = (EINVAL, EOVERFLOW)[$y < 0];
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

# Wait for an event and return it. This is a blocking function call.
sub PollEvent { # \%Event ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  return;
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
# visually pretty though. At the moment on Windows it does nothing.
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

=item * 2024 by J. Schneider L<https://github.com/brickpool/>

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

=head1 SEE ALSO

L<Go termbox implementation|http://godoc.org/github.com/nsf/termbox-go>

=cut
