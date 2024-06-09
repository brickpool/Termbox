# ------------------------------------------------------------------------
#
#   Winndows Terminal Termbox implementation
#
#   Copyright (C) 2012 termbox-go authors
#
# ------------------------------------------------------------------------
#   Author: 2024 J. Schneider
# ------------------------------------------------------------------------

package Termbox::Go::WinVT;

# ------------------------------------------------------------------------
# Boilerplate ------------------------------------------------------------
# ------------------------------------------------------------------------

use 5.014;
use strict;
use warnings;

# version '...'
use version;
our $version = version->declare('v1.1.1');
our $VERSION = version->declare('v0.3.0_0');

# authority '...'
our $authority = 'github:nsf';
our $AUTHORITY = 'github:brickpool';

# ------------------------------------------------------------------------
# Imports ----------------------------------------------------------------
# ------------------------------------------------------------------------

use Carp qw( croak );
use Fcntl;
use Params::Util qw( 
  _NONNEGINT
  _INVOCANT
);
use POSIX qw( :errno_h );
use threads;
use threads::shared;
use Thread::Queue 3.07;
use Win32::API;
use Win32::Console;
use Win32API::File qw(
  :Misc
  :Func
  :FILE_TYPE_
);

use Termbox::Go::Common qw(
  :bool
  :const
  :color
  :input
  :vars
);
use Termbox::Go::Devel qw(
  :all
  __FUNCTION__
  usage
);
use Termbox::Go::Terminal;
use Termbox::Go::Terminal::Backend qw( 
  coord_invalid
  attr_invalid
  input_event
  :vars
);
use Termbox::Go::Terminfo qw( setup_term_builtin );
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

# Windows Error Codes
use constant {
  WSAEWOULDBLOCK => 0x2733,
};

# Windows INPUT_RECORD EventType
use constant {
  KEY_EVENT   => 0x0001,
  MOUSE_EVENT => 0x0002,
};

# Input mode flags
use constant {
  ENABLE_INSERT_MODE => 0x0020,
  ENABLE_QUICK_EDIT_MODE => 0x0040,
  ENABLE_VIRTUAL_TERMINAL_INPUT => 0x0200,
  ENABLE_EXTENDED_FLAGS => 0x0080,
};

# Output mode flags
use constant {
  ENABLE_VIRTUAL_TERMINAL_PROCESSING => 0x0004,
  DISABLE_NEWLINE_AUTO_RETURN => 0x0008,
  ENABLE_LVB_GRID_WORLDWIDE => 0x0010,
};

# Windows codepage's
use constant {
  CP_UTF8 => 65001,
};

# Windows read console index
use constant {
  _event_type   => 0,
  _key_down     => 1,
  _repeat_count => 2,
  _ascii_char   => 5,
};

use constant {
  kernel32 => "kernel32.dll",
};

# ------------------------------------------------------------------------
# Variables --------------------------------------------------------------
# ------------------------------------------------------------------------

# Windows VT support
my $supportsVT;
my $notify;
my $orig_mode_in;
my $orig_mode_out;
my $orig_cp_out;

# ------------------------------------------------------------------------
# SysCalls ---------------------------------------------------------------
# ------------------------------------------------------------------------

my $peek_named_pipe;
BEGIN {
  $peek_named_pipe = Win32::API->new(kernel32,
    'PeekNamedPipe', 'NPIPPP', 'N'
  ) or die "Import PeekNamedPipe: $^E";
}

# ------------------------------------------------------------------------
# Backend ----------------------------------------------------------------
# ------------------------------------------------------------------------

# The call to Term::ReadKey::GetTerminalSize did not work if the handle was 
# redirected or duplicated, so we need to mock the original 
# Terminal::Backend::get_term_size() subroutine.
sub get_term_size { # $cols, $rows ($fd)
  my ($fd) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                    ? EINVAL
        : @_ > 1                    ? E2BIG
        : !defined(_NONNEGINT($fd)) ? EINVAL
        : 0;
        ;

  my $hConsole = FdGetOsFHandle($fd) // INVALID_HANDLE_VALUE;
  my ($col, $row) = Win32::Console::_GetConsoleScreenBufferInfo($hConsole);
  if (!$col || !$row) {
    $! = ENOTTY;
    return;
  }
  return ($col, $row);
}

