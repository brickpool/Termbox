# ------------------------------------------------------------------------
#
#   Win32 Termbox implementation
#
#   Code based on termbox-go v1.1.1, 21. April 2021
#
#   Copyright (C) 2012 termbox-go authors
#
# ------------------------------------------------------------------------
#   Author: 2024 J. Schneider
# ------------------------------------------------------------------------

package Termbox::Go::Win32::Backend;

# ------------------------------------------------------------------------
# Boilerplate ------------------------------------------------------------
# ------------------------------------------------------------------------

use 5.014;
use strict;
use warnings;

# version '...'
use version;
our $version = version->declare('v1.1.1');
our $VERSION = version->declare('v0.3.1');

# authority '...'
our $authority = 'github:nsf';
our $AUTHORITY = 'github:brickpool';

# ------------------------------------------------------------------------
# Imports ----------------------------------------------------------------
# ------------------------------------------------------------------------

require bytes; # not use, see https://perldoc.perl.org/bytes
use Carp qw( croak );
use Config;
use Devel::StrictMode;
use Encode;
use List::Util 1.29 qw(
  any
  all
);
use Params::Util qw(
  _STRING
  _POSINT
  _NONNEGINT
  _SCALAR0
  _ARRAY
  _ARRAY0
  _HASH
  _HASH0
);
use POSIX qw( :errno_h );
use Scalar::Util qw( readonly );
use threads;
use threads::shared;
use Thread::Queue 3.07;
use Unicode::EastAsianWidth;
use Unicode::EastAsianWidth::Detect qw( is_cjk_lang );
use Win32;
use Win32::Console;

use Termbox::Go::Common qw( :all );
use Termbox::Go::Devel qw(
  __FUNCTION__
  usage
);
use Termbox::Go::WCWidth qw( wcwidth );

# ------------------------------------------------------------------------
# Exports ----------------------------------------------------------------
# ------------------------------------------------------------------------

=head1 EXPORTS

Nothing per default, but can export the following per request:

  :all

    :const
      common_lvb_leading_byte
      common_lvb_trailing_byte
      key_event
      mouse_event
      window_buffer_size_event
      enable_extended_flags

    :syscalls
      set_console_active_screen_buffer
      set_console_screen_buffer_size
      set_console_window_info
      create_console_screen_buffer
      get_console_screen_buffer_info
      write_console_output
      write_console_output_character
      write_console_output_attribute
      set_console_cursor_info
      get_console_cursor_info
      set_console_cursor_position
      read_console_input
      get_console_mode
      set_console_mode
      fill_console_output_character
      fill_console_output_attribute
      create_event
      wait_for_multiple_objects
      set_event
      get_current_console_font

    :func
      get_cursor_position
      get_term_size
      get_win_min_size
      get_win_size
      fix_win_size
      update_size_maybe
      append_diff_line
      prepare_diff_messages
      get_ct
      cell_to_char_info
      move_cursor
      show_cursor
      clear
      key_event_record_to_event
      input_event_producer

    :types
      syscallHandle
      char_info
      coord
      small_rect
      console_cursor_info
      key_event_record
      window_buffer_size_record
      diff_msg

    :vars
      $is_cjk
      $orig_cursor_info
      $orig_size
      $orig_window
      $orig_mode
      $orig_screen
      $term_size
      $interrupt
      $charbuf
      $diffbuf
      $cancel_comm
      $cancel_done_comm

=cut

use Exporter qw( import );

our @EXPORT_OK = qw(
);

