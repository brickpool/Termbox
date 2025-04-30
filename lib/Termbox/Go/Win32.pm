# ------------------------------------------------------------------------
#
#   Win32 Termbox implementation
#
#   Code based on termbox-go v1.1.1, 21 April 2021
#
#   Copyright (C) 2012 termbox-go authors
#
# ------------------------------------------------------------------------
#   Author: 2024,2025 J. Schneider
# ------------------------------------------------------------------------

package Termbox::Go::Win32;

# ------------------------------------------------------------------------
# Boilerplate ------------------------------------------------------------
# ------------------------------------------------------------------------

use 5.014;
use strict;
use warnings;

# version '...'
use version;
our $version = version->declare('v1.1.1');
our $VERSION = version->declare('v0.3.2');

# authority '...'
our $authority = 'github:nsf';
our $AUTHORITY = 'github:brickpool';

# ------------------------------------------------------------------------
# Imports ----------------------------------------------------------------
# ------------------------------------------------------------------------

use Carp qw( croak );
use Encode;
use Params::Util qw(
  _STRING
  _INVOCANT
  _NUMBER
  _NONNEGINT
);
use POSIX qw( :errno_h );
use threads;
use threads::shared;
use Thread::Queue 3.07;
use Win32API::File;
use Win32::Console;

use Termbox::Go::Common qw(
  :all
  !:keys
  !:mode
  !:color
  !:attr
);
use Termbox::Go::Devel qw(
  __FUNCTION__
  usage
);
use Termbox::Go::WCWidth qw( wcwidth );
use Termbox::Go::Win32::Backend qw( :all );

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

  ($interrupt = create_event())
    or return $! = ECHILD;

  ($in = Win32::Console::_GetStdHandle(STD_INPUT_HANDLE))
    or return $! = EBADF;
  ($out = Win32::Console::_GetStdHandle(STD_OUTPUT_HANDLE))
    or return $! = EBADF;

  get_console_mode($in, \$orig_mode)
    or return $! = ENXIO;

  set_console_mode($in, ENABLE_WINDOW_INPUT)
    or return $! = ENXIO;

  ($orig_size, $orig_window) = get_term_size($out);
  my $win_size = get_win_size($out);

  set_console_screen_buffer_size($out, $win_size)
    or return $! = ENXIO;

  fix_win_size($out, $win_size)
    or return $! = ENXIO;

  get_console_cursor_info($out, $orig_cursor_info)
    or return $! = ENXIO;

  show_cursor(FALSE);
  ($term_size) = get_term_size($out);
  $back_buffer->init($term_size->{x}, $term_size->{y});
  $front_buffer->init($term_size->{x}, $term_size->{y});
  $back_buffer->clear();
  $front_buffer->clear();
  clear();

  $diffbuf = [];

  threads->create(\&input_event_producer)->detach();
  $IsInit = TRUE;
  return 0;
}

# Finalizes termbox library, should be called after successful initialization 
# when termbox's functionality isn't required anymore.
sub Close { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  # we ignore errors here, because we can't really do anything about them
  Clear(0, 0);
  Flush();

  # stop event producer
  $cancel_comm->enqueue(TRUE);
  set_event($interrupt);
  select: {
    case: $input_comm->pending() and do {
      $input_comm->dequeue($input_comm->pending());
      last;
    } 
  }
  $cancel_done_comm->dequeue_timed(2);

  set_console_screen_buffer_size($out, $orig_size);
  set_console_window_info($out, $orig_window);
  set_console_cursor_info($out, $orig_cursor_info);
  set_console_cursor_position($out, coord());
  set_console_mode($in, $orig_mode);
  Win32API::File::CloseHandle($interrupt);
  $IsInit = FALSE;
  return 0;
}

# Interrupt an in-progress call to L</PollEvent> by causing it to return
# EventInterrupt.  Note that this function will block until the L</PollEvent>
# function has successfully been interrupted.
sub Interrupt { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  $input_comm->insert(0, Event{Type => EventInterrupt});
  # $interrupt_comm->enqueue({});
  return 0;
}