{
  no warnings 'redefine';
  *Termbox::Go::Terminal::Backend::get_term_size = \&get_term_size;
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

  TRACE_VOID();
  if ($IsInit) {
    return 0;
  }

  my $err;

  use open IO => ':raw'; # https://github.com/Perl/perl5/issues/17665
  $err = sysopen($out, 'CONOUT$', O_RDWR) ? 0 : $!+0;
  if ($err != 0) {
    return $err;
  }
  $err = sysopen(IN, 'CONIN$', O_RDWR) ? 0 : $!+0;
  if ($err != 0) {
    return $err;
  }
  $in = fileno(\*IN);

  # Note: the following statement was not verified when porting to perl
  #
  # fileno clears the O_NONBLOCK flag. On systems where in and out are the
  # same file descriptor (see above), that would be a problem, because
  # the in file descriptor needs to be nonblocking. Save the fileno return
  # value here so that we won't need to call fileno later after the in file
  # descriptor has been made nonblocking (see below).
  $outfd = fileno($out);

  $notify = threads->create(sub {
    TRACE_VOID();
    # references
    # https://metacpan.org/pod/Win32::PowerShell::IPC#PeekNamedPipe
    # https://stackoverflow.com/a/73571717
    local $SIG{'KILL'} = sub { threads->exit() };
    my $hInput = FdGetOsFHandle($in) // INVALID_HANDLE_VALUE;
    if ($hInput == INVALID_HANDLE_VALUE) {
      return SET_ERROR($!, EBADF, 'FdGetOsFHandle');
    }
    my $hOutput = FdGetOsFHandle($outfd) // INVALID_HANDLE_VALUE;
    if ($hOutput == INVALID_HANDLE_VALUE) {
      return SET_ERROR($!, EBADF, 'FdGetOsFHandle');
    }
    my $uFileType = GetFileType($hInput) // FILE_TYPE_UNKNOWN;
    DEBUG_FMT('FileType: %d', $uFileType);
    for (;;) {
      switch: for ($uFileType) {
        case: $_ == FILE_TYPE_CHAR and do {
          local $_;
          # Get the number of unread input records in the input buffer of the 
          # console. This includes keyboard and mouse events, but also events
          # for resizing.
          $^E = 0;
          my $cNumberOfEvents
            = Win32::Console::_GetNumberOfConsoleInputEvents($hInput);
          if ($^E) {
            return SET_FAIL($!, 'GetNumberOfConsoleInputEvents');
          }
          $cNumberOfEvents //= 0;
          if ($cNumberOfEvents > 0) {
            $^E = 0;
            my ($eventType) = Win32::Console::_PeekConsoleInput($hInput);
            if ($^E) {
              return SET_FAIL($!, 'PeekConsoleInput');
            }
            $eventType //= 0;
            switch: for ($eventType) {
              case: $_ == KEY_EVENT and do {
                DEBUG('KEY_EVENT') unless $sigio->pending();
                $sigio->pending() or $sigio->enqueue(TRUE);
                last;
              };
              case: $_ == MOUSE_EVENT and do {
                DEBUG('MOUSE_EVENT');
                last;
              };
              default: {
                state $col = 0;
                state $row = 0;
                # Win32::Console::_PeekConsoleInput returns false if it is not 
                # a keyboard or mouse event. Means we receive a event type 
                # FOCUS_EVENT, MENU_EVENT or WINDOW_BUFFER_SIZE_EVENT.
                $^E = 0;
                my ($curr_col, $curr_row) 
                  = Win32::Console::_GetConsoleScreenBufferInfo($hOutput);
                if ($^E) {
                  SET_FAIL($!, 'GetConsoleScreenBufferInfo');
                }
                $curr_col //= 0;
                $curr_row //= 0;
                if ($curr_col != $col || $curr_row != $row) {
                  DEBUG('WINDOW_BUFFER_SIZE_EVENT') unless $sigwinch->pending();
                  $sigwinch->pending() or $sigwinch->enqueue(TRUE);
                  ($col, $row) = ($curr_col, $curr_row);
                }
              } # default
            } # switch: for ($eventType)
          } # if ($cNumberOfEvents)
          last;
        };
        case: $_ == FILE_TYPE_DISK ||
              $_ == FILE_TYPE_PIPE and do {
          my $bytesAvailable = 0;
          # PeekNamedPipe(hInput, NULL, NULL, NULL, &bytesAvailable, NULL)
          my $lpTotalBytesAvail = pack('L', 0);
          $peek_named_pipe->Call($hInput, undef, 0, undef, $lpTotalBytesAvail, 
            undef) or return;
          $bytesAvailable = unpack('L', $lpTotalBytesAvail);
          if ($bytesAvailable > 0) {
            DEBUG('KEY_EVENT') unless $sigio->pending();
            $sigwinch->pending() or $sigio->enqueue(TRUE);
          }
          last;
        };
        default: {
          return SET_FAIL($!, 'unknown FileType');
        }
      }
      # Wait 20 millis for more data
      Time::HiRes::sleep(20/1000);
    }
  });
  $notify->detach();

  # Set the input mode.
  {
    my $hInput = FdGetOsFHandle($in) // INVALID_HANDLE_VALUE;
    if ($hInput == INVALID_HANDLE_VALUE) {
      return $! = EBADF;
    }
    $^E = 0;
    $orig_mode_in = Win32::Console::_GetConsoleMode($hInput);
    if ($^E) {
      return $! = ENXIO;
    }
    my $mode = $orig_mode_in;
    $mode &= ~ENABLE_ECHO_INPUT;      # Turn off echo in a terminal
    $mode &= ~ENABLE_LINE_INPUT;      # no CR for ReadFile or ReadConsole
    $mode |= ENABLE_WINDOW_INPUT;     # Report changes in buffer size
    $mode &= ~ENABLE_PROCESSED_INPUT; # Report CTRL+C and SHIFT+Arrow events.
    $mode |= ENABLE_EXTENDED_FLAGS;   # Disable the Quick Edit mode,
    $mode &= ~ENABLE_QUICK_EDIT_MODE; # which inhibits the mouse.
    $mode |= ENABLE_VIRTUAL_TERMINAL_INPUT; # Allow ANSI escape sequences.
    $^E = 0;
    Win32::Console::_SetConsoleMode($hInput, $mode);
    if ($^E) {
      return $! = ENXIO;
    }
  }

  # Set the output mode.
  {
    my $hOutput = FdGetOsFHandle($outfd) // INVALID_HANDLE_VALUE;
    if ($hOutput == INVALID_HANDLE_VALUE) {
      return $! = EBADF;
    }
    $^E = 0;
    $orig_mode_out = Win32::Console::_GetConsoleMode($hOutput);
    if ($^E) {
      return $! = ENXIO;
    }
    my $mode = $orig_mode_out;
    $mode |= ENABLE_PROCESSED_OUTPUT;     # enable when using escape sequences.
    $mode &= ~ENABLE_WRAP_AT_EOL_OUTPUT;  # Avoid scrolling when reaching EOL.
    $mode |= DISABLE_NEWLINE_AUTO_RETURN; # Do not do CR on LF.
    $mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING; # Allow ANSI escape sequences.
    $^E = 0;
    Win32::Console::_SetConsoleMode($hOutput, $mode);
    if ($^E) {
      return $! = ENXIO;
    }
    $supportsVT = do {
      $^E = 0;
      $mode = Win32::Console::_GetConsoleMode($hOutput);
      if ($^E) {
        return $! = ENXIO;
      }
      $mode & ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    };
  }

  # Set codepage to utf8
  {
    $^E = 0;
    $orig_cp_out = Win32::Console::_GetConsoleOutputCP();
    if ($^E) {
      return $! = ENXIO;
    }
    if (!Win32::Console::_SetConsoleOutputCP(65001)) {
      return $! = ENXIO;
    }
  }

  # Windows Terminal is xterm-256color compatible
  {
    if (!$supportsVT) {
      return $! = ENOTTY;
    }
    # https://github.com/microsoft/terminal/issues/6045#issuecomment-631645277
    # https://superuser.com/a/1691012
    my $env = $ENV{"TERM"};
    $ENV{"TERM"} ||= 'xterm-256color';
    $err = setup_term_builtin() ? 0 : $!+0;
    if ($err != 0) {
      return $err;
    }
    $ENV{"TERM"} = $env;
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
    TRACE_VOID();
    use bytes;
    my $buf = "\0" x 128;
    my $hInput = FdGetOsFHandle($in) // INVALID_HANDLE_VALUE;
    if ($hInput == INVALID_HANDLE_VALUE) {
      return SET_ERROR($!, EBADF, 'FdGetOsFHandle');
    }
    my $uFileType = GetFileType($hInput) // FILE_TYPE_UNKNOWN;
    for (;;) {
      select: {
        case: $sigio->dequeue_nb() and do {
          DEBUG('sigio dequeued');
          for (;;) {
            my $n = 0;
            $^E = 0;
            switch: for ($uFileType) {
              case: $_ == FILE_TYPE_CHAR and do {
                my $cNumberOfEvents 
                  = Win32::Console::_GetNumberOfConsoleInputEvents($hInput) // 0;
                while ($cNumberOfEvents--) {
                  if (my @ir = Win32::Console::_ReadConsoleInput($hInput)) {
                    if ($ir[_event_type] == KEY_EVENT && $ir[_key_down]) {
                      while ($ir[_repeat_count]--) {
                        substr($buf, $n++, 1) = chr($ir[_ascii_char]);
                      }
                    }
                  }
                }
                if ($n == 0) {
                  $^E ||= WSAEWOULDBLOCK;
                }
                last;
              };
              case: $_ == FILE_TYPE_DISK || $_ == FILE_TYPE_PIPE and do {
                return SET_FAIL($!, 'not implemented');
              };
              default: {
                return SET_FAIL($!, 'unknown FileType');
              }
            }
            DEBUG_FMT("read %d bytes", $n) if $n;
            my $err = $^E+0;
            if ($err) {
              DEBUG_FMT("System Error Code: %d", $err) if $err;
              last;
            }
            select: {
              my $ie;
              case: ($ie = input_event(substr($buf, 0, $n), $err)) and do {
                DEBUG_FMT('enqueue {%s} to input_comm', "@{[%$ie]}");
                $input_comm->enqueue($ie);
                DEBUG('done');
                substr($buf, $n, 128) = "\0" x 128;
              };
              case: $quit->dequeue_nb() and do {
                return 0+RETURN_OK;
              };
            }
          }
        };
        case: $quit->dequeue_nb() and do {
          return 0+RETURN_OK;
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
  goto &Termbox::Go::Terminal::Interrupt;
}

# Finalizes termbox library, should be called after successful initialization 
# when termbox's functionality isn't required anymore.
sub Close { # $errno ()
  my $class = shift if _INVOCANT($_[0]) and $_[0]->can(__FUNCTION__);
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  TRACE_VOID();
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

  my $hInput = FdGetOsFHandle($in) // INVALID_HANDLE_VALUE;
  if ($hInput == INVALID_HANDLE_VALUE) {
    return $! = EBADF;
  }
  if (defined $orig_mode_in) {
    $^E = 0;
    Win32::Console::_SetConsoleMode($hInput, $orig_mode_in);
    if ($^E) {
      return $! = ENXIO;
    }
    undef $orig_mode_in;
  }

  my $hOutput = FdGetOsFHandle($outfd) // INVALID_HANDLE_VALUE;
  if ($hOutput == INVALID_HANDLE_VALUE) {
    return $! = EBADF;
  }
  if (defined $orig_mode_out) {
    $^E = 0;
    Win32::Console::_SetConsoleMode($hOutput, $orig_mode_out);
    if ($^E) {
      return $! = ENXIO;
    }
    undef $orig_mode_out;
  }

  if ($notify) {
    $notify->kill('KILL');
    undef $notify;
  }
  if (defined $orig_cp_out) {
    if (!Win32::Console::_SetConsoleOutputCP($orig_cp_out)) {
      return $! = ENXIO;
    }
    undef $orig_cp_out;
  }

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
  goto &Termbox::Go::Terminal::Flush;
}

# Sets the position of the cursor. See also L</HideCursor>.
sub SetCursor { # $errno ($x, $y)
  goto &Termbox::Go::Terminal::SetCursor;
}

# The shortcut for L<SetCursor(-1, -1)|/SetCursor>.
sub HideCursor { # $errno ()
  goto &Termbox::Go::Terminal::HideCursor;
}

# Changes cell's parameters in the internal back buffer at the specified
# position.
sub SetCell { # $errno ($x, $y, $ch, $fg, $bg)
  goto &Termbox::Go::Terminal::SetCell;
}

# Returns the specified cell from the internal back buffer.
sub GetCell { # \%Cell ($x, $y)
  goto &Termbox::Go::Terminal::GetCell;
}

# Changes cell's character (utf8) in the internal back buffer at 
# the specified position.
sub SetChar { # $errno ($x, $y, $ch)
  goto &Termbox::Go::Terminal::SetChar;
}

# Changes cell's foreground attributes in the internal back buffer at
# the specified position.
sub SetFg { # $errno ($x, $y, $fg)
  goto &Termbox::Go::Terminal::SetFg;
}

# Changes cell's background attributes in the internal back buffer at
# the specified position.
sub SetBg { # $errno ($x, $y, $bg)
  goto &Termbox::Go::Terminal::SetBg;
}

# Returns a slice into the termbox's back buffer. You can get its dimensions
# using L</Size> function. The slice remains valid as long as no L</Clear> or
# L</Flush> function calls were made after call to this function.
sub CellBuffer { # \@ ()
  goto &Termbox::Go::Terminal::CellBuffer;
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
  goto &Termbox::Go::Terminal::ParseEvent;
}

# Wait for an event and return it. This is a blocking function call. Instead
# of EventKey and EventMouse it returns EventRaw events. Raw event is written
# into C<data> slice and Event's N field is set to the amount of bytes written.
# The minimum required length of the C<data> slice is 1. This requirement may
# vary on different platforms.
#
# B<NOTE>: This API is experimental and may change in future.
sub PollRawEvent { # \%event ($data)
  goto &Termbox::Go::Terminal::PollRawEvent;
}

# Wait for an event and return it. This is a blocking function call.
sub PollEvent { # \%Event ()
  goto &Termbox::Go::Terminal::PollEvent;
}

# Returns the size of the internal back buffer (which is mostly the same as
# terminal's window size in characters). But it doesn't always match the size
# of the terminal window, after the terminal size has changed, the internal back
# buffer will get in sync only after L</Clear> or L</Flush> function calls.
sub Size { # $x, $y ()
  goto &Termbox::Go::Terminal::Size;
}

# Clears the internal back buffer.
sub Clear { # $errno ($fg, $bg)
  goto &Termbox::Go::Terminal::Clear;
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
  goto &Termbox::Go::Terminal::SetInputMode;
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
  goto &Termbox::Go::Terminal::SetOutputMode;
}

# Sync comes handy when something causes desync between termbox's understanding
# of a terminal buffer and the reality. Such as a third party process. Sync
# forces a complete resync between the termbox and a terminal, it may not be
# visually pretty though.
sub Sync { # $errno ()
  goto &Termbox::Go::Terminal::Sync;
}

1;

__END__

=head1 NAME

Termbox::Go::WinVT - Windows Terminal Termbox implementation

=head1 DESCRIPTION

This document describes the Termbox library for Perl, using the Windows 
Terminal, which was introduced with Windows 10. 

The advantage of the Termbox library is the use of an standard. Termbox
contains a few functions with which terminal applications can be 
developed with high portability and interoperability. 

B<Note>: Windows Terminal still requires parts of the classic Console API, 
e.g. to set the input or output mode and codepage.

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

L<Win32API::File> 

L<Win32::Console> 

L<Win32::API> 

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


=head2 get_term_size

 my ($cols, $rows) = get_term_size($fd);

The call to Term::ReadKey::GetTerminalSize did not work if the handle was
redirected or duplicated, so we need to mock the original
Terminal::Backend::get_term_size() subroutine.



=cut