our %EXPORT_TAGS = (

  const => [qw(
    common_lvb_leading_byte
    common_lvb_trailing_byte
    key_event
    mouse_event
    window_buffer_size_event
    enable_extended_flags
  )],

  syscalls => [qw(
    set_console_active_screen_buffer
    set_console_screen_buffer_size
    set_console_window_info
    create_console_screen_buffer
    get_console_screen_buffer_info
    write_console_output
    write_console_output_character
    write_console_output_attribute
    set_console_cursor_info
    get_console_cursor_info
    set_console_cursor_position
    read_console_input
    get_console_mode
    set_console_mode
    fill_console_output_character
    fill_console_output_attribute
    create_event
    wait_for_multiple_objects
    set_event
    get_current_console_font
  )],

  func => [qw(
    get_cursor_position
    get_term_size
    get_win_min_size
    get_win_size
    fix_win_size
    update_size_maybe
    append_diff_line
    prepare_diff_messages
    get_ct
    cell_to_char_info
    move_cursor
    show_cursor
    clear
    key_event_record_to_event
    input_event_producer
  )],

  types => [qw(
    syscallHandle
    char_info
    coord
    small_rect
    console_cursor_info
    key_event_record
    window_buffer_size_record
    diff_msg
  )],

  vars => [qw(
    $is_cjk
    $orig_cursor_info
    $orig_size
    $orig_window
    $orig_mode
    $orig_screen
    $term_size
    $interrupt
    $charbuf
    $diffbuf
    $cancel_comm
    $cancel_done_comm
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
# Types ------------------------------------------------------------------
# ------------------------------------------------------------------------

# WaitForMultipleObjects, WriteConsoleOutputW
use constant PTR_SIZE => $Config{ptrsize};

use constant HANDLE =>
    PTR_SIZE == 8 ? 'Q'
  : PTR_SIZE == 4 ? 'L'
  : die("Unrecognized ptrsize\n");

# https://stackoverflow.com/a/35259129
use constant UINT_PTR =>
    PTR_SIZE == 8 ? 'Q'
  : PTR_SIZE == 4 ? 'L'
  : die("Unrecognized ptrsize\n");

use constant {
  INFINITE    => 0xffffffff,
  WAIT_FAILED => 0xffffffff,
};

# ------------------------------------------------------------------------

# Usage:
#  $handle = syscallHandle();
#  $handle = syscallHandle($handle) // die;
sub syscallHandle { # $|undef (|$)
  return 0
      if @_ == 0
      ;
  return $_[0]
      if @_ == 1 
      && _POSINT($_[0])
      ;
  return;
}

# Usage:
#  my \%hashref = char_info();
#  my \%hashref = char_info($char, $attr) // die;
#  my \%hashref = char_info({char => $char, attr => $attr}) // die;
sub char_info { # \%|undef (|@|\%)
  state $char_info = {
    char => 0,
    attr => 0,
  };
  return { %$char_info } 
      if @_ == 0
      ;
  return $_[0] 
      if @_ == 1 
      && _HASH($_[0])
      && keys(%$char_info) == keys(%{$_[0]})
      && (!STRICT or all { exists $_[0]->{$_} } keys %$char_info)
      && (!STRICT or all { exists $char_info->{$_} } keys %{$_[0]})
      && (!STRICT or all { defined _NONNEGINT($_) } values %{$_[0]})
      ;
  return { 
      char => $_[0],
      attr => $_[1],
    } if @_ == 2
      && (!STRICT or all { defined _NONNEGINT($_) } @_)
      ;
  return;
}

# Usage:
#  my \%hashref = coord();
#  my \%hashref = coord($x, $y) // die;
#  my \%hashref = coord({x => $x, y = $y}) // die;
sub coord { # \%|undef (|@|\%)
  state $coord = {
    x => 0,
    y => 0,
  };
  return { %$coord } 
      if @_ == 0
      ;
  return $_[0] 
      if @_ == 1
      && _HASH($_[0])
      && keys(%$coord) == keys(%{$_[0]})
      && (!STRICT or all { exists $_[0]->{$_} } keys %$coord)
      && (!STRICT or all { exists $coord->{$_} } keys %{$_[0]})
      && (!STRICT or all { defined _NONNEGINT($_) } values %{$_[0]})
      ;
  return { 
      x => $_[0], 
      y => $_[1],
    } if @_ == 2 
      && (!STRICT or all { defined _NONNEGINT($_) } @_)
      ;
  return;
}

# Usage:
#  my \%hashref = small_rect();
#  my \%hashref = small_rect(
#    $left, 
#    $top, 
#    $right, 
#    $bottom,
#  ) // die;
#  my \%hashref = small_rect({
#    left    => $left, 
#    top     => $top, 
#    right   => $right, 
#    bottom  => $bottom,
#  }) // die;
sub small_rect { # \%|undef (|@|\%)
  state $small_rect = {
    left   => 0,
    top    => 0,
    right  => 0,
    bottom => 0,
  };
  return { %$small_rect } 
      if @_ == 0
      ;
  return $_[0] 
      if @_ == 1 
      && _HASH($_[0])
      && keys(%$small_rect) == keys(%{$_[0]})
      && (!STRICT or all { exists $_[0]->{$_} } keys %$small_rect)
      && (!STRICT or all { exists $small_rect->{$_} } keys %{$_[0]})
      && (!STRICT or all { defined _NONNEGINT($_) } values %{$_[0]})
      ;
  return { 
    left   => $_[0],
    top    => $_[1],
    right  => $_[2],
    bottom => $_[3],
    } if @_ == 4
      && (!STRICT or all { defined _NONNEGINT($_) } @_)
      ;
  return;

}

# Usage:
#  my \%hashref = console_cursor_info();
#  my \%hashref = console_cursor_info($size, $visible) // die;
#  my \%hashref = console_cursor_info({
#    size    => $size, 
#    visible => $visible,
#  }) // die;
sub console_cursor_info { # \%|undef (|@|\%)
  state $console_cursor_info = {
    size    => 0,
    visible => 0,
  };
  return { %$console_cursor_info } 
      if @_ == 0
      ;
  return $_[0] 
      if @_ == 1 
      && _HASH($_[0])
      && (all { exists $_[0]->{$_} } keys %$console_cursor_info)
      && (all { exists $console_cursor_info->{$_} } keys %{$_[0]})
      && (all { defined _NONNEGINT($_) } values %{$_[0]})
      ;
  return { 
      size    => $_[0], 
      visible => $_[1],
    } if @_ == 2 
      && (all { defined _NONNEGINT($_) } @_)
      ;
  return;
}

# Usage:
#  my \%hashref = key_event_record();
#  my \%hashref = key_event_record(
#    $key_down,
#    $repeat_count,
#    $virtual_key_code,
#    $virtual_scan_code,
#    $unicode_char,
#    $control_key_state
#  ) // die;
#  my \%hashref = key_event_record({
#    key_down          => $key_down,
#    repeat_count      => $repeat_count,
#    virtual_key_code  => $virtual_key_code,
#    virtual_scan_code => $virtual_scan_code,
#    unicode_char      => $unicode_char,
#    control_key_state => $control_key_state,
#  }) // die:
sub key_event_record { # \%|undef (|@|\%)
  state $key_event_record = {
    key_down          => 0,
    repeat_count      => 0,
    virtual_key_code  => 0,
    virtual_scan_code => 0,
    unicode_char      => 0,
    control_key_state => 0,
  };
  return { %$key_event_record } 
      if @_ == 0
      ;
  return $_[0] 
      if @_ == 1 
      && _HASH($_[0])
      && (all { exists $_[0]->{$_} } keys %$key_event_record)
      && (all { exists $key_event_record->{$_} } keys %{$_[0]})
      && (all { defined _NONNEGINT($_) } values %{$_[0]})
      ;
  return { 
      key_down          => $_[0],
      repeat_count      => $_[1],
      virtual_key_code  => $_[2],
      virtual_scan_code => $_[3],
      unicode_char      => $_[4],
      control_key_state => $_[5],
    } if @_ == 6
      && (all { defined _NONNEGINT($_) } @_)
      ;
  return;
}

# Usage:
#  my \%hashref = window_buffer_size_record();
#  my \%hashref = window_buffer_size_record({x => $x, y => $y}) // die;
sub window_buffer_size_record { # \%|undef (|\%)
  state $size = {
    x => 0,
    y => 0,
  };
  return { size => { %$size } }
      if @_ == 0;
  return $_[0]
      if @_ == 1 
      && _HASH($_[0])
      && keys %{$_[0]} == 1
      && exists $_[0]->{size}
      && _HASH($_[0]->{size})
      && (all { exists $_[0]->{size}->{$_} } keys %$size)
      && (all { exists $size->{$_} } keys %{$_[0]->{size}})
      && (all { defined _NONNEGINT($_) } values %{$_[0]->{size}})
      ;
  return;
}

# Usage:
#  my \%hashref = mouse_event_record();
#  my \%hashref = mouse_event_record({
#    mouse_pos => {
#      x => $x,
#      y => $y,
#    },
#    button_state      => $button_state,
#    control_key_state => $control_key_state,
#    event_flags       => $event_flags,
#  }) // die;
sub mouse_event_record { # \%|undef (|\%)
  state $mouse_pos = {
    x => 0,
    y => 0,
  };
  state $mouse_event_record = {
    mouse_pos         => {},
    button_state      => 0,
    control_key_state => 0,
    event_flags       => 0,
  };
  return do { 
      local $_ = { %$mouse_event_record };
      $_->{mouse_pos} = { %$mouse_pos };
      $_;
    } if @_ == 0;
  return $_[0]
      if @_ == 1 
      && _HASH($_[0])
      && (all { exists $_[0]->{$_} } keys %$mouse_event_record)
      && (all { exists $mouse_event_record->{$_} } keys %{$_[0]})
      && _HASH($_[0]->{mouse_pos})
      && (all { exists $_[0]->{mouse_pos}->{$_} } keys %$mouse_pos)
      && (all { exists $mouse_pos->{$_} } keys %{$_[0]->{mouse_pos}})
      && defined(_NONNEGINT($_[0]->{mouse_pos}->{x}))
      && defined(_NONNEGINT($_[0]->{mouse_pos}->{y}))
      && defined(_NONNEGINT($_[0]->{button_state}))
      && defined(_NONNEGINT($_[0]->{control_key_state}))
      && defined(_NONNEGINT($_[0]->{event_flags}))
      ;
  return;
}

# Usage:
#  my \%hashref = diff_msg();
#  my \%hashref = diff_msg($pos, $lines, \@chars) // die;
#  my \%hashref = diff_msg({
#    pos   => $pos,
#    lines => $lines,
#    chars => \@chars,
#  }) // die;
sub diff_msg { # \%|undef (|@|\%)
  state $diff_msg = {
    pos   => 0,
    lines => 0,
    chars => [],
  };
  return { %$diff_msg } 
      if @_ == 0;
  return $_[0]
      if @_ == 1
      && _HASH($_[0])
      && (all { exists $_[0]->{$_} } keys %$diff_msg)
      && (all { exists $diff_msg->{$_} } keys %{$_[0]})
      && defined(_NONNEGINT($_[0]->{pos}))
      && defined(_NONNEGINT($_[0]->{lines}))
      && defined(_ARRAY0($_[0]->{chars}))
      ;
  return {
      pos   => $_[0],
      lines => $_[1],
      chars => $_[2],
    } if @_ == 3
      && defined(_NONNEGINT($_[0])) 
      && defined(_NONNEGINT($_[1]))
      && defined(_ARRAY0($_[2]))
      ;
  return;
}

# ------------------------------------------------------------------------
# Constants --------------------------------------------------------------
# ------------------------------------------------------------------------

# Windows Error Codes
use constant {
  ERROR_INVALID_HANDLE => 0x6,
  ERROR_INVALID_DATA => 0xd,
  ERROR_INVALID_PARAMETER => 0x57,
  ERROR_BAD_ARGUMENTS => 0xa0,
  ERROR_INVALID_CRUNTIME_PARAMETER => 0x508,
  WSAEINVAL => 0x2726,
};

# Event types
use constant {
  KEY_EVENT                 => 0x0001,
  MOUSE_EVENT               => 0x0002,
  WINDOW_BUFFER_SIZE_EVENT  => 0x0004,
};

# ReadConsoleInput
use constant {
  # INPUT_RECORD
  wEventType        => 0,
  # KEY_EVENT_RECORD
  bKeyDown          => 1,
  wRepeatCount      => 2,
  wVirtualKeyCode   => 3,
  wVirtualScanCode  => 4,
  UnicodeChar       => 5,
  AsciiChar         => 5,
  dwControlKeyState => 6,
  # MOUSE_EVENT_RECORD
  dwMousePosition   => 1,
  dwButtonState     => 2,
  dwControlKeyState => 3,
  dwEventFlags      => 4,
  # WINDOW_BUFFER_SIZE_RECORD
  dwSize            => 1,
};

# GetCurrentConsoleFont
use constant {
  nFont       => 0,
  dwFontSize  => 1,
};

# Character attributes
use constant {
  COMMON_LVB_LEADING_BYTE   => 0x0100,
  COMMON_LVB_TRAILING_BYTE  => 0x0200,
};

# Status of the mouse buttons
use constant {
  FROM_LEFT_1ST_BUTTON_PRESSED  => 0x0001,
  FROM_LEFT_2ND_BUTTON_PRESSED  => 0x0004,
  FROM_LEFT_3RD_BUTTON_PRESSED  => 0x0008,
  FROM_LEFT_4TH_BUTTON_PRESSED  => 0x0010,
  RIGHTMOST_BUTTON_PRESSED      => 0x0002,
};

# Input Mode flags
use constant {
  ENABLE_EXTENDED_FLAGS => 0x80,
};

use constant {
  mouse_lmb => FROM_LEFT_1ST_BUTTON_PRESSED,
  mouse_rmb => RIGHTMOST_BUTTON_PRESSED,
  mouse_mmb => FROM_LEFT_2ND_BUTTON_PRESSED
             | FROM_LEFT_3RD_BUTTON_PRESSED
             | FROM_LEFT_4TH_BUTTON_PRESSED,
  SM_CXMIN  => 28,
  SM_CYMIN  => 29,
};

# api_windows.go
use constant {
  common_lvb_leading_byte   => COMMON_LVB_LEADING_BYTE,
  common_lvb_trailing_byte  => COMMON_LVB_TRAILING_BYTE,
};

# syscalls_windows.go
use constant {
  key_event                 => KEY_EVENT,
  mouse_event               => MOUSE_EVENT,
  window_buffer_size_event  => WINDOW_BUFFER_SIZE_EVENT,
};

use constant {
  enable_extended_flags => ENABLE_EXTENDED_FLAGS,
};

use constant {
  vk_f1          => 0x70,
  vk_f2          => 0x71,
  vk_f3          => 0x72,
  vk_f4          => 0x73,
  vk_f5          => 0x74,
  vk_f6          => 0x75,
  vk_f7          => 0x76,
  vk_f8          => 0x77,
  vk_f9          => 0x78,
  vk_f10         => 0x79,
  vk_f11         => 0x7a,
  vk_f12         => 0x7b,
  vk_insert      => 0x2d,
  vk_delete      => 0x2e,
  vk_home        => 0x24,
  vk_end         => 0x23,
  vk_pgup        => 0x21,
  vk_pgdn        => 0x22,
  vk_arrow_up    => 0x26,
  vk_arrow_down  => 0x28,
  vk_arrow_left  => 0x25,
  vk_arrow_right => 0x27,
  vk_backspace   => 0x8,
  vk_tab         => 0x9,
  vk_enter       => 0xd,
  vk_esc         => 0x1b,
  vk_space       => 0x20,
};

# ------------------------------------------------------------------------
# Variables ---------------------------------------------------------------
# ------------------------------------------------------------------------

our $is_cjk               = is_cjk_lang();
our $orig_cursor_info     = {}; # console_cursor_info;
our $orig_size            = {}; # coord;
our $orig_window          = {}; # small_rect;
our $orig_mode            = 0;
our $orig_screen          = 0;  # syscallHandle
our $term_size            = {}; # coord;
our $interrupt            = 0;  # syscallHandle
our $charbuf              = []; # char_info
our $diffbuf              = []; # diff_msg
our $cancel_comm          = $_ = Thread::Queue->new(); $_->limit(1);
our $cancel_done_comm     = Thread::Queue->new();
my $alt_mode_esc  :shared = FALSE;

# these ones just to prevent heap allocs at all costs
my $tmp_info   = {}; # console_screen_buffer_info
my $tmp_arg    = 0;
# my $tmp_coord0 = coord(0, 0);
my $tmp_coord  = coord(0, 0);
my $tmp_rect   = small_rect(0, 0, 0, 0);
my $tmp_finfo  = {}; # console_font_info;

my $color_table_bg = [
  $BG_BLACK, # default (black)
  $BG_BLACK,
  $BG_RED,
  $BG_GREEN,
  $BG_BROWN,
  $BG_BLUE,
  $BG_MAGENTA,
  $BG_CYAN,
  $BG_LIGHTGRAY,
  $BG_GRAY,
  $BG_LIGHTRED,
  $BG_LIGHTGREEN,
  $BG_YELLOW,
  $BG_LIGHTBLUE,
  $BG_LIGHTMAGENTA,
  $BG_LIGHTCYAN,
  $BG_WHITE,
];

my $color_table_fg = [
  $FG_LIGHTGRAY, # default (white)
  $FG_BLACK,
  $FG_RED,
  $FG_GREEN,
  $FG_BROWN,
  $FG_BLUE,
  $FG_MAGENTA,
  $FG_CYAN,
  $FG_LIGHTGRAY,
  $FG_GRAY,
  $FG_LIGHTRED,
  $FG_LIGHTGREEN,
  $FG_YELLOW,
  $FG_LIGHTBLUE,
  $FG_LIGHTMAGENTA,
  $FG_LIGHTCYAN,
  $FG_WHITE,
];

# ------------------------------------------------------------------------
# SysCalls ---------------------------------------------------------------
# ------------------------------------------------------------------------

package syscall {
use Win32::API;
use constant kernel32 => "kernel32.dll";
BEGIN {
  exists &ReadConsoleInputW
    or
  Win32::API::More->Import(kernel32,
    'BOOL ReadConsoleInputW(
      HANDLE    hConsoleInput,
      UINT_PTR  lpBuffer,
      DWORD     nLength,
      LPDWORD   lpNumberOfEventsRead
    )'
  ) or die "Import ReadConsoleInput: $^E";

  exists &WaitForMultipleObjects
    or
  Win32::API::More->Import(kernel32,
    'DWORD WaitForMultipleObjects(
      DWORD     nCount,
      UINT_PTR  lpHandles,
      BOOL      bWaitAll,
      DWORD     dwMilliseconds
    );'
  ) or die "Import WaitForMultipleObjects: $^E";

  exists &CreateEventW
    or
  Win32::API::More->Import(kernel32,
    'HANDLE CreateEventW(
      LPVOID    lpEventAttributes,
      BOOL      bManualReset,
      BOOL      bInitialState,
      LPCWSTR   lpName
    )'
  ) or die "Import CreateEventW: $^E";

  exists &SetEvent
    or
  Win32::API::More->Import(kernel32,
    'BOOL SetEvent(
      HANDLE hEvent
    )'
  ) or die "Import SetEvent: $^E";

  exists &GetCurrentConsoleFont
    or
  Win32::API::More->Import(kernel32,
    'BOOL GetCurrentConsoleFont(
      HANDLE    hConsoleOutput,
      BOOL      bMaximumWindow,
      UINT_PTR  lpConsoleCurrentFont
    )'
  ) or die "Import GetCurrentConsoleFont: $^E";

  exists &WriteConsoleOutputW
    or
  Win32::API::More->Import(kernel32,
    'BOOL WriteConsoleOutputW(
      HANDLE    hConsoleOutput,
      LPCWSTR   lpBuffer,
      DWORD     dwBufferSize,
      DWORD     dwBufferCoord,
      UINT_PTR  lpWriteRegion
    )'
  ) or die "Import WriteConsoleOutputW: $^E";
}
1;
}