# Synchronizes the internal back buffer with the terminal.
sub Flush { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  update_size_maybe();
  prepare_diff_messages();
  foreach my $diff (@$diffbuf) {
    my $chars = '';
    foreach my $char (@{ $diff->{chars} }) {
      # my @utf16 = unpack('S*', Encode::encode('UTF16-LE', chr($char->{char})));
      my @utf16 = ($char->{char});
      if ($char->{char} > 0xffff) {
        @utf16 = (
          ($char->{char} - 0x10000) / 0x400 + 0xD800, 
          ($char->{char} - 0x10000) % 0x400 + 0xDC00
        );
      }
      if (wcwidth($char->{char}) > 1) {
        $chars .= pack('S*', @utf16, $char->{attr} | common_lvb_leading_byte);
        $chars .= pack('S*', @utf16, $char->{attr} | common_lvb_trailing_byte);
      } else {
        $chars .= pack('S*', @utf16, $char->{attr});
      }
    }
    my $r = small_rect{
      left    => 0,
      top     => $diff->{pos},
      right   => $term_size->{x} - 1,
      bottom  => $diff->{pos} + $diff->{lines} - 1,
    };
    write_console_output($out, $chars, $r);
  }
  if (!is_cursor_hidden($cursor_x, $cursor_y)) {
    move_cursor($cursor_x, $cursor_y)
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

  if (is_cursor_hidden($cursor_x, $cursor_y) && !is_cursor_hidden($x, $y)) {
    show_cursor(TRUE);
  }

  if (!is_cursor_hidden($cursor_x, $cursor_y) && is_cursor_hidden($x, $y)) {
    show_cursor(FALSE);
  }

  ($cursor_x, $cursor_y) = ($x, $y);
  if (!is_cursor_hidden($cursor_x, $cursor_y)) {
    move_cursor($cursor_x, $cursor_y)
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
        : !defined(_NUMBER($x))     ? EINVAL
        : $x - int($x)              ? EINVAL
        : !defined(_NUMBER($y))     ? EINVAL
        : $y - int($y)              ? EINVAL
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

# Changes cell's character (length($ch) == 1) in the internal back buffer at 
# the specified position.
sub SetChar { # $errno ($x, $y, $ch)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my ($x, $y, $ch) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 3                  ? EINVAL
        : @_ > 3                  ? E2BIG
        : !defined(_NUMBER($x))     ? EINVAL
        : $x - int($x)              ? EINVAL
        : !defined(_NUMBER($y))     ? EINVAL
        : $y - int($y)              ? EINVAL
        : !defined(_STRING($ch))  ? EINVAL
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
        : !defined(_NUMBER($x))     ? EINVAL
        : $x - int($x)              ? EINVAL
        : !defined(_NUMBER($y))     ? EINVAL
        : $y - int($y)              ? EINVAL
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
        : !defined(_NUMBER($x))     ? EINVAL
        : $x - int($x)              ? EINVAL
        : !defined(_NUMBER($y))     ? EINVAL
        : $y - int($y)              ? EINVAL
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

  select: {
    my $ev;
    case: ($ev = $input_comm->dequeue()) and 
      return { %$ev }; # must be a copy
    q/*
    case: $interrupt_comm->dequeue_nb() and
      return Event{Type => EventInterrupt};
    */ if 0;
  }
  return;
}

# Returns the size of the internal back buffer (which is mostly the same as
# console's window size in characters). But it doesn't always match the size
# of the console window, after the console size has changed, the internal back
# buffer will get in sync only after L</Clear> or L</Flush> function calls.
sub Size { # $x, $y ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  return ($term_size->{x}, $term_size->{y});
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
  update_size_maybe();
  $back_buffer->clear();
  return 0;
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
    lock $input_mode;
    return $input_mode;
  }
  if ($mode & InputMouse) {
    set_console_mode($in, ENABLE_WINDOW_INPUT | ENABLE_MOUSE_INPUT | enable_extended_flags)
      or die $^E;
  } else {
    set_console_mode($in, ENABLE_WINDOW_INPUT)
      or die $^E;
  }

  lock $input_mode;
  return $input_mode = $mode;
}

# Sets the termbox output mode.
#
# As the Windows console only supports additional color modes starting with the 
# Anniversary Update for Windows 10, C<OutputNormal> is always set and returned 
# here.
sub SetOutputMode { # $current ($mode)
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  my ($mode) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                      ? EINVAL
        : @_ > 1                      ? E2BIG
        : !defined(_NONNEGINT($mode)) ? EINVAL
        : undef
        ;

  return OutputNormal;
}

# Sync comes handy when something causes desync between termbox's understanding
# of a terminal buffer and the reality. Such as a third party process. Sync
# forces a complete resync between the termbox and a terminal, it may not be
# visually pretty though. At the moment on Windows it does nothing.
sub Sync { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  return 0;
}

1;

__END__

=head1 NAME

Termbox::Go::Win32 - Win32 Termbox implementation

=head1 DESCRIPTION

This document describes the Termbox library for Perl, for the use of Windows 
console applications.

The advantage of the Termbox library is the use of an standard. Termbox
contains a few functions with which console applications can be 
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

L<Win32API::File> 

L<Win32::Console> 

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

The shortcut for SetCursor(-1, -1).


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


=head2 PollEvent

 my \%Event = PollEvent();

Wait for an event and return it. This is a blocking function call.


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

Changes cell's character (length($ch) == 1) in the internal back buffer at
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

Sets the termbox output mode.

As the Windows console only supports additional color modes starting with the
Anniversary Update for Windows 10, C<OutputNormal> is always set and returned
here.


=head2 Size

 my ($x, $y) = Size();

Returns the size of the internal back buffer (which is mostly the same as
console's window size in characters). But it doesn't always match the size
of the console window, after the console size has changed, the internal back
buffer will get in sync only after L</Clear> or L</Flush> function calls.


=head2 Sync

 my $errno = Sync();

Sync comes handy when something causes desync between termbox's understanding
of a terminal buffer and the reality. Such as a third party process. Sync
forces a complete resync between the termbox and a terminal, it may not be
visually pretty though. At the moment on Windows it does nothing.



=cut

