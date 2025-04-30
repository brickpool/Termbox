# ------------------------------------------------------------------------
#
#   Termbox Legacy API
#
#   Interface based on termbox2 v2.5.0-dev, 9. Feb 2024
#
#   Copyright (C) 2010-2020 nsf <no.smile.face@gmail.com>
#                 2015-2024 Adam Saponara <as@php.net>
#
# ------------------------------------------------------------------------
#   Author: 2024,2025 J. Schneider
# ------------------------------------------------------------------------

package Termbox::Go::Legacy;

# ------------------------------------------------------------------------
# Boilerplate ------------------------------------------------------------
# ------------------------------------------------------------------------

use 5.014;
use strict;
use warnings;

# version '...'
use version;
our $version = version->declare('v2.5.0_0');
our $VERSION = version->declare('v0.3.2');

# authority '...'
our $authority = 'github:adsr';
our $AUTHORITY = 'github:brickpool';

# ------------------------------------------------------------------------
# Imports ----------------------------------------------------------------
# ------------------------------------------------------------------------

require bytes; # not use, see https://perldoc.perl.org/bytes
use Carp qw( croak );
use Encode;
use English qw( -no_match_vars );
use List::Util 1.29 qw(
  all
  any
);
use Params::Util qw(
  _STRING
  _CLASSISA
  _NUMBER
  _POSINT
  _NONNEGINT
  _SCALAR0
  _HASH
  _INSTANCE
);
use POSIX qw( :errno_h );
use Scalar::Util qw( readonly );
use threads;
use Thread::Queue;
use Time::HiRes ();

use Termbox::Go::Devel qw(
  __FUNCTION__
  usage
);
use Termbox::Go::Common qw(
  :all 
  !:types
);

my %module = (
  darwin          => 'Terminal',
  dragonfly       => 'Terminal',
  freebsd         => 'Terminal',
  linux           => 'Terminal',
  netbsd          => 'Terminal',
  openbsd         => 'Terminal',
  MSWin32         => 'Win32',
);
# https://stackoverflow.com/a/72575526
$module{MSWin32} = 'WinVT' if $ENV{WT_SESSION};

my $module = $module{$OSNAME} || 'Terminal';

require "Termbox/Go/$module.pm";
my $termbox = "Termbox::Go::$module";
our @ISA = ($termbox);

# ------------------------------------------------------------------------
# Exports ----------------------------------------------------------------
# ------------------------------------------------------------------------

=head1 EXPORTS

Nothing per default, but can export the following per request:

  :all

    :api
      tb_init
      tb_shutdown
      tb_width
      tb_height
      tb_clear
      tb_present
      tb_invalidate
      tb_set_cursor
      tb_hide_cursor
      tb_set_cell
      tb_set_input_mode
      tb_set_output_mode
      tb_peek_event
      tb_poll_event
      tb_print
      tb_printf
      tb_utf8_char_length
      tb_utf8_char_to_unicode
      tb_utf8_unicode_to_char
      tb_last_errno
      tb_strerror
      tb_cell_buffer
      tb_version

    :const
      TB_VERSION_STR

    :keys
      TB_KEY_CTRL_TILDE
      TB_KEY_CTRL_2
      TB_KEY_CTRL_A
      TB_KEY_CTRL_B
      TB_KEY_CTRL_C
      TB_KEY_CTRL_D
      TB_KEY_CTRL_E
      TB_KEY_CTRL_F
      TB_KEY_CTRL_G
      TB_KEY_BACKSPACE
      TB_KEY_CTRL_H
      TB_KEY_TAB
      TB_KEY_CTRL_I
      TB_KEY_CTRL_J
      TB_KEY_CTRL_K
      TB_KEY_CTRL_L
      TB_KEY_ENTER
      TB_KEY_CTRL_M
      TB_KEY_CTRL_N
      TB_KEY_CTRL_O
      TB_KEY_CTRL_P
      TB_KEY_CTRL_Q
      TB_KEY_CTRL_R
      TB_KEY_CTRL_S
      TB_KEY_CTRL_T
      TB_KEY_CTRL_U
      TB_KEY_CTRL_V
      TB_KEY_CTRL_W
      TB_KEY_CTRL_X
      TB_KEY_CTRL_Y
      TB_KEY_CTRL_Z
      TB_KEY_ESC
      TB_KEY_CTRL_LSQ_BRACKET
      TB_KEY_CTRL_3
      TB_KEY_CTRL_4
      TB_KEY_CTRL_BACKSLASH
      TB_KEY_CTRL_5
      TB_KEY_CTRL_RSQ_BRACKET
      TB_KEY_CTRL_6
      TB_KEY_CTRL_7
      TB_KEY_CTRL_SLASH
      TB_KEY_CTRL_UNDERSCORE
      TB_KEY_SPACE
      TB_KEY_BACKSPACE2
      TB_KEY_CTRL_8
      TB_KEY_F1
      TB_KEY_F2
      TB_KEY_F3
      TB_KEY_F4
      TB_KEY_F5
      TB_KEY_F6
      TB_KEY_F7
      TB_KEY_F8
      TB_KEY_F9
      TB_KEY_F10
      TB_KEY_F11
      TB_KEY_F12
      TB_KEY_INSERT
      TB_KEY_DELETE
      TB_KEY_HOME
      TB_KEY_END
      TB_KEY_PGUP
      TB_KEY_PGDN
      TB_KEY_ARROW_UP
      TB_KEY_ARROW_DOWN
      TB_KEY_ARROW_LEFT
      TB_KEY_ARROW_RIGHT
      TB_KEY_BACK_TAB
      TB_KEY_MOUSE_LEFT
      TB_KEY_MOUSE_RIGHT
      TB_KEY_MOUSE_MIDDLE
      TB_KEY_MOUSE_RELEASE
      TB_KEY_MOUSE_WHEEL_UP
      TB_KEY_MOUSE_WHEEL_DOWN

    :color
      TB_DEFAULT
      TB_BLACK
      TB_RED
      TB_GREEN
      TB_YELLOW
      TB_BLUE
      TB_MAGENTA
      TB_CYAN
      TB_WHITE

    :attr
      TB_BOLD
      TB_UNDERLINE
      TB_REVERSE
      TB_ITALIC
      TB_BLINK
      TB_DIM
      TB_INVISIBLE
    :event
      TB_EVENT_KEY
      TB_EVENT_RESIZE
      TB_EVENT_MOUSE

    :mode
      TB_MOD_ALT
      TB_MOD_MOTION

    :input
      TB_INPUT_CURRENT
      TB_INPUT_ESC
      TB_INPUT_ALT
      TB_INPUT_MOUSE

    :output
      TB_OUTPUT_CURRENT
      TB_OUTPUT_NORMAL
      TB_OUTPUT_256
      TB_OUTPUT_216
      TB_OUTPUT_GRAYSCALE
      TB_OUTPUT_TRUECOLOR

    :types
      tb_cells
      tb_event

    :return
      TB_OK
      TB_ERR
      TB_ERR_NEED_MORE
      TB_ERR_INIT_ALREADY
      TB_ERR_INIT_OPEN
      TB_ERR_MEM
      TB_ERR_NO_EVENT
      TB_ERR_NO_TERM
      TB_ERR_NOT_INIT
      TB_ERR_OUT_OF_BOUNDS
      TB_ERR_READ
      TB_ERR_RESIZE_IOCTL
      TB_ERR_RESIZE_PIPE
      TB_ERR_RESIZE_SIGACTION
      TB_ERR_POLL
      TB_ERR_TCGETATTR
      TB_ERR_TCSETATTR
      TB_ERR_UNSUPPORTED_TERM
      TB_ERR_RESIZE_WRITE
      TB_ERR_RESIZE_POLL
      TB_ERR_RESIZE_READ
      TB_ERR_RESIZE_SSCANF
      TB_ERR_CAP_COLLISION
      TB_ERR_SELECT
      TB_ERR_RESIZE_SELECT