my $proc_set_console_active_screen_buffer  = \&Win32::Console::_SetConsoleActiveScreenBuffer;
my $proc_set_console_screen_buffer_size    = \&Win32::Console::_SetConsoleScreenBufferSize;
my $proc_set_console_window_info           = \&Win32::Console::_SetConsoleWindowInfo;
my $proc_create_console_screen_buffer      = \&Win32::Console::_CreateConsoleScreenBuffer;
my $proc_get_console_screen_buffer_info    = \&Win32::Console::_GetConsoleScreenBufferInfo;
my $proc_write_console_output              = \&syscall::WriteConsoleOutputW;
my $proc_write_console_output_character    = \&Win32::Console::_WriteConsoleOutputCharacter;
my $proc_write_console_output_attribute    = \&Win32::Console::_WriteConsoleOutputAttribute;
my $proc_set_console_cursor_info           = \&Win32::Console::_SetConsoleCursorInfo;
my $proc_set_console_cursor_position       = \&Win32::Console::_SetConsoleCursorPosition;
my $proc_get_console_cursor_info           = \&Win32::Console::_GetConsoleCursorInfo;
my $proc_read_console_input                = \&syscall::ReadConsoleInputW;
my $proc_get_console_mode                  = \&Win32::Console::_GetConsoleMode;
my $proc_set_console_mode                  = \&Win32::Console::_SetConsoleMode;
my $proc_fill_console_output_character     = \&Win32::Console::_FillConsoleOutputCharacter;
my $proc_fill_console_output_attribute     = \&Win32::Console::_FillConsoleOutputAttribute;
my $proc_create_event                      = \&syscall::CreateEventW;
my $proc_wait_for_multiple_objects         = \&syscall::WaitForMultipleObjects;
my $proc_set_event                         = \&syscall::SetEvent;
my $proc_get_current_console_font          = \&syscall::GetCurrentConsoleFont;
my $get_system_metrics                     = \&Win32::GetSystemMetrics;

# ------------------------------------------------------------------------