=cut

use Exporter qw( import );

our @EXPORT_OK = qw(
);

our %EXPORT_TAGS = (

  api => [qw(
    tb_init
    tb_shutdown
    tb_width
    tb_height
    tb_clear
    tb_present
    tb_invalidate
    tb_set_cursor
    tb_hide_cursor
    tb_set_cell
    tb_set_input_mode
    tb_set_output_mode
    tb_peek_event
    tb_poll_event
    tb_print
    tb_printf
    tb_utf8_char_length
    tb_utf8_char_to_unicode
    tb_utf8_unicode_to_char
    tb_last_errno
    tb_strerror
    tb_cell_buffer
    tb_version
  )],

  const => [qw(
    TB_VERSION_STR
  )],

  keys => [qw(
    TB_KEY_CTRL_TILDE
    TB_KEY_CTRL_2
    TB_KEY_CTRL_A
    TB_KEY_CTRL_B
    TB_KEY_CTRL_C
    TB_KEY_CTRL_D
    TB_KEY_CTRL_E
    TB_KEY_CTRL_F
    TB_KEY_CTRL_G
    TB_KEY_BACKSPACE
    TB_KEY_CTRL_H
    TB_KEY_TAB
    TB_KEY_CTRL_I
    TB_KEY_CTRL_J
    TB_KEY_CTRL_K
    TB_KEY_CTRL_L
    TB_KEY_ENTER
    TB_KEY_CTRL_M
    TB_KEY_CTRL_N
    TB_KEY_CTRL_O
    TB_KEY_CTRL_P
    TB_KEY_CTRL_Q
    TB_KEY_CTRL_R
    TB_KEY_CTRL_S
    TB_KEY_CTRL_T
    TB_KEY_CTRL_U
    TB_KEY_CTRL_V
    TB_KEY_CTRL_W
    TB_KEY_CTRL_X
    TB_KEY_CTRL_Y
    TB_KEY_CTRL_Z
    TB_KEY_ESC
    TB_KEY_CTRL_LSQ_BRACKET
    TB_KEY_CTRL_3
    TB_KEY_CTRL_4
    TB_KEY_CTRL_BACKSLASH
    TB_KEY_CTRL_5
    TB_KEY_CTRL_RSQ_BRACKET
    TB_KEY_CTRL_6
    TB_KEY_CTRL_7
    TB_KEY_CTRL_SLASH
    TB_KEY_CTRL_UNDERSCORE
    TB_KEY_SPACE
    TB_KEY_BACKSPACE2
    TB_KEY_CTRL_8

    TB_KEY_F1
    TB_KEY_F2
    TB_KEY_F3
    TB_KEY_F4
    TB_KEY_F5
    TB_KEY_F6
    TB_KEY_F7
    TB_KEY_F8
    TB_KEY_F9
    TB_KEY_F10
    TB_KEY_F11
    TB_KEY_F12
    TB_KEY_INSERT
    TB_KEY_DELETE
    TB_KEY_HOME
    TB_KEY_END
    TB_KEY_PGUP
    TB_KEY_PGDN
    TB_KEY_ARROW_UP
    TB_KEY_ARROW_DOWN
    TB_KEY_ARROW_LEFT
    TB_KEY_ARROW_RIGHT
    TB_KEY_BACK_TAB
    TB_KEY_MOUSE_LEFT
    TB_KEY_MOUSE_RIGHT
    TB_KEY_MOUSE_MIDDLE
    TB_KEY_MOUSE_RELEASE
    TB_KEY_MOUSE_WHEEL_UP
    TB_KEY_MOUSE_WHEEL_DOWN
  )],

  color => [qw(
    TB_DEFAULT
    TB_BLACK
    TB_RED
    TB_GREEN
    TB_YELLOW
    TB_BLUE
    TB_MAGENTA
    TB_CYAN
    TB_WHITE
  )],

  attr => [qw(
    TB_BOLD
    TB_UNDERLINE
    TB_REVERSE
    TB_ITALIC
    TB_BLINK
    TB_DIM
    TB_INVISIBLE
  )],

  event => [qw(
    TB_EVENT_KEY
    TB_EVENT_RESIZE
    TB_EVENT_MOUSE
  )],

  mode => [qw(
    TB_MOD_ALT
    TB_MOD_MOTION
  )],

  input => [qw(
    TB_INPUT_CURRENT
    TB_INPUT_ESC
    TB_INPUT_ALT
    TB_INPUT_MOUSE
  )],

  output => [qw(
    TB_OUTPUT_CURRENT
    TB_OUTPUT_NORMAL
    TB_OUTPUT_256
    TB_OUTPUT_216
    TB_OUTPUT_GRAYSCALE
    TB_OUTPUT_TRUECOLOR
  )],

  types => [qw(
    tb_cells
    tb_event
  )],

  return => [qw(
    TB_OK
    TB_ERR
    TB_ERR_NEED_MORE
    TB_ERR_INIT_ALREADY
    TB_ERR_INIT_OPEN
    TB_ERR_MEM
    TB_ERR_NO_EVENT
    TB_ERR_NO_TERM
    TB_ERR_NOT_INIT
    TB_ERR_OUT_OF_BOUNDS
    TB_ERR_READ
    TB_ERR_RESIZE_IOCTL
    TB_ERR_RESIZE_PIPE
    TB_ERR_RESIZE_SIGACTION
    TB_ERR_POLL
    TB_ERR_TCGETATTR
    TB_ERR_TCSETATTR
    TB_ERR_UNSUPPORTED_TERM
    TB_ERR_RESIZE_WRITE
    TB_ERR_RESIZE_POLL
    TB_ERR_RESIZE_READ
    TB_ERR_RESIZE_SSCANF
    TB_ERR_CAP_COLLISION

    TB_ERR_SELECT
    TB_ERR_RESIZE_SELECT
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

# use constant TB_VERSION_STR => $version->normal;
sub TB_VERSION_STR () { state $qv = $version->normal }

# ASCII key constants (tb_event->{key})
use constant {
  TB_KEY_CTRL_TILDE       => KeyCtrlTilde,
  TB_KEY_CTRL_2           => KeyCtrl2,
  TB_KEY_CTRL_A           => KeyCtrlA,
  TB_KEY_CTRL_B           => KeyCtrlB,
  TB_KEY_CTRL_C           => KeyCtrlC,
  TB_KEY_CTRL_D           => KeyCtrlD,
  TB_KEY_CTRL_E           => KeyCtrlE,
  TB_KEY_CTRL_F           => KeyCtrlF,
  TB_KEY_CTRL_G           => KeyCtrlG,
  TB_KEY_BACKSPACE        => KeyBackspace,
  TB_KEY_CTRL_H           => KeyCtrlH,
  TB_KEY_TAB              => KeyTab,
  TB_KEY_CTRL_I           => KeyCtrlI,
  TB_KEY_CTRL_J           => KeyCtrlJ,
  TB_KEY_CTRL_K           => KeyCtrlK,
  TB_KEY_CTRL_L           => KeyCtrlL,
  TB_KEY_ENTER            => KeyEnter,
  TB_KEY_CTRL_M           => KeyCtrlM,
  TB_KEY_CTRL_N           => KeyCtrlN,
  TB_KEY_CTRL_O           => KeyCtrlO,
  TB_KEY_CTRL_P           => KeyCtrlP,
  TB_KEY_CTRL_Q           => KeyCtrlQ,
  TB_KEY_CTRL_R           => KeyCtrlR,
  TB_KEY_CTRL_S           => KeyCtrlS,
  TB_KEY_CTRL_T           => KeyCtrlT,
  TB_KEY_CTRL_U           => KeyCtrlU,
  TB_KEY_CTRL_V           => KeyCtrlV,
  TB_KEY_CTRL_W           => KeyCtrlW,
  TB_KEY_CTRL_X           => KeyCtrlX,
  TB_KEY_CTRL_Y           => KeyCtrlY,
  TB_KEY_CTRL_Z           => KeyCtrlZ,
  TB_KEY_ESC              => KeyEsc,
  TB_KEY_CTRL_LSQ_BRACKET => KeyCtrlLsqBracket,
  TB_KEY_CTRL_3           => KeyCtrl3,
  TB_KEY_CTRL_4           => KeyCtrl4,
  TB_KEY_CTRL_BACKSLASH   => KeyCtrlBackslash,
  TB_KEY_CTRL_5           => KeyCtrl5,
  TB_KEY_CTRL_RSQ_BRACKET => KeyCtrlRsqBracket,
  TB_KEY_CTRL_6           => KeyCtrl6,
  TB_KEY_CTRL_7           => KeyCtrl7,
  TB_KEY_CTRL_SLASH       => KeyCtrlSlash,
  TB_KEY_CTRL_UNDERSCORE  => KeyCtrlUnderscore,
  TB_KEY_SPACE            => KeySpace,
  TB_KEY_BACKSPACE2       => KeyBackspace2,
  TB_KEY_CTRL_8           => KeyCtrl8,
};

# Terminal-dependent key constants (tb_event->{key}) and terminfo capabilities
use constant {
  TB_KEY_F1               => KeyF1,
  TB_KEY_F2               => KeyF2,
  TB_KEY_F3               => KeyF3,
  TB_KEY_F4               => KeyF4,
  TB_KEY_F5               => KeyF5,
  TB_KEY_F6               => KeyF6,
  TB_KEY_F7               => KeyF7,
  TB_KEY_F8               => KeyF8,
  TB_KEY_F9               => KeyF9,
  TB_KEY_F10              => KeyF10,
  TB_KEY_F11              => KeyF11,
  TB_KEY_F12              => KeyF12,
  TB_KEY_INSERT           => KeyInsert,
  TB_KEY_DELETE           => KeyDelete,
  TB_KEY_HOME             => KeyHome,
  TB_KEY_END              => KeyEnd,
  TB_KEY_PGUP             => KeyPgup,
  TB_KEY_PGDN             => KeyPgdn,
  TB_KEY_ARROW_UP         => KeyArrowUp,
  TB_KEY_ARROW_DOWN       => KeyArrowDown,
  TB_KEY_ARROW_LEFT       => KeyArrowLeft,
  TB_KEY_ARROW_RIGHT      => KeyArrowRight,
  TB_KEY_BACK_TAB         => key_min,
  TB_KEY_MOUSE_LEFT       => MouseLeft,
  TB_KEY_MOUSE_RIGHT      => MouseRight,
  TB_KEY_MOUSE_MIDDLE     => MouseMiddle,
  TB_KEY_MOUSE_RELEASE    => MouseRelease,
  TB_KEY_MOUSE_WHEEL_UP   => MouseWheelUp,
  TB_KEY_MOUSE_WHEEL_DOWN => MouseWheelDown,
};

# Colors (numeric) and attributes (bitwise) (Cell->{Fg}, Cell->{Bg})
use constant {
  TB_DEFAULT              => ColorDefault,
  TB_BLACK                => ColorBlack,
  TB_RED                  => ColorRed,
  TB_GREEN                => ColorGreen,
  TB_YELLOW               => ColorYellow,
  TB_BLUE                 => ColorBlue,
  TB_MAGENTA              => ColorMagenta,
  TB_CYAN                 => ColorCyan,
  TB_WHITE                => ColorWhite,
};

use constant {
  TB_BOLD       => AttrBold,
  TB_UNDERLINE  => AttrUnderline,
  TB_REVERSE    => AttrReverse,
  TB_ITALIC     => AttrCursive,
  TB_BLINK      => AttrBlink,
  # TB_BRIGHT     => ,
  TB_DIM        => AttrDim,
};

use constant {
  # TB_STRIKEOUT   => ,
  # TB_UNDERLINE_2 => ,
  # TB_OVERLINE    => ,
  TB_INVISIBLE   => AttrHidden,
};

# Event types (tb_event->{type})
use constant {
  TB_EVENT_KEY    => 1, # != EventKey
  TB_EVENT_RESIZE => 2, # != EventResize
  TB_EVENT_MOUSE  => 3, # != EventMouse
};

# Key modifiers (bitwise) (tb_event->{mod})
use constant {
  TB_MOD_ALT    => 1, # == ModAlt
  # TB_MOD_CTRL   => ,
  # TB_MOD_SHIFT  => ,
  TB_MOD_MOTION => 8, # != ModMotion
};

# Input modes (bitwise) (tb_set_input_mode)
use constant {
  TB_INPUT_CURRENT    => InputCurrent,
  TB_INPUT_ESC        => InputEsc,
  TB_INPUT_ALT        => InputAlt,
  TB_INPUT_MOUSE      => InputMouse,
};

# Output modes (tb_set_output_mode)
use constant {
  TB_OUTPUT_CURRENT   => OutputCurrent,
  TB_OUTPUT_NORMAL    => OutputNormal,
  TB_OUTPUT_256       => Output256,
  TB_OUTPUT_216       => Output216,
  TB_OUTPUT_GRAYSCALE => OutputGrayscale,
  TB_OUTPUT_TRUECOLOR => OutputRGB,
};

# Common function return values unless otherwise noted.
use constant {
  TB_OK                   => 0,   # Success
  TB_ERR                  => -1,
  TB_ERR_NEED_MORE        => -2,  # Not enough input
  TB_ERR_INIT_ALREADY     => -3,  # Termbox initialized already
  TB_ERR_INIT_OPEN        => -4,
  TB_ERR_MEM              => -5,  # Out of memory
  TB_ERR_NO_EVENT         => -6,  # No event
  TB_ERR_NO_TERM          => -7,  # No TERM in environment
  TB_ERR_NOT_INIT         => -8,  # Termbox not initialized
  TB_ERR_OUT_OF_BOUNDS    => -9,  # Out of bounds
  TB_ERR_READ             => -10,
  TB_ERR_RESIZE_IOCTL     => -11,
  TB_ERR_RESIZE_PIPE      => -12,
  TB_ERR_RESIZE_SIGACTION => -13,
  TB_ERR_POLL             => -14,
  TB_ERR_TCGETATTR        => -15,
  TB_ERR_TCSETATTR        => -16,
  TB_ERR_UNSUPPORTED_TERM => -17, # Unsupported terminal
  TB_ERR_RESIZE_WRITE     => -18,
  TB_ERR_RESIZE_POLL      => -19,
  TB_ERR_RESIZE_READ      => -20,
  TB_ERR_RESIZE_SSCANF    => -21, # Terminal width/height not received by sscanf() after resize
  TB_ERR_CAP_COLLISION    => -22, # Termcaps collision
};

use constant {
  TB_ERR_SELECT           => TB_ERR_POLL,
  TB_ERR_RESIZE_SELECT    => TB_ERR_RESIZE_POLL,
};

# ------------------------------------------------------------------------
# Variables --------------------------------------------------------------
# ------------------------------------------------------------------------

# To know the last errno
my $last_errno = 0;

# ------------------------------------------------------------------------
# Classes ----------------------------------------------------------------
# ------------------------------------------------------------------------

# The terminal screen is represented as 2d array of cells.The structure is
# optimized for dealing with single-width Unicode codepoints.
#
#  tb_cell {
#    ch => Int, # a Unicode codepoint
#    fg => Int, # bitwise foreground attributes
#    bg => Int, # bitwise background attributes
#  };
#
sub tb_cell { # \% (|\%|@)
  state $tb_cell = {
    ch => 0,
    fg => 0,
    bg => 0,
  };
  return { %$tb_cell } 
      if @_ == 0
      ;
  return $_[0] 
      if @_ == 1 
      && _HASH($_[0])
      && (all { exists $_[0]->{$_} } keys %$tb_cell)
      && (all { exists $tb_cell->{$_} } keys %{$_[0]})
      && (all { defined _NONNEGINT($_) } values %{$_[0]})
      ;
  return { 
      Ch => $_[0], 
      Fg => $_[1],
      Bg => $_[2],
    } if @_ == 3
      && (all { defined _NONNEGINT($_) } values %{@_})
      ;
  return;
}

=for comment

sub Termbox::Cell::new { # $cell ($class, \%cell)
  my $class = _CLASSISA(shift, 'Termbox::Cell') // croak ''.($! = EINVAL);
  my $args  = !@_ ? {} : _HASH(shift)           // croak ''.($! = EINVAL);
              !@_                               or croak ''.($! = E2BIG);

  my $self = {
    ch => 0,
    fg => 0,
    bg => 0,
  };
  if ($args) {
    # croak ''.($! = EINVAL) if !all { exists $args->{$_} } keys %$self;
    croak ''.($! = EINVAL) if !all { exists $self->{$_} } keys %$args;
    croak ''.($! = EINVAL) if !all { defined _NONNEGINT($_) } values %$args;
    map { $self->{$_} = $args->{$_} } keys %$args;
  }
  return bless $self, $class;
}

BEGIN {
  no strict 'refs';
  foreach my $name (qw{ch fg bg}) {
    *{"Termbox::Cell::$name"} = sub {
      my $self = _INSTANCE(shift, 'Termbox::Cell')  // croak ''.($! = EINVAL);
      my $attr = !@_ ? undef : _NONNEGINT(shift)    // croak ''.($! = EINVAL);
                 !@_                                or croak ''.($! = E2BIG);
      $self->{$name} = $attr if defined $attr;
      return $self->{$name};
    }
  }
}

=cut

# Create a class derived from L<Tie::Array> for back cells.
package back::cells { use parent qw( Tie::Array ) }

# Constructor for the derived class L<Tie::Array>. It will return a blessed 
# variable that emulates the L</tb_cell> array from the back 
# buffer.
sub back::cells::TIEARRAY { # $object ($class)
  my ($class, @args) = @_;
  my $self = {
    cells => $termbox->CellBuffer(),
  };
  return bless $self, $class;
}

# This method is always executed when a single element of the back buffer 
# is to be accessed. A (newly created) L</tb_cell> object 
# selected via index is returned. Equivalent to 
# C<< termbox::CellBuffer()->[$index] >>.
sub back::cells::FETCH { # $cell ($self, $index)
  my ($self, $index) = @_;
  return unless exists $self->{cells}->[$index];
  return tb_cell{
    ch => $self->{cells}->[$index]->{Ch},
    fg => $self->{cells}->[$index]->{Fg},
    bg => $self->{cells}->[$index]->{Bg},
  };
}

# This method returns the total number of elements in the array connected to 
# the back buffer. Equivalent to C<< scalar(@{ termbox::CellBuffer() }) >>.
sub back::cells::FETCHSIZE { # $size ()
  my ($self) = @_;
  return scalar @{ $self->{cells} };
}

# An incoming event from the console/tty.
#
# Given the event type, the following fields are relevant:
#
#  when TB_EVENT_KEY: (key XOR ch, one will be zero), mod. Note there is
#                     overlap between TB_MOD_CTRL and TB_KEY_CTRL_*.
#                     TB_MOD_CTRL and TB_MOD_SHIFT are only set as
#                     modifiers to TB_KEY_ARROW_*.
#
#  when TB_EVENT_RESIZE: w, h
#
#  when TB_EVENT_MOUSE: key (TB_KEY_MOUSE_*), x, y
#
sub tb_event { # \% (|\%|@)
  state $tb_event = {
    type  => 0, # one of TB_EVENT_* constants
    mod   => 0, # bitwise TB_MOD_* constants
    key   => 0, # one of TB_KEY_* constants
    ch    => 0, # a Unicode character
    w     => 0, # resize width
    h     => 0, # resize height
    x     => 0, # mouse x
    y     => 0, # mouse y
  };
  return { %$tb_event }
      if @_ == 0
      ;
  return $_[0]
      if @_ == 1
      && _HASH($_[0])
      && (all { exists $tb_event->{$_} } keys %{$_[0]})
      && (all { defined _NONNEGINT($_) } values %{$_[0]})
      ;
  my $ev = {};
  foreach my $k (qw( type mod key ch w h x y )) {
    $ev->{$k} = _NONNEGINT(shift) // return;
  }
  return @_ ? undef : $ev;
}

=for comment

sub Termbox::Event::new { # $event ($class, \%event)
  my $class = _CLASSISA(shift, 'Termbox::Event')  // croak ''.($! = EINVAL);
  my $args  = !@_ ? {} : _HASH(shift)             // croak ''.($! = EINVAL);
              !@_                                 || croak ''.($! = E2BIG);

  my $self = {
    type  => 0,
    mod   => 0,
    key   => 0,
    ch    => 0,
    w     => 0,
    h     => 0,
    x     => 0,
    y     => 0,
  };
  if ($args) {
    # croak ''.($! = EINVAL) if !all { exists $args->{$_} } keys %$self;
    croak ''.($! = EINVAL) if !all { exists $self->{$_} } keys %$args;
    croak ''.($! = EINVAL) if !all { defined _NONNEGINT($_) } values %$args;
    map { $self->{$_} = $args->{$_} } keys %$args;
  }
  return bless $self, $class;
}

BEGIN {
  no strict 'refs';
  foreach my $name (qw{type mod key ch w h x y}) {
    *{"Termbox::Event::$name"} = sub {
      my $self = _INSTANCE(shift, 'Termbox::Event') // croak ''.($! = EINVAL);
      my $attr = !@_ ? undef : _NONNEGINT(shift)    // croak ''.($! = EINVAL);
                 !@_                                or croak ''.($! = E2BIG);
      $self->{$name} = $attr if defined $attr;
      return $self->{$name};
    }
  }
}

=cut

# ------------------------------------------------------------------------
# Functions --------------------------------------------------------------
# ------------------------------------------------------------------------

# Initializes the termbox library. This function should be called before any
# other functions. 
sub tb_init { # $result ()
  return TB_ERR_INIT_ALREADY if $IsInit;
  my $rv;
  local $@;
  try: eval {
    $rv = $termbox->Init(@_) // TB_ERR;
    if ($rv < 0) {
      $last_errno = $!+0;
      $rv = TB_ERR_INIT_OPEN;
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rv;
}

# After successful initialization, the library must be finalized using the
# tb_shutdown() function.
sub tb_shutdown { # $result ()
  return TB_ERR_NOT_INIT if not $IsInit;
  local $@;
  try: eval {
    $termbox->Close(@_);
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return TB_OK;
}

# Returns the width of the internal back buffer (which is the same as 
# terminal's window size in rows). 
#
# The internal buffer can be resized after L</tb_clear> or L</tb_present> 
# function calls. Both dimensions have an unspecified negative value when 
# called before L</tb_init> or after L</tb_shutdown>.
sub tb_width { # $rows ()
  return TB_ERR_NOT_INIT if not $IsInit;
  my $rows;
  local $@;
  try: eval {
    ($rows) = $termbox->Size(@_);
    $rows //= TB_ERR;
    if ($rows < 0) {
      $last_errno = $!+0;
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rows;

}

# Returns the height of the internal back buffer (which is the same as terminal's
# window size in columns).
#
# The internal buffer can be resized after L</tb_clear> or L</tb_present> 
# function calls. Both dimensions have an unspecified negative value when 
# called before L</tb_init> or after L</tb_shutdown>.
sub tb_height { # $columns ()
  return TB_ERR_NOT_INIT if not $IsInit;
  my $cols;
  local $@;
  try: eval {
    (undef, $cols) = $termbox->Size(@_);
    $cols //= TB_ERR;
    if ($cols < 0) {
      $last_errno = $!+0;
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $cols;
}

# Clears the internal back buffer using C<TB_DEFAULT> color.
sub tb_clear { # $result ()
  return TB_ERR_NOT_INIT if not $IsInit;
  my $rv;
  local $@;
  try: eval {
    $rv = $termbox->Clear(TB_DEFAULT, TB_DEFAULT) // TB_ERR;
    if ($rv < 0) {
      $last_errno = $!+0;
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rv;
}

# Synchronizes the internal back buffer with the terminal by writing to C<STDOUT>.
sub tb_present { # $result ()
  return TB_ERR_NOT_INIT if not $IsInit;
  my $rv;
  local $@;
  try: eval {
    $rv = $termbox->Flush(@_) // TB_ERR;
    if ($rv < 0) {
      $last_errno = $!+0;
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rv;
}

# Clears the internal front buffer effectively forcing a complete re-render of
# the back buffer to the tty. It is not necessary to call this under normal
# circumstances.
sub tb_invalidate { # $result ()
  return TB_ERR_NOT_INIT if not $IsInit;
  my $rv;
  local $@;
  try: eval {
    $front_buffer->clear();
    $rv = $termbox->Sync(@_) // TB_ERR;
    if ($rv < 0) {
      $last_errno = $!+0;
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rv;
}

# Sets the position of the cursor. Upper-left character is (0, 0).
sub tb_set_cursor { # $result ($cx, $cy)
  return TB_ERR_NOT_INIT if not $IsInit;
  my $rv;
  local $@;
  try: eval {
    $rv = $termbox->SetCursor(@_) // TB_ERR;
    if ($rv < 0) {
      $last_errno = $!+0;
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rv;
}

# The shortcut for L<tb_set_cursor(-1, -1)|/tb_set_cursor>.
sub tb_hide_cursor { # $result ()
  return TB_ERR_NOT_INIT if not $IsInit;
  my $rv;
  local $@;
  try: eval {
    $rv = $termbox->HideCursor(@_) // TB_ERR;
    if ($rv < 0) {
      $last_errno = $!+0;
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rv;
}

# Set cell contents in the internal back buffer at the specified position.
sub tb_set_cell { # $result ($x, $y, $ch, $fg, $bg)
  my ($x, $y, $ch, $fg, $bg) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 5                    ? EINVAL
        : @_ > 5                    ? E2BIG
        : !defined(_NONNEGINT($ch)) ? EINVAL
        : undef
        ;

  return TB_ERR_NOT_INIT if not $IsInit;
  my $rv;
  local $@;
  try: eval {
    $rv = $termbox->SetCell($x, $y, chr($ch), $fg, $bg) // TB_ERR;
    if ($rv < 0) {
      $last_errno = $!+0;
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rv;
}

# Sets the input mode. Termbox has two input modes:
#
#  * TB_INPUT_ESC
#  When escape (\x1b) is in the buffer and there's no match for an escape 
#  sequence, a key event for TB_KEY_ESC is returned.
#
#  * TB_INPUT_ALT
#  When escape (\x1b) is in the buffer and there's no match for an escape 
#  sequence, the next keyboard event is returned with a TB_MOD_ALT modifier.
#
# You can also apply TB_INPUT_MOUSE via bitwise OR operation to either of the
# modes (e.g., TB_INPUT_ESC | TB_INPUT_MOUSE) to receive TB_EVENT_MOUSE events.
# If none of the main two modes were set, but the mouse mode was, TB_INPUT_ESC
# mode is used. If for some reason you've decided to use
# (TB_INPUT_ESC | TB_INPUT_ALT) combination, it will behave as if only
# TB_INPUT_ESC was selected.
#
# If mode is TB_INPUT_CURRENT, the function returns the current input mode.
#
# The default input mode is TB_INPUT_ESC.
sub tb_set_input_mode { # $result ($mode)
  return TB_ERR_NOT_INIT if not $IsInit;
  my $rv;
  local $@;
  try: eval {
    $rv = $termbox->SetInputMode(@_) // TB_ERR;
    if ($rv < 0) {
      $last_errno = $!+0;
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rv;
}

# Sets the termbox output mode. Termbox has multiple output modes:
#
#  1. TB_OUTPUT_NORMAL     => [1..8]
#
#    This mode provides 8 different colors:
#      TB_BLACK, TB_RED, TB_GREEN, TB_YELLOW,
#      TB_BLUE, TB_MAGENTA, TB_CYAN, TB_WHITE
#
#    Plus TB_DEFAULT which skips sending a color code (i.e., uses the
#    terminal's default color).
#
#    Colors (including TB_DEFAULT) may be bitwise OR'd with attributes:
#      TB_BOLD, TB_UNDERLINE, TB_REVERSE, TB_ITALIC, TB_BLINK, 
#      TB_DIM
#
#    The following style attributes are also available:
#      TB_INVISIBLE
#
#    As in all modes, the value 0 is interpreted as TB_DEFAULT for
#    convenience.
#
#    Some notes: TB_REVERSE can be applied as either fg or bg attributes for
#    the same effect. The rest of the attributes apply to fg only and are 
#    ignored as bg attributes.
#
#    Example usage:
#      tb_set_cell(x, y, '@', TB_BLACK | TB_BOLD, TB_RED);
#
#  2. TB_OUTPUT_256        => [1..256]
#
#    In this mode you get 256 distinct colors (plus default):
#                0x00   (1): TB_DEFAULT
#          0x01..0x08   (8): the next 8 colors as in TB_OUTPUT_NORMAL
#          0x09..0x10   (8): bright versions of the above
#          0x11..0xe8 (216): 216 different colors
#          0xe9..0x100 (24): 24 different shades of gray
#
#    All TB_* style attributes may be bitwise OR'd as in TB_OUTPUT_NORMAL.
#
#  3. TB_OUTPUT_216        => [1..216]
#
#    This mode supports the 216-color range of TB_OUTPUT_256 only, but you
#    don't need to provide an offset:
#                0x00   (1): TB_DEFAULT
#          0x01..0xd8 (216): 216 different colors
#
#  4. TB_OUTPUT_GRAYSCALE  => [1..24]
#
#    This mode supports the 24-color range of TB_OUTPUT_256 only, but you
#    don't need to provide an offset:
#                0x00   (1): TB_DEFAULT
#          0x01..0x18  (24): 24 different shades of gray
#
# If mode is TB_OUTPUT_CURRENT, the function returns the current output mode.
#
# The default output mode is TB_OUTPUT_NORMAL.
#
# To use the terminal default color (i.e., to not send an escape code), pass
# TB_DEFAULT. For convenience, the value 0 is interpreted as TB_DEFAULT in
# all modes.
#
# Note, cell attributes persist after switching output modes. Any translation
# between, for example, TB_OUTPUT_NORMAL's TB_RED and TB_OUTPUT_TRUECOLOR's
# 0xff0000 must be performed by the caller. Also note that cells previously
# rendered in one mode may persist unchanged until the front buffer is cleared
# (such as after a resize event) at which point it will be re-interpreted and
# flushed according to the current mode. Callers may invoke tb_invalidate if
# it is desirable to immediately re-interpret and flush the entire screen
# according to the current mode.
#
# Note, not all terminals support all output modes, especially beyond
# TB_OUTPUT_NORMAL. There is also no very reliable way to determine color
# support dynamically. If portability is desired, callers are recommended to
# use TB_OUTPUT_NORMAL or make output mode end-user configurable. The same
# advice applies to style attributes.
sub tb_set_output_mode { # $result ($mode)
  return TB_ERR_NOT_INIT if not $IsInit;
  my $rv;
  local $@;
  try: eval {
    $rv = $termbox->SetOutputMode(@_) // TB_ERR;
    if ($rv < 0) {
      $last_errno = $!+0;
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rv;
}

# Wait for an event up to timeout_ms milliseconds and fill the event structure
# with it. If no event is available within the timeout period, TB_ERR_NO_EVENT
# is returned. On a resize event, the underlying C<select> call may be
# interrupted, yielding a return code of TB_ERR_POLL. In this case, you may
# check errno via C<$!>. If it's EINTR, you can safely ignore that
# and call tb_peek_event() again.
sub tb_peek_event { # $result (\%event, $timeout_ms)
  my ($tb_event, $timeout_ms) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                ? EINVAL
        : @_ > 2                ? E2BIG
        : !tb_event($tb_event)  ? EINVAL
        : !_POSINT($timeout_ms) ? EINVAL
        : undef
        ;

  return TB_ERR_NOT_INIT if not $IsInit;
  my $ev;
  local $@;
  try: eval {
    local $SIG{ALRM} = sub { "alarm\n" }; # supress '...no signal handler set.'
    my $alarm = threads->create(
      sub {
        local $SIG{ALRM} = sub { threads->exit };
        Time::HiRes::sleep($timeout_ms / 1000);
        $termbox->Interrupt();
        return;
      }
    );
    $alarm->detach();
    $ev = $termbox->PollEvent();
    $alarm->kill('ALRM');
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  map { $tb_event->{$_} = 0 } keys %{tb_event()};
  switch: for ($ev->{Type} // -1) {
    case: EventKey == $_ and do {
      # DEBUG_FMT("EventKey:%s", "@{[%$ev]}");
      $tb_event->{type} = TB_EVENT_KEY;
      $tb_event->{mod} |= TB_MOD_ALT    if $ev->{Mod} & ModAlt;
      $tb_event->{mod} |= TB_MOD_MOTION if $ev->{Mod} & ModMotion;
      $tb_event->{key}  = $ev->{Key};
      $tb_event->{ch}   = $ev->{Ch};
      return TB_OK;
    };
    case: EventResize == $_ and do {
      # DEBUG_FMT("EventResize:%s", "@{[%$ev]}");
      $tb_event->{type} = TB_EVENT_RESIZE;
      $tb_event->{w}    = $ev->{Width};
      $tb_event->{h}    = $ev->{Height};
      return TB_OK;
    };
    case: EventMouse == $_ and do {
      # DEBUG_FMT("EventMouse:%s", "@{[%$ev]}");
      $tb_event->{type} = TB_EVENT_MOUSE;
      $tb_event->{mod} |= TB_MOD_ALT    if $ev->{Mod} & ModAlt;
      $tb_event->{mod} |= TB_MOD_MOTION if $ev->{Mod} & ModMotion;
      $tb_event->{key}  = $ev->{Key};
      $tb_event->{x}    = $ev->{MouseX};
      $tb_event->{y}    = $ev->{MouseY};
      return TB_OK;
    };
    case: EventInterrupt == $_ and do {
      # DEBUG("EventInterrupt");
      $last_errno = $! = EINTR;
      return TB_ERR_NO_EVENT;
    };
    default: {
      $last_errno = $! = EAGAIN;
      return TB_ERR_POLL;
    }
  }
}

# Same as tb_peek_event except no timeout.
sub tb_poll_event { # $result (\%event)
  my ($tb_event) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                ? EINVAL
        : @_ > 1                ? E2BIG
        : !tb_event($tb_event)  ? EINVAL
        : undef
        ;

  return TB_ERR_NOT_INIT if not $IsInit;
  my $ev;
  local $@;
  try: eval {
    $ev = $termbox->PollEvent();
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  map { $tb_event->{$_} = 0 } keys %{tb_event()};
  switch: for ($ev->{Type} // -1) {
    case: EventKey == $_ and do {
      # DEBUG_FMT("EventKey:%s", "@{[%$ev]}");
      $tb_event->{type} = TB_EVENT_KEY;
      $tb_event->{mod} |= TB_MOD_ALT    if $ev->{Mod} & ModAlt;
      $tb_event->{mod} |= TB_MOD_MOTION if $ev->{Mod} & ModMotion;
      $tb_event->{key}  = $ev->{Key};
      $tb_event->{ch}   = $ev->{Ch};
      return TB_OK;
    };
    case: EventResize == $_ and do {
      # DEBUG_FMT("EventResize:%s", "@{[%$ev]}");
      $tb_event->{type} = TB_EVENT_RESIZE;
      $tb_event->{w}    = $ev->{Width};
      $tb_event->{h}    = $ev->{Height};
      return TB_OK;
    };
    case: EventMouse == $_ and do {
      # DEBUG_FMT("EventMouse:%s", "@{[%$ev]}");
      $tb_event->{type} = TB_EVENT_MOUSE;
      $tb_event->{mod} |= TB_MOD_ALT    if $ev->{Mod} & ModAlt;
      $tb_event->{mod} |= TB_MOD_MOTION if $ev->{Mod} & ModMotion;
      $tb_event->{key}  = $ev->{Key};
      $tb_event->{x}    = $ev->{MouseX};
      $tb_event->{y}    = $ev->{MouseY};
      return TB_OK;
    };
    case: EventInterrupt == $_ and do {
      # DEBUG("EventInterrupt");
      $last_errno = $! = EINTR;
      return TB_ERR_NO_EVENT;
    };
    default: {
      $last_errno = $! = EAGAIN;
      return TB_ERR_POLL;
    }
  }
}

# Print function. For finer control, use L</tb_set_cell>.
sub tb_print { # $result ($x, $y, $fg, $bg, $str)
  my ($x, $y, $fg, $bg, $str) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 5                  ? EINVAL
        : @_ > 5                  ? E2BIG
        : !defined(_STRING($str)) ? EINVAL
        : undef
        ;

  return TB_ERR_NOT_INIT if not $IsInit;
  my $rv;
  local $@;
  try: eval {
    for my $c (split //, $str) {
      $rv = $termbox->SetCell($x++, $y, $c, $fg, $bg) // TB_ERR;
      if ($rv < 0) {
        $last_errno = $!+0;
        last;
      }
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rv;
}

# Printf function. For finer control, use L</tb_set_cell>.
sub tb_printf { # $result ($x, $y, $fg, $bg, $fmt, @)
  my ($x, $y, $fg, $bg, $fmt, @vl) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 5                    ? EINVAL
        : !defined(_STRING($fmt))   ? EINVAL
        : !(all { defined $_ } @vl) ? EINVAL
        : undef
        ;

  return TB_ERR_NOT_INIT if not $IsInit;
  my $rv;
  local $@;
  try: eval {
    my $str = sprintf($fmt, @vl);
    for my $c (split //, $str) {
      $rv = $termbox->SetCell($x++, $y, $c, $fg, $bg) // TB_ERR;
      if ($rv < 0) {
        $last_errno = $!+0;
        last;
      }
    }
    1;
  } // ($@ ||= 'Died');
  catch: if ($@ and $!+0 == EINVAL || $!+0 == E2BIG) {
    $last_errno = $!+0;
    croak usage("$!", __FILE__, __FUNCTION__);
  }
  catch: if ($@) {
    die;
  }
  return $rv;
}

# Returns the byte length of the code point from the UTF-8 character (1-6)
sub tb_utf8_char_length { # $length ($c)
  my ($c) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                ? EINVAL
        : @_ > 1                ? E2BIG
        : !defined(_STRING($c)) ? EINVAL
        : undef
        ;

  return bytes::length($c);
}

# Convert UTF-8 one unicode character string to UTF-32 codepoint.
#
# If $c is an empty string, return 0. $out is left unchanged.
#
# If an error occurs during the encoding, a negative number is returned. $out 
# is left unchanged.
#
# Otherwise, return byte length of codepoint (1-6).
sub tb_utf8_char_to_unicode { # $length (\$out, $c)
  my ($out, $c) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                    ? EINVAL
        : @_ > 2                    ? E2BIG
        : !defined(_SCALAR0($out))  ? EINVAL
        : readonly($$out)           ? EINVAL
        : !defined(_STRING($c))     ? EINVAL
        : undef
        ;

  utf8::upgrade($c);
  return 0 if length($c) == 0;
  my $length = bytes::length($c);
  # Note: UTF-8 originally supported 5-byte and 6-byte encodings, but was later 
  # restricted to 4-bytes max to be 100% compatible with UTF-16. If Unicode ever 
  # goes larger than UTF-16 can handle, a new UTF will have to be created (if 
  # not just use UTF-32) so maybe the 4-byte limit of UTF-8 might be lifted at 
  # that time.
  return TB_ERR if $length > 6;
  $$out = ord($c);
  return $length;
}

# Convert UTF-32 codepoint to UTF-8 string.
#
# $out must be scalar reference. Return byte length of codepoint (1-6).
sub tb_utf8_unicode_to_char { # $length (\$out, $c)
  my ($out, $c) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                    ? EINVAL
        : @_ > 2                    ? E2BIG
        : !defined(_SCALAR0($out))  ? EINVAL
        : readonly($$out)           ? EINVAL
        : !defined(_STRING($c))     ? EINVAL
        : undef
        ;

  $$out = Encode::encode('UTF-8', chr($c), Encode::FB_QUIET | Encode::LEAVE_SRC);
  return bytes::length($$out);
}

# Library utility function: returns the last error code
sub tb_last_errno { # $errno ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  return $last_errno;
}

# Library utility function: get error message
sub tb_strerror { # $str ($err)
  my ($err) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                  ? EINVAL
        : @_ > 1                  ? E2BIG
        : !defined(_NUMBER($err)) ? EINVAL
        : undef
        ;

  switch: for (int($err)) {
    local $==$_; # use 'any { $===$_} (1..n)' instead of '$_ ~~ [1,2,..]'
    case: TB_OK == $_ and do {
      return "Success"
    };
    case: TB_ERR_NEED_MORE == $_ and do {
      return "Not enough input"
    };
    case: TB_ERR_INIT_ALREADY == $_ and do {
      return "Termbox initialized already"
    };
    case: TB_ERR_MEM == $_ and do {
      return "Out of memory"
    };
    case: TB_ERR_NO_EVENT == $_ and do {
      return "No event"
    };
    case: TB_ERR_NO_TERM == $_ and do {
      return "No TERM in environment"
    };
    case: TB_ERR_NOT_INIT == $_ and do {
      return "Termbox not initialized"
    };
    case: TB_ERR_OUT_OF_BOUNDS == $_ and do {
      return "Out of bounds"
    };
    case: TB_ERR_UNSUPPORTED_TERM == $_ and do {
      return "Unsupported terminal"
    };
    case: TB_ERR_CAP_COLLISION == $_ and do {
      return "Termcaps collision"
    };
    case: TB_ERR_RESIZE_SSCANF == $_ and do {
      return "Terminal width/height not received by sscanf() after resize"
    };
    case: any { $===$_} (
      TB_ERR,
      TB_ERR_INIT_OPEN,
      TB_ERR_READ,
      TB_ERR_RESIZE_IOCTL,
      TB_ERR_RESIZE_PIPE,
      TB_ERR_RESIZE_SIGACTION,
      TB_ERR_POLL,
      TB_ERR_TCGETATTR,
      TB_ERR_TCSETATTR,
      TB_ERR_RESIZE_WRITE,
      TB_ERR_RESIZE_POLL,
      TB_ERR_RESIZE_READ,
    ) and do {
      $! = $last_errno;
      return "$!";
    };
    default: {
      $! = $last_errno;
      return "$!";
    }
  }
}

# Library utility function: returns a slice into the termbox's back buffer
sub tb_cell_buffer { # \@ ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;
  tie my @cells, 'back::cells';
  return \@cells;
}

# Library utility function: returns the stringified termbox's $version V-String
sub tb_version { # $str ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  return $version->stringify;
}

1;

__END__

=head1 NAME

Termbox::Go::Legacy - Legacy Termbox Interface implementation

=head1 DESCRIPTION

Legacy Interface of Termbox based on termbox2 v2.5.0-dev, 9. Feb 2024.

=head1 COPYRIGHT AND LICENCE

 This file is part of the port of Termbox.
 
 Copyright (C) 2012 by termbox-go authors
               2010-2020 nsf <no.smile.face@gmail.com>
               2015-2024,2025 Adam Saponara <as@php.net>
 
 The content of the library was taken from termbox-go and the interface was 
 taken from the termbox2 implementation of Termbox, which is licensed under 
 the MIT license.
 
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

=head1 SEE ALSO

L<Termbox>

L<termbox2.h|https://raw.githubusercontent.com/termbox/termbox2/master/termbox2.h>

=cut


#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 SUBROUTINES

=head2 TB_VERSION_STR

 TB_VERSION_STR();

use constant TB_VERSION_STR => $version->normal;


=head2 Termbox::Cell::new

 my $cell = Termbox::Cell::new($class, \%cell);

=head2 Termbox::Event::new

 my $event = Termbox::Event::new($class, \%event);

=head2 back::cells::FETCH

 my $cell = back::cells::FETCH($self, $index);

This method is always executed when a single element of the back buffer
is to be accessed. A (newly created) L</tb_cell> object
selected via index is returned. Equivalent to
C<< termbox::CellBuffer()->[$index] >>.


=head2 back::cells::FETCHSIZE

 my $size = back::cells::FETCHSIZE();

This method returns the total number of elements in the array connected to
the back buffer. Equivalent to C<< scalar(@{ termbox::CellBuffer() }) >>.


=head2 back::cells::TIEARRAY

 my $object = back::cells::TIEARRAY($class);

Constructor for the derived class L<Tie::Array>. It will return a blessed
variable that emulates the L</tb_cell> array from the back
buffer.


=head2 tb_cell

 my \%hashref = tb_cell( | \%hashref | @array);

The terminal screen is represented as 2d array of cells.The structure is
optimized for dealing with single-width Unicode codepoints.

 tb_cell {
   ch => Int, # a Unicode codepoint
   fg => Int, # bitwise foreground attributes
   bg => Int, # bitwise background attributes
 };



=head2 tb_cell_buffer

 my \@arrayref = tb_cell_buffer();

Library utility function: returns a slice into the termbox's back buffer


=head2 tb_clear

 my  $result = tb_clear();

Clears the internal back buffer using C<TB_DEFAULT> color.


=head2 tb_event

 my \%hashref = tb_event( | \%hashref | @array);

An incoming event from the console/tty.

Given the event type, the following fields are relevant:

 when TB_EVENT_KEY: (key XOR ch, one will be zero), mod. Note there is
                    overlap between TB_MOD_CTRL and TB_KEY_CTRL_*.
                    TB_MOD_CTRL and TB_MOD_SHIFT are only set as
                    modifiers to TB_KEY_ARROW_*.

 when TB_EVENT_RESIZE: w, h

 when TB_EVENT_MOUSE: key (TB_KEY_MOUSE_*), x, y



=head2 tb_height

 my $columns = tb_height();

Returns the height of the internal back buffer (which is the same as terminal's
window size in columns).

The internal buffer can be resized after L</tb_clear> or L</tb_present>
function calls. Both dimensions have an unspecified negative value when
called before L</tb_init> or after L</tb_shutdown>.


=head2 tb_hide_cursor

 my  $result = tb_hide_cursor();

The shortcut for L<tb_set_cursor(-1, -1)|/tb_set_cursor>.


=head2 tb_init

 my  $result = tb_init();

Initializes the termbox library. This function should be called before any
other functions.


=head2 tb_invalidate

 my  $result = tb_invalidate();

Clears the internal front buffer effectively forcing a complete re-render of
the back buffer to the tty. It is not necessary to call this under normal
circumstances.


=head2 tb_last_errno

 my $errno = tb_last_errno();

Library utility function: returns the last error code


=head2 tb_peek_event

 my  $result = tb_peek_event($event, $timeout_ms);

Wait for an event up to timeout_ms milliseconds and fill the event structure
with it. If no event is available within the timeout period, TB_ERR_NO_EVENT
is returned. On a resize event, the underlying C<select> call may be
interrupted, yielding a return code of TB_ERR_POLL. In this case, you may
check errno via C<$!>. If it's EINTR, you can safely ignore that
and call tb_peek_event() again.


=head2 tb_poll_event

 my  $result = tb_poll_event($event);

=head2 tb_present

 my  $result = tb_present();

Synchronizes the internal back buffer with the terminal by writing to C<STDOUT>.


=head2 tb_print

 my  $result = tb_print($x, $y, $fg, $bg, $str);

Print function. For finer control, use L</tb_set_cell>.


=head2 tb_printf

 my  $result = tb_printf($x, $y, $fg, $bg, $fmt, @array);

Printf function. For finer control, use L</tb_set_cell>.


=head2 tb_set_cell

 my  $result = tb_set_cell($x, $y, $ch, $fg, $bg);

Set cell contents in the internal back buffer at the specified position.


=head2 tb_set_cursor

 my  $result = tb_set_cursor($cx, $cy);

Sets the position of the cursor. Upper-left character is (0, 0).


=head2 tb_set_input_mode

 my  $result = tb_set_input_mode($mode);

Sets the input mode. Termbox has two input modes:

 * TB_INPUT_ESC
 When escape (\x1b) is in the buffer and there's no match for an escape
 sequence, a key event for TB_KEY_ESC is returned.

 * TB_INPUT_ALT
 When escape (\x1b) is in the buffer and there's no match for an escape
 sequence, the next keyboard event is returned with a TB_MOD_ALT modifier.

You can also apply TB_INPUT_MOUSE via bitwise OR operation to either of the
modes (e.g., TB_INPUT_ESC | TB_INPUT_MOUSE) to receive TB_EVENT_MOUSE events.
If none of the main two modes were set, but the mouse mode was, TB_INPUT_ESC
mode is used. If for some reason you've decided to use
(TB_INPUT_ESC | TB_INPUT_ALT) combination, it will behave as if only
TB_INPUT_ESC was selected.

If mode is TB_INPUT_CURRENT, the function returns the current input mode.

The default input mode is TB_INPUT_ESC.


=head2 tb_set_output_mode

 my  $result = tb_set_output_mode($mode);

Sets the termbox output mode. Termbox has multiple output modes:

 1. TB_OUTPUT_NORMAL     => [1..8]

   This mode provides 8 different colors:
     TB_BLACK, TB_RED, TB_GREEN, TB_YELLOW,
     TB_BLUE, TB_MAGENTA, TB_CYAN, TB_WHITE

   Plus TB_DEFAULT which skips sending a color code (i.e., uses the
   terminal's default color).

   Colors (including TB_DEFAULT) may be bitwise OR'd with attributes:
     TB_BOLD, TB_UNDERLINE, TB_REVERSE, TB_ITALIC, TB_BLINK,
     TB_DIM

   The following style attributes are also available:
     TB_INVISIBLE

   As in all modes, the value 0 is interpreted as TB_DEFAULT for
   convenience.

   Some notes: TB_REVERSE can be applied as either fg or bg attributes for
   the same effect. The rest of the attributes apply to fg only and are
   ignored as bg attributes.

   Example usage:
     tb_set_cell(x, y, '@', TB_BLACK | TB_BOLD, TB_RED);

 2. TB_OUTPUT_256        => [1..256]

   In this mode you get 256 distinct colors (plus default):
               0x00   (1): TB_DEFAULT
         0x01..0x08   (8): the next 8 colors as in TB_OUTPUT_NORMAL
         0x09..0x10   (8): bright versions of the above
         0x11..0xe8 (216): 216 different colors
         0xe9..0x100 (24): 24 different shades of gray

   All TB_* style attributes may be bitwise OR'd as in TB_OUTPUT_NORMAL.

 3. TB_OUTPUT_216        => [1..216]

   This mode supports the 216-color range of TB_OUTPUT_256 only, but you
   don't need to provide an offset:
               0x00   (1): TB_DEFAULT
         0x01..0xd8 (216): 216 different colors

 4. TB_OUTPUT_GRAYSCALE  => [1..24]

   This mode supports the 24-color range of TB_OUTPUT_256 only, but you
   don't need to provide an offset:
               0x00   (1): TB_DEFAULT
         0x01..0x18  (24): 24 different shades of gray

If mode is TB_OUTPUT_CURRENT, the function returns the current output mode.

The default output mode is TB_OUTPUT_NORMAL.

To use the terminal default color (i.e., to not send an escape code), pass
TB_DEFAULT. For convenience, the value 0 is interpreted as TB_DEFAULT in
all modes.

Note, cell attributes persist after switching output modes. Any translation
between, for example, TB_OUTPUT_NORMAL's TB_RED and TB_OUTPUT_TRUECOLOR's
0xff0000 must be performed by the caller. Also note that cells previously
rendered in one mode may persist unchanged until the front buffer is cleared
(such as after a resize event) at which point it will be re-interpreted and
flushed according to the current mode. Callers may invoke tb_invalidate if
it is desirable to immediately re-interpret and flush the entire screen
according to the current mode.

Note, not all terminals support all output modes, especially beyond
TB_OUTPUT_NORMAL. There is also no very reliable way to determine color
support dynamically. If portability is desired, callers are recommended to
use TB_OUTPUT_NORMAL or make output mode end-user configurable. The same
advice applies to style attributes.


=head2 tb_shutdown

 my  $result = tb_shutdown();

After successful initialization, the library must be finalized using the
tb_shutdown() function.


=head2 tb_strerror

 my $str = tb_strerror($err);

Library utility function: get error message


=head2 tb_utf8_char_length

 my $length = tb_utf8_char_length($c);

Returns the byte length of the code point from the UTF-8 character (1-6)


=head2 tb_utf8_char_to_unicode

 my $length = tb_utf8_char_to_unicode(\$out, $c);

Convert UTF-8 one unicode character string to UTF-32 codepoint.

If $c is an empty string, return 0. $out is left unchanged.

If an error occurs during the encoding, a negative number is returned. $out
is left unchanged.

Otherwise, return byte length of codepoint (1-6).


=head2 tb_utf8_unicode_to_char

 my $length = tb_utf8_unicode_to_char(\$out, $c);

Convert UTF-32 codepoint to UTF-8 string.

$out must be scalar reference. Return byte length of codepoint (1-6).


=head2 tb_version

 my $str = tb_version();

Library utility function: returns the stringified termbox's $version V-String


=head2 tb_width

 my $rows = tb_width();

Returns the width of the internal back buffer (which is the same as
terminal's window size in rows).

The internal buffer can be resized after L</tb_clear> or L</tb_present>
function calls. Both dimensions have an unspecified negative value when
called before L</tb_init> or after L</tb_shutdown>.



=cut