#
sub set_console_active_screen_buffer { # $bSucceeded ($hConsoleOutput)
  my ($h) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 1       ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)  ? ERROR_INVALID_HANDLE
        : 0
        ;

  my $err;
  my $r0 = $proc_set_console_active_screen_buffer->($h);
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub set_console_screen_buffer_size { # $bSucceeded ($hConsoleOutput, \%dwSize)
  my ($h, $size) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 2       ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)  ? ERROR_INVALID_HANDLE
        : !coord($size) ? ERROR_INVALID_PARAMETER
        : 0
        ;

  my $err;
  my $r0 = $proc_set_console_screen_buffer_size->(
    $h, $size->{x}, $size->{y});
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub set_console_window_info { # $bSucceeded ($hConsoleOutput, \%lpConsoleWindow)
  my ($h, $window) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 2               ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)          ? ERROR_INVALID_HANDLE
        : !small_rect($window)  ? ERROR_INVALID_PARAMETER
        : 0
        ;

  my $err;
  my $absolute = 1;
  my $r0 = $proc_set_console_window_info->(
    $h, $absolute, 
    $window->{left}, $window->{top}, $window->{right}, $window->{bottom}
  );
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub create_console_screen_buffer { # $handle|undef ()
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ ? ERROR_BAD_ARGUMENTS : 0;

  my $err;
  my $r0 = $proc_create_console_screen_buffer->(
    (GENERIC_READ|GENERIC_WRITE), 0, CONSOLE_TEXTMODE_BUFFER
  );
  my $e1 = $^E + 0;
  if ($r0 <= 0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : $r0;
}

sub get_console_screen_buffer_info { # $bSucceeded ($hConsoleOutput, \%lpConsoleScreenBufferInfo)
  my ($h, $info) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 2                 ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)            ? ERROR_INVALID_HANDLE
        : !defined(_HASH0($info)) ? ERROR_INVALID_PARAMETER
        : readonly(%$info)        ? ERROR_INVALID_CRUNTIME_PARAMETER
        : 0
        ;

  my $err = $^E = 0;
  my $r0 = do { # proc_get_console_screen_buffer_info
    my @info = $proc_get_console_screen_buffer_info->($h);
    my $r = @info >= 11;
    if ($r) {
      $info->{size} = {
        x => shift @info,
        y => shift @info,
      };
      $info->{cursor_position} = {
        x => shift @info,
        y => shift @info,
      };
      $info->{attributes} = shift @info;
      $info->{window} = {
        left => shift @info,
        top => shift @info,
        right => shift @info,
        bottom => shift @info,
      };
      $info->{maximum_window_size} = {
        x => shift @info,
        y => shift @info,
      };
    }
    $r;
  };
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub write_console_output { # $bSucceeded ($hConsoleOutput, $lpBuffer, \%lpWriteRegion)
  my ($h, $chars, $dst) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 3                   ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)              ? ERROR_INVALID_HANDLE
        : !defined(_STRING($chars)) ? ERROR_INVALID_PARAMETER
        : bytes::length($chars) < 4 ? ERROR_INVALID_DATA
        : !small_rect($dst)         ? ERROR_INVALID_PARAMETER
        : 0
        ;

  my $err;
  my $tmp_coord = unpack('V', pack('SS',
    $dst->{right} - $dst->{left} + 1,
    $dst->{bottom} - $dst->{top} + 1,
  ));
  my $tmp_rect = pack('S4', @$dst{qw(
    left 
    top 
    right 
    bottom
  )});
  my $r0 = do { # proc_write_console_output
    # https://stackoverflow.com/a/64068027
    my $uintptr = unpack(UINT_PTR, pack('P', $tmp_rect));
    if ($Win32::API::DEBUG) {
      STDERR->printf("[Win32::API] WriteConsoleOutputW");
      STDERR->printf("[Win32::API] nLength: %d\n", 0+unpack('S*', $chars));
      STDERR->printf("[Win32::API] dwBufferSize: %#08x\n", $tmp_coord);
      STDERR->printf("[Win32::API] dwBufferCoord: %#08x\n", 0);
      STDERR->printf("[Win32::API] sizeof(SMALL_RECT*): %u\n", PTR_SIZE);
      STDERR->printf("[Win32::API] lpWriteRegion: %#08x\n", $uintptr);
    }
    $proc_write_console_output->($h, $chars, $tmp_coord, 0, $uintptr);
  };
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub write_console_output_character { # $bSucceeded ($hConsoleOutput, $lpCharacter, \%dwWriteCoord)
  my ($h, $chars, $pos) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 3                   ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)              ? ERROR_INVALID_HANDLE
        : !defined(_STRING($chars)) ? ERROR_INVALID_PARAMETER
        : !coord($pos)              ? ERROR_INVALID_PARAMETER
        : 0
        ;

  my $err;
  my $r0 = $proc_write_console_output_character->(
    $h, $chars, $pos->{x}, $pos->{y}
  );
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub write_console_output_attribute { # $bSucceeded ($hConsoleOutput, $lpAttribute, \%dwWriteCoord)
  my ($h, $attrs, $pos) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 3                       ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)                  ? ERROR_INVALID_HANDLE
        : !defined(_NONNEGINT($attrs))  ? ERROR_INVALID_PARAMETER
        : !coord($pos)                  ? ERROR_INVALID_PARAMETER
        : 0
        ;

  my $err;
  my $r0 = $proc_write_console_output_attribute->(
    $h, chr($attrs), $pos->{x}, $pos->{y}
  );
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub set_console_cursor_info { # $bSucceeded ($hConsoleOutput, \%lpConsoleCursorInfo)
  my ($h, $info) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 2                     ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)                ? ERROR_INVALID_HANDLE
        : !_HASH($info)               ? ERROR_INVALID_PARAMETER
        : !console_cursor_info($info) ? ERROR_INVALID_PARAMETER
        : 0
        ;

  my $err;
  my $r0 = $proc_set_console_cursor_info->(
    $h, $info->{size}, $info->{visible}
  );
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub get_console_cursor_info { # $bSucceeded ($hConsoleOutput, \%lpConsoleCursorInfo)
  my ($h, $info) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 2                 ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)            ? ERROR_INVALID_HANDLE
        : !defined(_HASH0($info)) ? ERROR_INVALID_PARAMETER
        : readonly(%$info)        ? ERROR_INVALID_CRUNTIME_PARAMETER
        : 0
        ;

  my $err;
  my $r0 = do { # proc_get_console_cursor_info
    my @info = $proc_get_console_cursor_info->($h);
    my $r = @info >= 2;
    if ($r) {
      $info->{size} = shift @info;
      $info->{visible} = shift @info;
    }
    $r;
  };
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub set_console_cursor_position { # $bSucceeded ($hConsoleOutput, $dwCursorPosition)
  my ($h, $pos) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 2       ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)  ? ERROR_INVALID_HANDLE
        : !coord($pos)  ? ERROR_INVALID_PARAMETER
        : 0
        ;

  my $err;
  my $r0 = $proc_set_console_cursor_position->(
    $h, $pos->{x}, $pos->{y}
  );
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub read_console_input { # $bSucceeded ($hConsoleInput, \%lpBuffer)
  my ($h, $record) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 2                   ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)              ? ERROR_INVALID_HANDLE
        : !defined(_HASH0($record)) ? ERROR_INVALID_PARAMETER
        : readonly(%$record)        ? ERROR_INVALID_CRUNTIME_PARAMETER
        : 0
        ;

  my $err;
  my $r0 = do { # proc_read_console_input
    my $buf = pack('L5', (0) x 5);
    my $uintptr = unpack(UINT_PTR, pack('P', $buf));
    my $r = $proc_read_console_input->($h, $uintptr, 1, $tmp_arg);
    if ($r) {
      my @ev = unpack('L', $buf);
      $record->{event_type} = unpack('L', $buf);
      switch: for ($record->{event_type}) {
        case: KEY_EVENT == $_ and do {
          push @ev, unpack('x4'.'LSSSSL', $buf);
          $record->{event} = {
            key_down          => $ev[bKeyDown],
            repeat_count      => $ev[wRepeatCount],
            virtual_key_code  => $ev[wVirtualKeyCode],
            virtual_scan_code => $ev[wVirtualScanCode],
            unicode_char      => $ev[UnicodeChar],
            control_key_state => $ev[dwControlKeyState],
          };
          last;
        };
        case: MOUSE_EVENT == $_ and do {
          push @ev, unpack('x4'.'LLLL', $buf);
          my ($x, $y) = unpack('SS', pack('V', $ev[dwMousePosition]));
          $record->{event} = {
            mouse_pos => {
              x => $x,
              y => $y,
            },
            button_state       => $ev[dwButtonState],
            control_key_state  => $ev[dwControlKeyState],
            event_flags        => $ev[dwEventFlags],
          };
          last;
        };
        case: WINDOW_BUFFER_SIZE_EVENT == $_ and do {
          push @ev, unpack('x4'.'L', $record);
          my ($x, $y) = unpack('SS', pack('V', $ev[dwSize]));
          $record->{event} = {
            size => {
              x => $x,
              y => $y,
            },
          };
          last;
        };
      }
    }
    $r;
  };
  # my $r0 = do { # proc_read_console_input
  #   state $lpBuffer = do {
  #     my $record = Win32::API::Struct->new('INPUT_RECORD');
  #     map { $record->{$_} = 0 } qw( EventType d0 w1 w2 w3 w4 d5 );
  #     $record;
  #   };
  #   my $r = $proc_read_console_input->($h, $lpBuffer, 1, $tmp_arg);
  #   if ($r) {
  #     $record->{event_type} = $lpBuffer->{EventType};
  #     $lpBuffer->{EventType} = 0;
  #     switch: for ($record->{event_type}) {
  #       case: key_event == $_ and do {
  #         $record->{event} = {
  #           key_down          => $lpBuffer->{d0},
  #           repeat_count      => $lpBuffer->{w1},
  #           virtual_key_code  => $lpBuffer->{w2},
  #           virtual_scan_code => $lpBuffer->{w3},
  #           unicode_char      => $lpBuffer->{w4},
  #           control_key_state => $lpBuffer->{d5},
  #         };
  #         map { $lpBuffer->{$_} = 0 } qw( d0 w1 w2 w3 w4 d5 );
  #         last;
  #       };
  #       case: mouse_event == $_ and do {
  #         my ($x, $y) = unpack('SS', pack('V', $lpBuffer->{d0}));
  #         $record->{event} = {
  #           mouse_pos => {
  #             x => $x,
  #             y => $y,
  #           },
  #           button_state       => $lpBuffer->{w1},
  #           control_key_state  => $lpBuffer->{w3},
  #           event_flags        => $lpBuffer->{d5},
  #         };
  #         map { $lpBuffer->{$_} = 0 } qw( d0 w1 w3 d5 );
  #         last;
  #       };
  #       case: window_buffer_size_event == $_ and do {
  #         my ($x, $y) = unpack('SS', pack('V', $lpBuffer->{d0}));
  #         $record->{event} = {
  #           size => {
  #             x => $x,
  #             y => $y,
  #           },
  #         };
  #         last;
  #       };
  #     }
  #   }
  #   $r;
  # };
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub get_console_mode { # $bSucceeded ($hConsoleHandle, \$lpMode)
  my ($h, $mode) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 2                   ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)              ? ERROR_INVALID_HANDLE
        : !defined(_SCALAR0($mode)) ? ERROR_INVALID_PARAMETER
        : readonly($$mode)          ? ERROR_INVALID_CRUNTIME_PARAMETER
        : 0
        ;

  my $err;
  my $r0 = do { # proc_get_console_mode
    Win32::SetLastError(0);
    $$mode = $proc_get_console_mode->($h);
    Win32::GetLastError() == 0;
  };
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub set_console_mode { # $bSucceeded ($hConsoleHandle, $lpMode)
  my ($h, $mode) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 2                     ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)                ? ERROR_INVALID_HANDLE
        : !defined(_NONNEGINT($mode)) ? ERROR_INVALID_PARAMETER
        : 0
        ;

  my $err;
  my $r0 = $proc_set_console_mode->($h, $mode);
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub fill_console_output_character { # $bSucceeded ($hConsoleOutput, $cCharacter, $nLength)
  my ($h, $char, $n) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 3                   ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)              ? ERROR_INVALID_HANDLE
        : !defined(_STRING($char))  ? ERROR_INVALID_PARAMETER
        : length($char) != 1        ? ERROR_INVALID_DATA
        : !defined(_NONNEGINT($n))  ? ERROR_INVALID_PARAMETER
        : 0
        ;

  my $err;
  my $tmp_coord = coord(0, 0);
  my $r0 = $proc_fill_console_output_character->(
    $h, $char, $n, $tmp_coord->{x}, $tmp_coord->{y}
  );
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub fill_console_output_attribute { # $bSucceeded ($hConsoleOutput, $wAttribute, $nLength)
  my ($h, $attr, $n) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 3                     ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)                ? ERROR_INVALID_HANDLE
        : !defined(_NONNEGINT($attr)) ? ERROR_INVALID_PARAMETER
        : !defined(_NONNEGINT($n))    ? ERROR_INVALID_PARAMETER
        : 0
        ;

  my $err;
  my $tmp_coord = coord(0, 0);
  my $r0 = $proc_fill_console_output_attribute->(
    $h, $attr, $n, $tmp_coord->{x}, $tmp_coord->{y}
  );
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub create_event { # $handle|undef ()
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ ? ERROR_BAD_ARGUMENTS : 0;

  my $err;
  my $r0 = $proc_create_event->(undef, 0, 0, undef);
  my $e1 = $^E + 0;
  if ($r0 == 0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : $r0;
}

sub wait_for_multiple_objects { # $bSucceeded (\@lpHandles)
  my ($objects) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 1                           ? ERROR_BAD_ARGUMENTS
        : !defined(_ARRAY($objects))        ? ERROR_INVALID_PARAMETER
        : !(any { _POSINT($_) } @$objects)  ? ERROR_INVALID_DATA
        : 0
        ;

  my $err;
  my $r0 = do { # proc_wait_for_multiple_objects
    # https://stackoverflow.com/a/64068027
    my $len = @$objects;
    my $handles = pack(HANDLE . $len, @$objects);
    my $uintptr = unpack(UINT_PTR, pack('P', $handles));
    if ($Win32::API::DEBUG) {
      STDERR->printf("[Win32::API] WaitForMultipleObjects");
      STDERR->printf("[Win32::API] sizeof(HANDLE*): %u\n", PTR_SIZE);
      STDERR->printf("[Win32::API] nCount: %d\n", $len);
      STDERR->printf("[Win32::API] lpHandles: %#08x\n", $uintptr);
      STDERR->printf("[Win32::API] bWaitAll: %d\n", 0);
      STDERR->printf("[Win32::API] dwMilliseconds: %#08x\n", INFINITE);
    }
    $proc_wait_for_multiple_objects->($len, $uintptr, 0, INFINITE);
  };
  my $e1 = $^E + 0;
  if ($r0 == WAIT_FAILED) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub set_event { # $bSucceeded ($hEvent)
  my ($ev) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 1       ? ERROR_BAD_ARGUMENTS
        : !_POSINT($ev) ? ERROR_INVALID_HANDLE
        : 0
        ;

  my $err;
  my $r0 = $proc_set_event->($ev);
  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

sub get_current_console_font { # $bSucceeded ($hConsoleOutput, \%dwFontSize)
  my ($h, $info) = @_;
  (STRICT ? croak(usage("$^E", __FILE__, __FUNCTION__)) : return) if
    $^E = @_ != 2                 ? ERROR_BAD_ARGUMENTS
        : !_POSINT($h)            ? ERROR_INVALID_HANDLE
        : !defined(_HASH0($info)) ? ERROR_INVALID_PARAMETER
        : readonly(%$info)        ? ERROR_INVALID_CRUNTIME_PARAMETER
        : 0
        ;

  my $err;
  my $r0 = do { # proc_get_current_console_font
    my $font = pack('L2', (0) x 2);
    my $uintptr = unpack(UINT_PTR, pack('P', $font));
    my $r = $proc_get_current_console_font->($h, 0, $uintptr);
    if ($r) {
      my @font = unpack('LL', $font);
      $info->{font} = $font[nFont];
      my ($x, $y) = unpack('SS', pack('V', $font[dwFontSize]));
      $info->{font_size} = {
        x => $x,
        y => $y,
      };
    }
    $r;
  };
  # my $r0 = do { # proc_get_current_console_font
  #   state $lpConsoleCurrentFont = Win32::API::Struct->new('CONSOLE_FONT_INFO');
  #   $lpConsoleCurrentFont->{nFont} = 0;
  #   $lpConsoleCurrentFont->{dwFontSize} = 0;
  #   my $r = $proc_get_current_console_font->($h, 0, $lpConsoleCurrentFont);
  #   if ($r) {
  #     $info->{font} = $lpConsoleCurrentFont->{nFont};
  #     (
  #       $info->{font_size}->{x},
  #       $info->{font_size}->{y},
  #     ) = unpack 'SS', pack 'V', $lpConsoleCurrentFont->{dwFontSize};
  #   }
  #   $r;
  # };

  my $e1 = $^E + 0;
  if (!$r0) {
    if ($e1) {
      $err = $e1;
    } else {
      $err = $^E = WSAEINVAL;
    }
  }
  $err ? return : "0E0";
}

# ------------------------------------------------------------------------
# Functions --------------------------------------------------------------
# ------------------------------------------------------------------------

#
sub get_cursor_position { # \%dwCursorPosition ($hConsoleOutput)
  my ($out) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1          ? EINVAL
        : @_ > 1          ? E2BIG
        : !_POSINT($out)  ? EBADF
        : 0
        ;

  get_console_screen_buffer_info($out, $tmp_info)
    or die $^E;
  return {%{ $tmp_info->{cursor_position} }};
}

sub get_term_size { # \%dwSize, \%srWindow ($hConsoleOutput)
  my ($out) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1          ? EINVAL
        : @_ > 1          ? E2BIG
        : !_POSINT($out)  ? EBADF
        : 0
        ;

  get_console_screen_buffer_info($out, $tmp_info)
    or die $^E;
  return (
    { %{ $tmp_info->{size} }}, 
    { %{ $tmp_info->{window} }}, 
  );
}

sub get_win_min_size { # \%dwSize ($hConsoleOutput)
  my ($out) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1          ? EINVAL
        : @_ > 1          ? E2BIG
        : !_POSINT($out)  ? EBADF
        : 0
        ;

  my $x = $get_system_metrics->(SM_CXMIN) || 0;
  my $y = $get_system_metrics->(SM_CYMIN) || 0;
  if ($x == 0 || $y == 0) {
    die $^E if $^E;
  }

  get_current_console_font($out, $tmp_finfo)
    or die $^E;

  # Windows Terminal always returns size {x => 0, y => 16}
  # https://github.com/microsoft/terminal/issues/6395#issue-633416220
  return coord(0, 0)
      if $tmp_finfo->{font_size}->{x} == 0 
      || $tmp_finfo->{font_size}->{y} == 0;

  return coord({
    x => POSIX::ceil($x / ($tmp_finfo->{font_size}->{x})),
    y => POSIX::ceil($y / ($tmp_finfo->{font_size}->{y})),
  });
}

sub get_win_size { # \%dwSize ($hConsoleOutput)
  my ($out) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1          ? EINVAL
        : @_ > 1          ? E2BIG
        : !_POSINT($out)  ? EBADF
        : 0
        ;

  get_console_screen_buffer_info($out, $tmp_info)
    or die $^E;

  my $min_size = get_win_min_size($out);

  my $size = coord({
    x => $tmp_info->{window}->{right} - $tmp_info->{window}->{left} + 1,
    y => $tmp_info->{window}->{bottom} - $tmp_info->{window}->{top} + 1,
  });

  if ($size->{x} < $min_size->{x}) {
    $size->{x} = $min_size->{x};
  }

  if ($size->{y} < $min_size->{y}) {
    $size->{y} = $min_size->{y};
  }

  return $size;
}

sub fix_win_size { # $bSucceeded ($hConsoleOutput, \%dwSize)
  my ($out, $size) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2            ? EINVAL
        : @_ > 2            ? E2BIG
        : !_POSINT($out)    ? EBADF
        : !coord($size)     ? EINVAL
        : readonly(%$size)  ? EFAULT
        : 0
        ;

  my $window = small_rect();
  $window->{top} = 0;
  $window->{bottom} = $size->{y} - 1;
  $window->{left} = 0;
  $window->{right} = $size->{x} - 1;
  return set_console_window_info($out, $window);
}

sub update_size_maybe { # $bSucceeded ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  my $size = get_win_size($out);
  if ($size->{x} != $term_size->{x} || $size->{y} != $term_size->{y}) {
    set_console_screen_buffer_size($out, $size);
    fix_win_size($out, $size);
    $term_size = { %$size };
    $back_buffer->resize($size->{x}, $size->{y});
    $front_buffer->resize($size->{x}, $size->{y});
    $front_buffer->clear();
    clear();

    my $area = $size->{x} * $size->{y};
    if (@$charbuf < $area) {
      $charbuf = [];
    }
  }
  return "0E0";
}

sub append_diff_line { # $nColumns ($wRow)
  my ($y) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                    ? EINVAL
        : @_ > 1                    ? E2BIG
        : !defined(_NONNEGINT($y))  ? EINVAL
        : 0
        ;

  my $n = 0;
  my $width = $front_buffer->{width};
  my $back_buffer_cells = $back_buffer->{cells};
  my $front_buffer_cells = $front_buffer->{cells};
  my $cell_offset = $y*$width;
  for my $x (0..$width-1) {
    my $back = $back_buffer_cells->[$cell_offset];
    my $front = $front_buffer_cells->[$cell_offset];
    my ($attr, $char) = cell_to_char_info($back);
    push @$charbuf, char_info{attr => $attr, char => $char};
    map { $front->{$_} = $back->{$_} } keys %$back;
    q/*
    {
      require Data::Dumper;
      local $Data::Dumper::Varname = 'pos';
      Win32::OutputDebugString(Data::Dumper::Dumper({ x => $x, y => $y }));
      local $Data::Dumper::Varname = 'back_buffer';
      Win32::OutputDebugString(Data::Dumper::Dumper($back_buffer->{cells}->[$cell_offset]));
      local $Data::Dumper::Varname = 'char_info';
      Win32::OutputDebugString(Data::Dumper::Dumper([ char_info{ attr => $attr, char => $char } ]));
    }
    */ if 0;
    $n++;
    my $w = wcwidth($back->{Ch});
    if ($w <= 0 || $w == 2 && chr($back->{Ch}) =~ /\p{InEastAsianAmbiguous}/) {
      $w = 1;
    }
    $x += $w;
    # If not CJK, fill trailing space with whitespace
    if (!$is_cjk && $w == 2) {
      push @$charbuf, char_info{attr => $attr, char => ord(' ')};
    }
  } continue { $cell_offset++ }
  return $n;
}

# compares 'back_buffer' with 'front_buffer' and prepares all changes in the form of
# 'diff_msg's in the 'diff_buf'
sub prepare_diff_messages { # $bSucceeded ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  # clear buffers
  $diffbuf = [];
  $charbuf = [];

  my $diff = diff_msg();
  my $gbeg = 0;
  my $height = $front_buffer->{height};
  my $width = $front_buffer->{width};
  my $back_buffer_cells = $back_buffer->{cells};
  my $front_buffer_cells = $front_buffer->{cells};
  my $line_offset = 0;
  for my $y (0..$height-1) {
    my $same = TRUE;
    my $cell_offset = $line_offset;
    for my $x (0..$width-1) {
      my $back = $back_buffer_cells->[$cell_offset];
      my $front = $front_buffer_cells->[$cell_offset];
      q/*
      {
        require Data::Dumper;
        use warnings FATAL => 'all';
        local $Data::Dumper::Varname = 'back';
        Win32::OutputDebugString(Data::Dumper::Dumper($back));
        local $Data::Dumper::Varname = 'front';
        Win32::OutputDebugString(Data::Dumper::Dumper($front));
      }
      */ if 0;
      if ( $back->{Ch} != $front->{Ch}
        || $back->{Fg} != $front->{Fg}
        || $back->{Bg} != $front->{Bg}
      ) {
        $same = FALSE;
        last;
      }
    } continue { $cell_offset++ }
    if ($same && $diff->{lines} > 0) {
      push @$diffbuf, $diff;
      $diff = diff_msg();
    }
    if (!$same) {
      my $beg = @$charbuf;
      my $end = $beg + append_diff_line($y);
      if ($diff->{lines} == 0) {
        $diff->{pos} = $y;
        $gbeg = $beg;
      }
      $diff->{lines}++;
      $diff->{chars} = [ @$charbuf[$gbeg..$end-1] ];
    }
  } continue { $line_offset += $width }
  if ($diff->{lines} > 0) {
    push @$diffbuf, $diff;
    $diff = diff_msg();
  }
  return "0E0";
}

sub get_ct { # $uColor (\%rgColorTable, $iColor)
  my ($table, $idx) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if STRICT and
    $!  = @_ < 2                      ? EINVAL
        : @_ > 2                      ? E2BIG
        : !defined(_ARRAY($table))    ? EINVAL
        : !defined(_NONNEGINT($idx))  ? EINVAL
        : 0
        ;

  $idx &= 0x0f;
  if ($idx >= @$table) {
    $idx = @$table - 1
  }
  return $table->[$idx];
}

sub cell_to_char_info { # $uAttributes, $uChar (\%Cell)
  my ($c) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if STRICT and
    $!  = @_ < 1    ? EINVAL
        : @_ > 1    ? E2BIG
        : !Cell($c) ? EINVAL
        : 0
        ;

  my $attr =  get_ct($color_table_fg, $c->{Fg})
            | get_ct($color_table_bg, $c->{Bg});
  if ($c->{Fg} & AttrReverse | $c->{Bg} & AttrReverse) {
    $attr = ($attr & 0xf0) >> 4 | ($attr & 0x0f) << 4;
  }
  if ($c->{Fg} & AttrBold) {
    $attr |= FOREGROUND_INTENSITY;
  }
  if ($c->{Bg} & AttrBold) {
    $attr |= BACKGROUND_INTENSITY;
  }

  # This works in the basic multilingual plane but will fail with anything else
  # https://stackoverflow.com/a/63968958
  my $wc = $c->{Ch};
  if ($wc > 0xffff) {
    my ($r0, $r1) = unpack('S*', Encode::encode("UTF-16LE", chr($c->{Ch})));
    $wc = 0xfffd if $r0 == 0xfffd;
  }
  return ($attr, $wc);
}

sub move_cursor { # $bSucceeded ($uLeft, $uTop)
  my ($x, $y) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                    ? EINVAL
        : @_ > 2                    ? E2BIG
        : !defined(_NONNEGINT($x))  ? EINVAL
        : !defined(_NONNEGINT($y))  ? EINVAL
        : 0
        ;

  set_console_cursor_position($out, coord($x, $y))
    or die $^E;
  return "0E0";
}

sub show_cursor { # $bSucceeded ($bVisible)
  my ($visible) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1        ? EINVAL
        : @_ > 1        ? E2BIG
        : ref($visible) ? EINVAL
        : 0
        ;

  my $v = $visible ? 1 : 0;

  my $info = console_cursor_info();
  $info->{size}    = 100;
  $info->{visible} = $v;
  set_console_cursor_info($out, $info)
    or die $^E;
  return "0E0";
}

sub clear { # $bSucceeded ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  my $char = ' ';
  my $attr = $foreground | $background;

  my $area = $term_size->{x} * $term_size->{y};
  fill_console_output_attribute($out, $attr, $area) 
    or die $^E;
  fill_console_output_character($out, $char, $area)
    or die $^E;
  if (!is_cursor_hidden($cursor_x, $cursor_y)) {
    move_cursor($cursor_x, $cursor_y);
  }
  return "0E0";
}

sub key_event_record_to_event { # \%Event, $bSucceeded (\%lpBuffer)
  my ($r) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                ? EINVAL
        : @_ > 1                ? E2BIG
        : !key_event_record($r) ? EINVAL
        : 0
        ;
  
  if ($r->{key_down} == 0) {
    return (Event(), FALSE);
  }

  my $e = Event{Type => EventKey};
  {
    lock $input_mode;
    if ($input_mode & InputAlt) {
      if ($alt_mode_esc) {
        $e->{Mod} = ModAlt;
        $alt_mode_esc = FALSE;
      }
      if ($r->{control_key_state} & (LEFT_ALT_PRESSED | RIGHT_ALT_PRESSED)) {
        $e->{Mod} = ModAlt;
      }
    }
  }  

  my $ctrlpressed = $r->{control_key_state}
                  & (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED);

  if ($r->{virtual_key_code} >= vk_f1 && $r->{virtual_key_code} <= vk_f12) {
    switch: for ($r->{virtual_key_code}) {
      case: vk_f1 == $_ and do {
        $e->{Key} = KeyF1;
        last;
      };
      case: vk_f2 == $_ and do {
        $e->{Key} = KeyF2;
        last;
      };
      case: vk_f3 == $_ and do {
        $e->{Key} = KeyF3;
        last;
      };
      case: vk_f4 == $_ and do {
        $e->{Key} = KeyF4;
        last;
      };
      case: vk_f5 == $_ and do {
        $e->{Key} = KeyF5;
        last;
      };
      case: vk_f6 == $_ and do {
        $e->{Key} = KeyF6;
        last;
      };
      case: vk_f7 == $_ and do {
        $e->{Key} = KeyF7;
        last;
      };
      case: vk_f8 == $_ and do {
        $e->{Key} = KeyF8;
        last;
      };
      case: vk_f9 == $_ and do {
        $e->{Key} = KeyF9;
        last;
      };
      case: vk_f10 == $_ and do {
        $e->{Key} = KeyF10;
        last;
      };
      case: vk_f11 == $_ and do {
        $e->{Key} = KeyF11;
        last;
      };
      case: vk_f12 == $_ and do {
        $e->{Key} = KeyF12;
        last;
      };
      default: {
        die("unreachable");
      }
    }

    return ($e, TRUE);
  }

  if ($r->{virtual_key_code} <= vk_delete) {
    switch: for ($r->{virtual_key_code}) {
      case: vk_insert == $_ and do {
        $e->{Key} = KeyInsert;
        last;
      };
      case: vk_delete == $_ and do {
        $e->{Key} = KeyDelete;
        last;
      };
      case: vk_home == $_ and do {
        $e->{Key} = KeyHome;
        last;
      };
      case: vk_end == $_ and do {
        $e->{Key} = KeyEnd;
        last;
      };
      case: vk_pgup == $_ and do {
        $e->{Key} = KeyPgup;
        last;
      };
      case: vk_pgdn == $_ and do {
        $e->{Key} = KeyPgdn;
        last;
      };
      case: vk_arrow_up == $_ and do {
        $e->{Key} = KeyArrowUp;
        last;
      };
      case: vk_arrow_down == $_ and do {
        $e->{Key} = KeyArrowDown;
        last;
      };
      case: vk_arrow_left == $_ and do {
        $e->{Key} = KeyArrowLeft;
        last;
      };
      case: vk_arrow_right == $_ and do {
        $e->{Key} = KeyArrowRight;
        last;
      };
      case: vk_backspace == $_ and do {
        if ($ctrlpressed) {
          $e->{Key} = KeyBackspace2;
        } else {
          $e->{Key} = KeyBackspace;
        }
        last;
      };
      case: vk_tab == $_ and do {
        $e->{Key} = KeyTab;
        last;
      };
      case: vk_enter == $_ and do {
        if ($ctrlpressed) {
          $e->{Key} = KeyCtrlJ;
        } else {
          $e->{Key} = KeyEnter;
        }
        last;
      };
      case: vk_esc == $_ and do {
        lock $input_mode;
        if ($input_mode & InputEsc) {
          $e->{Key} = KeyEsc;
        } elsif ($input_mode & InputAlt) {
          $alt_mode_esc = TRUE;
          return (Event(), FALSE);
        }
        last;
      };
      case: vk_space == $_ and do {
        if ($ctrlpressed) {
          # manual return here, because KeyCtrlSpace is zero
          $e->{Key} = KeyCtrlSpace;
          return ($e, TRUE);
        } else {
          $e->{Key} = KeySpace;
        }
        last;
      };
    }

    if ($e->{Key}) {
      return ($e, TRUE);
    }
  }

  if ($ctrlpressed) {
    if ( $r->{unicode_char} >= KeyCtrlA
      && $r->{unicode_char} <= KeyCtrlRsqBracket
    ) {
      lock $input_mode;
      $e->{Key} = $r->{unicode_char};
      if (($input_mode & InputAlt) && $e->{Key} == KeyEsc) {
        $alt_mode_esc = TRUE;
        return (Event(), FALSE);
      }
      return ($e, TRUE);
    }
    switch: for ($r->{virtual_key_code}) {
      local $==$_; # use 'any { $===$_} (1..n)' instead of '$_ ~~ [1..n]'
      case: any { $===$_} (192, 50) and do {
        # manual return here, because KeyCtrl2 is zero
        $e->{Key} = KeyCtrl2;
        return ($e, TRUE);
      };
      case: 51 == $_ and do {
        lock $input_mode;
        if ($input_mode & InputAlt) {
          $alt_mode_esc = TRUE;
          return (Event(), FALSE);
        }
        $e->{Key} = KeyCtrl3;
        last;
      };
      case: 52 == $_ and do {
        $e->{Key} = KeyCtrl4;
        last;
      };
      case: 53 == $_ and do {
        $e->{Key} = KeyCtrl5;
        last;
      };
      case: 54 == $_ and do {
        $e->{Key} = KeyCtrl6;
        last;
      };
      case: any { $===$_} (189, 191, 55) and do {
        $e->{Key} = KeyCtrl7;
        last;
      };
      case: any { $===$_} (8, 56) and do {
        $e->{Key} = KeyCtrl8;
        last;
      };
    }
  
    if ($e->{Key}) {
      return ($e, TRUE);
    }
  }

  if ($r->{unicode_char}) {
    $e->{Ch} = $r->{unicode_char};
    return ($e, TRUE);
  }

  return (Event(), FALSE);
}

sub input_event_producer { # $bSucceeded ()
  my $r;
  my $last_button;
  my $last_button_pressed;
  my $last_state = 0;
  my ($last_x, $last_y) = (-1, -1);
  my $handles = [$in, $interrupt];
  LOOP: for (;;) {
    if (!wait_for_multiple_objects($handles)) {
      $input_comm->enqueue( Event{Type => EventError, Err => $^E} );
      # Win32::OutputDebugString(§input_comm: $^E");
    }

    select: {
      case: $cancel_comm->dequeue_nb() and do {
        $cancel_done_comm->enqueue(TRUE);
        # Win32::OutputDebugString('cancel_comm: TRUE');
        return;
      }
    }

    if (!read_console_input($in, $r = {})) {
      $input_comm->enqueue( Event{Type => EventError, Err => $^E} );
      # Win32::OutputDebugString(§input_comm: $^E");
    }

    switch: for ($r->{event_type}) {
      case: key_event == $_ and do {
        my $kr = key_event_record($r->{event});
        # Win32::OutputDebugString("input_comm: @{[%$kr]}");
        my ($ev, $ok) = key_event_record_to_event($kr);
        if ($ok) {
          for (my $i = 0; $i < $kr->{repeat_count}; $i++) {
            $input_comm->enqueue({ %$ev });
            # Win32::OutputDebugString("input_comm: @{[%$ev]}");
          }
        }
        last;
      };
      case: window_buffer_size_event == $_ and do {
        my $sr = window_buffer_size_record($r->{event});
        $input_comm->enqueue(
          Event{
            Type    => EventResize,
            Width   => $sr->{size}->{x},
            Height  => $sr->{size}->{y},
          }
        );
        # Win32::OutputDebugString("input_comm: @{[%$sr]}");
        last;
      };
      case: mouse_event == $_ and do {
        my $mr = mouse_event_record($r->{event});
        # Win32::OutputDebugString("input_comm: @{[%$mr]}");
        my $ev = Event{Type => EventMouse};
        switch: for ($mr->{event_flags}) {
          local $==$_; # use 'any { $===$_} (1..n)' instead of '$_ ~~ [1,2,..]'
          case: any { $===$_} (0, 2) and do {
            # single or double click
            my $cur_state = $mr->{button_state};
            switch: {
              case: !($last_state & mouse_lmb) && ($cur_state & mouse_lmb) 
              and do {
                $last_button = MouseLeft;
                $last_button_pressed = $last_button;
                last;
              };
              case: !($last_state & mouse_rmb) && ($cur_state & mouse_rmb)
              and do {
                $last_button = MouseRight;
                $last_button_pressed = $last_button;
                last;
              };
              case: !($last_state & mouse_mmb) && ($cur_state & mouse_mmb)
              and do {
                $last_button = MouseMiddle;
                $last_button_pressed = $last_button;
                last;
              };
              case: ($last_state & mouse_lmb) && !($cur_state & mouse_lmb)
              and do {
                $last_button = MouseRelease;
                last;
              };
              case: ($last_state & mouse_rmb) && !($cur_state & mouse_rmb)
              and do {
                $last_button = MouseRelease;
                last;
              };
              case: ($last_state & mouse_mmb) && !($cur_state & mouse_mmb)
              and do {
                $last_button = MouseRelease;
                last;
              };
              default: {
                $last_state = $cur_state;
                next LOOP;
              }
            }
            $last_state = $cur_state;
            $ev->{Key} = $last_button;
            ($last_x, $last_y) = ($mr->{mouse_pos}->{x}, $mr->{mouse_pos}->{y});
            $ev->{MouseX} = $last_x;
            $ev->{MouseY} = $last_y;
            last;
          };
          case: 1 == $_ and do {
            # mouse motion
            my ($x, $y) = ($mr->{mouse_pos}->{x}, $mr->{mouse_pos}->{y});
            if ($last_state != 0 && ($last_x != $x || $last_y != $y)) {
              $ev->{Key} = $last_button_pressed;
              $ev->{Mod} = ModMotion;
              $ev->{MouseX} = $x;
              $ev->{MouseY} = $y;
              ($last_x, $last_y) = ($x, $y);
            } else {
              $ev->{Type} = EventNone;
            }
            last;
          };
          case: 4 == $_ and do {
            # mouse wheel
            my $n = $mr->{button_state} >> 16;
            if ($n > 0) {
              $ev->{Key} = MouseWheelUp;
            } else {
              $ev->{Key} = MouseWheelDown;
            }
            ($last_x, $last_y) = ($mr->{mouse_pos}->{x}, $mr->{mouse_pos}->{y});
            $ev->{MouseX} = $last_x;
            $ev->{MouseY} = $last_y;
            last;
          };
          default: {
            $ev->{Type} = EventNone;
          }
        }
        if ($ev->{Type} != EventNone) {
          $input_comm->enqueue({ %$ev });
          # Win32::OutputDebugString("input_comm: @{[%$ev]}");
        }
        last;
      };
    }
  }
  return "0E0";
}

1;

__END__

=head1 NAME

Termbox::Go::Win32::Backend - Win32 Backend implementation for Termbox

=head1 DESCRIPTION

This module contains some Windows native functions for the implementation of 
Termbox for Win32.

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

L<Win32::API>

L<Win32::Console>

L<Unicode::EastAsianWidth>

L<Unicode::EastAsianWidth::Detect>

=head1 SEE ALSO

L<termbox_windows.go|https://raw.githubusercontent.com/nsf/termbox-go/master/termbox_windows.go>

L<syscalls_windows.go|https://raw.githubusercontent.com/nsf/termbox-go/master/syscalls_windows.go>

=cut


#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################


=head1 SUBROUTINES

=head2 append_diff_line

 my $nColumns = append_diff_line($wRow);

=head2 cell_to_char_info

 my ($uAttributes, $uChar) = cell_to_char_info(\%Cell);

=head2 char_info

 my \%hashref | undef = char_info( | @array | \%hashref);

Usage:
 my \%hashref = char_info();
 my \%hashref = char_info($char, $attr) // die;
 my \%hashref = char_info({char => $char, attr => $attr}) // die;


=head2 clear

 my $bSucceeded = clear();

=head2 console_cursor_info

 my \%hashref | undef = console_cursor_info( | @array | \%hashref);

Usage:
 my \%hashref = console_cursor_info();
 my \%hashref = console_cursor_info($size, $visible) // die;
 my \%hashref = console_cursor_info({
   size    => $size,
   visible => $visible,
 }) // die;


=head2 coord

 my \%hashref | undef = coord( | @array | \%hashref);

Usage:
 my \%hashref = coord();
 my \%hashref = coord($x, $y) // die;
 my \%hashref = coord({x => $x, y = $y}) // die;


=head2 create_console_screen_buffer

 my $handle | undef = create_console_screen_buffer();

=head2 create_event

 my $handle | undef = create_event();

=head2 diff_msg

 my \%hashref | undef = diff_msg( | @array | \%hashref);

Usage:
 my \%hashref = diff_msg();
 my \%hashref = diff_msg($pos, $lines, \@chars) // die;
 my \%hashref = diff_msg({
   pos   => $pos,
   lines => $lines,
   chars => \@chars,
 }) // die;


=head2 fill_console_output_attribute

 my $bSucceeded = fill_console_output_attribute($hConsoleOutput, $wAttribute, $nLength);

=head2 fill_console_output_character

 my $bSucceeded = fill_console_output_character($hConsoleOutput, $cCharacter, $nLength);

=head2 fix_win_size

 my $bSucceeded = fix_win_size($hConsoleOutput, \%dwSize);

=head2 get_console_cursor_info

 my $bSucceeded = get_console_cursor_info($hConsoleOutput, \%lpConsoleCursorInfo);

=head2 get_console_mode

 my $bSucceeded = get_console_mode($hConsoleHandle, \$lpMode);

=head2 get_console_screen_buffer_info

 my $bSucceeded = get_console_screen_buffer_info($hConsoleOutput, \%lpConsoleScreenBufferInfo);

=head2 get_ct

 my $uColor = get_ct(\%rgColorTable, $iColor);

=head2 get_current_console_font

 my $bSucceeded = get_current_console_font($hConsoleOutput, \%dwFontSize);

=head2 get_cursor_position

 my \%dwCursorPosition = get_cursor_position($hConsoleOutput);

=head2 get_term_size

 my (\%dwSize, \%srWindow) = get_term_size($hConsoleOutput);

=head2 get_win_min_size

 my \%dwSize = get_win_min_size($hConsoleOutput);

=head2 get_win_size

 my \%dwSize = get_win_size($hConsoleOutput);

=head2 input_event_producer

 my $bSucceeded = input_event_producer();

=head2 key_event_record

 my \%hashref | undef = key_event_record( | @array | \%hashref);

Usage:
 my \%hashref = key_event_record();
 my \%hashref = key_event_record(
   $key_down,
   $repeat_count,
   $virtual_key_code,
   $virtual_scan_code,
   $unicode_char,
   $control_key_state
 ) // die;
 my \%hashref = key_event_record({
   key_down          => $key_down,
   repeat_count      => $repeat_count,
   virtual_key_code  => $virtual_key_code,
   virtual_scan_code => $virtual_scan_code,
   unicode_char      => $unicode_char,
   control_key_state => $control_key_state,
 }) // die:


=head2 key_event_record_to_event

 my (\%Event, $bSucceeded) = key_event_record_to_event(\%lpBuffer);

=head2 mouse_event_record

 my \%hashref | undef = mouse_event_record( | \%hashref);

Usage:
 my \%hashref = mouse_event_record();
 my \%hashref = mouse_event_record({
   mouse_pos => {
     x => $x,
     y => $y,
   },
   button_state      => $button_state,
   control_key_state => $control_key_state,
   event_flags       => $event_flags,
 }) // die;


=head2 move_cursor

 my $bSucceeded = move_cursor($uLeft, $uTop);

=head2 prepare_diff_messages

 my $bSucceeded = prepare_diff_messages();

compares 'back_buffer' with 'front_buffer' and prepares all changes in the form of
'diff_msg's in the 'diff_buf'


=head2 read_console_input

 my $bSucceeded = read_console_input($hConsoleInput, \%lpBuffer);

=head2 set_console_active_screen_buffer

 my $bSucceeded = set_console_active_screen_buffer($hConsoleOutput);

=head2 set_console_cursor_info

 my $bSucceeded = set_console_cursor_info($hConsoleOutput, \%lpConsoleCursorInfo);

=head2 set_console_cursor_position

 my $bSucceeded = set_console_cursor_position($hConsoleOutput, $dwCursorPosition);

=head2 set_console_mode

 my $bSucceeded = set_console_mode($hConsoleHandle, $lpMode);

=head2 set_console_screen_buffer_size

 my $bSucceeded = set_console_screen_buffer_size($hConsoleOutput, \%dwSize);

=head2 set_console_window_info

 my $bSucceeded = set_console_window_info($hConsoleOutput, \%lpConsoleWindow);

=head2 set_event

 my $bSucceeded = set_event($hEvent);

=head2 show_cursor

 my $bSucceeded = show_cursor($bVisible);

=head2 small_rect

 my \%hashref | undef = small_rect( | @array | \%hashref);

Usage:
 my \%hashref = small_rect();
 my \%hashref = small_rect(
   $left,
   $top,
   $right,
   $bottom,
 ) // die;
 my \%hashref = small_rect({
   left    => $left,
   top     => $top,
   right   => $right,
   bottom  => $bottom,
 }) // die;


=head2 syscallHandle

 my $scalar | undef = syscallHandle( | $scalar);

Usage:
 $handle = syscallHandle();
 $handle = syscallHandle($handle) // die;


=head2 update_size_maybe

 my $bSucceeded = update_size_maybe();

=head2 wait_for_multiple_objects

 my $bSucceeded = wait_for_multiple_objects(\@lpHandles);

=head2 window_buffer_size_record

 my \%hashref | undef = window_buffer_size_record( | \%hashref);

Usage:
 my \%hashref = window_buffer_size_record();
 my \%hashref = window_buffer_size_record({x => $x, y => $y}) // die;


=head2 write_console_output

 my $bSucceeded = write_console_output($hConsoleOutput, $lpBuffer, \%lpWriteRegion);

=head2 write_console_output_attribute

 my $bSucceeded = write_console_output_attribute($hConsoleOutput, $lpAttribute, \%dwWriteCoord);

=head2 write_console_output_character

 my $bSucceeded = write_console_output_character($hConsoleOutput, $lpCharacter, \%dwWriteCoord);


=cut

