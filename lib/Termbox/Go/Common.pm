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

package Termbox::Go::Common;

# ------------------------------------------------------------------------
# Boilerplate ------------------------------------------------------------
# ------------------------------------------------------------------------

use 5.014;
use strict;
use warnings;

# version '...'
use version;
our $version = version->declare('v1.1.1');
our $VERSION = version->declare('v0.1.0_0');

# authority '...'
our $authority = 'github:nsf';
our $AUTHORITY = 'github:brickpool';

# ------------------------------------------------------------------------
# Imports ----------------------------------------------------------------
# ------------------------------------------------------------------------

use Carp qw( croak );
use POSIX qw( :errno_h );
use List::Util qw( all );
use Params::Util qw(
  _STRING
  _NUMBER
  _POSINT
  _NONNEGINT
  _HASH
  _INSTANCE
);
use threads;
use Thread::Queue;

# ------------------------------------------------------------------------
# Exports ----------------------------------------------------------------
# ------------------------------------------------------------------------

=head1 EXPORTS

Nothing per default, but can export the following per request:

  :all

    :bool
      TRUE
      FALSE

    :const
      cursor_hidden

    :keys
      KeyCtrlTilde
      KeyCtrl2
      KeyCtrlSpace
      KeyCtrlA
      KeyCtrlB
      KeyCtrlC
      KeyCtrlD
      KeyCtrlE
      KeyCtrlF
      KeyCtrlG
      KeyBackspace
      KeyCtrlH
      KeyTab
      KeyCtrlI
      KeyCtrlJ
      KeyCtrlK
      KeyCtrlL
      KeyEnter
      KeyCtrlM
      KeyCtrlN
      KeyCtrlO
      KeyCtrlP
      KeyCtrlQ
      KeyCtrlR
      KeyCtrlS
      KeyCtrlT
      KeyCtrlU
      KeyCtrlV
      KeyCtrlW
      KeyCtrlX
      KeyCtrlY
      KeyCtrlZ
      KeyEsc
      KeyCtrlLsqBracket
      KeyCtrl3
      KeyCtrl4
      KeyCtrlBackslash
      KeyCtrl5
      KeyCtrlRsqBracket
      KeyCtrl6
      KeyCtrl7
      KeyCtrlSlash
      KeyCtrlUnderscore
      KeySpace
      KeyBackspace2
      KeyCtrl8

      KeyF1
      KeyF2
      KeyF3
      KeyF4
      KeyF5
      KeyF6
      KeyF7
      KeyF8
      KeyF9
      KeyF10
      KeyF11
      KeyF12
      KeyInsert
      KeyDelete
      KeyHome
      KeyEnd
      KeyPgup
      KeyPgdn
      KeyArrowUp
      KeyArrowDown
      KeyArrowLeft
      KeyArrowRight
      key_min
      MouseLeft
      MouseMiddle
      MouseRight
      MouseRelease
      MouseWheelUp
      MouseWheelDown

    :mode
      ModAlt
      ModCtrl
      ModShift
      ModMotion

    :color
      ColorDefault
      ColorBlack
      ColorRed
      ColorGreen
      ColorYellow
      ColorBlue
      ColorMagenta
      ColorCyan
      ColorWhite
      ColorDarkGray
      ColorLightRed
      ColorLightGreen
      ColorLightYellow
      ColorLightBlue
      ColorLightMagenta
      ColorLightCyan
      ColorLightGray

    :attr
      AttrBold
      AttrBlink
      AttrHidden
      AttrDim
      AttrUnderline
      AttrCursive
      AttrReverse
      max_attr

    :input
      InputEsc
      InputAlt
      InputMouse
      InputCurrent

    :output
      OutputCurrent
      OutputNormal
      Output256
      Output216
      OutputGrayscale
      OutputRGB

    :event
      EventKey
      EventResize
      EventMouse
      EventError
      EventInterrupt
      EventRaw
      EventNone

    :func
      AttributeToRGB
      RGBToAttribute
      is_cursor_hidden

    :types
      Event
      Cell

    :utils
      __CALLER__
      __FUNCTION__
      usage

    :vars
      $IsInit
      $back_buffer
      $front_buffer
      $input_mode
      $output_mode
      $cursor_x
      $cursor_y
      $foreground
      $background
      $in
      $out
      $input_comm
      $interrupt_comm

=cut

use Exporter qw( import );

our @EXPORT_OK = qw(
);

our %EXPORT_TAGS = (

  bool => [qw(
    TRUE
    FALSE
  )],

  const => [qw(
    cursor_hidden
  )],

  keys => [qw(
    KeyCtrlTilde
    KeyCtrl2
    KeyCtrlSpace
    KeyCtrlA
    KeyCtrlB
    KeyCtrlC
    KeyCtrlD
    KeyCtrlE
    KeyCtrlF
    KeyCtrlG
    KeyBackspace
    KeyCtrlH
    KeyTab
    KeyCtrlI
    KeyCtrlJ
    KeyCtrlK
    KeyCtrlL
    KeyEnter
    KeyCtrlM
    KeyCtrlN
    KeyCtrlO
    KeyCtrlP
    KeyCtrlQ
    KeyCtrlR
    KeyCtrlS
    KeyCtrlT
    KeyCtrlU
    KeyCtrlV
    KeyCtrlW
    KeyCtrlX
    KeyCtrlY
    KeyCtrlZ
    KeyEsc
    KeyCtrlLsqBracket
    KeyCtrl3
    KeyCtrl4
    KeyCtrlBackslash
    KeyCtrl5
    KeyCtrlRsqBracket
    KeyCtrl6
    KeyCtrl7
    KeyCtrlSlash
    KeyCtrlUnderscore
    KeySpace
    KeyBackspace2
    KeyCtrl8

    KeyF1
    KeyF2
    KeyF3
    KeyF4
    KeyF5
    KeyF6
    KeyF7
    KeyF8
    KeyF9
    KeyF10
    KeyF11
    KeyF12
    KeyInsert
    KeyDelete
    KeyHome
    KeyEnd
    KeyPgup
    KeyPgdn
    KeyArrowUp
    KeyArrowDown
    KeyArrowLeft
    KeyArrowRight
    key_min
    MouseLeft
    MouseMiddle
    MouseRight
    MouseRelease
    MouseWheelUp
    MouseWheelDown
  )],

  mode => [qw(
    ModAlt
    ModCtrl
    ModShift
    ModMotion
  )],

  color => [qw(
    ColorDefault
    ColorBlack
    ColorRed
    ColorGreen
    ColorYellow
    ColorBlue
    ColorMagenta
    ColorCyan
    ColorWhite
    ColorDarkGray
    ColorLightRed
    ColorLightGreen
    ColorLightYellow
    ColorLightBlue
    ColorLightMagenta
    ColorLightCyan
    ColorLightGray
  )],

  attr => [qw(
    AttrBold
    AttrBlink
    AttrHidden
    AttrDim
    AttrUnderline
    AttrCursive
    AttrReverse
    max_attr
  )],
  
  input => [qw(
    InputEsc
    InputAlt
    InputMouse
    InputCurrent
  )],

  output => [qw(
    OutputCurrent
    OutputNormal
    Output256
    Output216
    OutputGrayscale
    OutputRGB
  )],

  event => [qw(
    EventKey
    EventResize
    EventMouse
    EventError
    EventInterrupt
    EventRaw
    EventNone
  )],

  func => [qw(
    AttributeToRGB
    RGBToAttribute
    is_cursor_hidden
  )],

  types => [qw(
    Event
    Cell
  )],

  utils => [qw(
    __CALLER__
    __FUNCTION__
    usage
  )],

  vars => [qw(
    $IsInit
    $back_buffer
    $front_buffer
    $input_mode
    $output_mode
    $cursor_x
    $cursor_y
    $foreground
    $background
    $in
    $out
    $input_comm
    $interrupt_comm
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
# Utils ------------------------------------------------------------------
# ------------------------------------------------------------------------

# Returns the context of the current pure perl subroutine call.
sub __CALLER__ { # \% ($level|undef)
  my $level = shift // 0;
  my %hash; 
  @hash{qw(
    package filename line subroutine hasargs 
    wantarray evaltext is_require hints bitmask hinthash
  )} = caller($level+1);
  return \%hash;
}

# Returns the subroutine name.
sub __FUNCTION__ { # $subname ()
  my $package     = __CALLER__(0)->{package}    // 'main';
  my $subroutine  = __CALLER__(1)->{subroutine} // 'main::__ANON__';
  return (split $package . '::', $subroutine)[-1];
}

# Print usage messages from embedded (auto)pod in file.
sub usage { # $string ($message, $filename, $subroutine)
  my ($msg, $file, $sub) = @_;
  local ($!, $@);

  my $autopod = eval {
    require Pod::Autopod;
    my $ap = Pod::Autopod->new();
    $ap->readFile($file);
    $ap->getPod();
  };

  my $usage = eval {
    require Pod::Usage;
    my $in;
    if ($autopod) {
      open($in, "<", \$autopod) or die $!;
    } else {
      open($in, "<", $file) or die $!;
    }
    my $text = '';
    open(my $out, ">", \$text) or die $!;
    Pod::Usage::pod2usage(
      -message  => $msg,
      -exitval  => 'NOEXIT',
      -verbose  => 99,
      -sections => "METHODS|FUNCTIONS/$sub",
      -output   => $out,
      -input    => $in,
    );
    close($in) or die $!;
    close($out) or die $!;
    # Adjust the output
    $text =~ s/\s*$sub:\s*/\nUsage: /s;
    $text = $1 if $text =~ /(.+?)\n\n/s;
    $text;
  } // $msg;

  return $usage;
}

# ------------------------------------------------------------------------
# Types ------------------------------------------------------------------
# ------------------------------------------------------------------------

# This type represents a termbox event. The 'Mod', 'Key' and 'Ch' fields are
# valid if 'Type' is EventKey. The 'Width' and 'Height' fields are valid if
# 'Type' is EventResize. The 'Err' field is valid if 'Type' is EventError.
sub Event { # \% (|\%|@)
  state $Event = {
    Type    => 0,     # one of Event* constants
    Mod     => 0,     # one of Mod* constants or 0
    Key     => 0,     # one of Key* constants, invalid if 'Ch' is not 0
    Ch      => "\0",  # a unicode character
    Width   => 0,     # width of the screen
    Height  => 0,     # height of the screen
    Err     => 0,     # error in case if input failed
    MouseX  => 0,     # x coord of mouse
    MouseY  => 0,     # y coord of mouse
    N       => 0,     # number of bytes written when getting a raw event
  };
  return { %$Event }
      if @_ == 0
      ;
  return $_[0]
      if @_ == 1
      && _HASH($_[0])
      && (all { exists $Event->{$_} } keys %{$_[0]})
      && (all { defined _NONNEGINT($_[0]->{$_}) } 
        grep { $_ !~ /Ch/ } keys %{$_[0]})
      && (!exists($_[0]->{Ch}) || length(_STRING($_[0]->{Ch})))
      ;
  my $ev = {};
  my $i = 0;
  foreach (qw( Type Mod Key Ch Width Height Err MouseX MouseY N )) {
    last 
        unless @_ > $i;
    return
        if /Ch/ && !length(_STRING($_[$i]));
    return
        unless defined(_NONNEGINT($_[$i]));
    $ev->{$_} = $_[$i];
    $i++;
  }
  return $ev;
}

# A cell, single conceptual entity on the screen. The screen is basically a 2d
# array of cells. 'Ch' is a unicode character, 'Fg' and 'Bg' are foreground
# and background attributes respectively.
sub Cell { # \% (|\%|@)
  state $Cell = {
    Ch => "\0",
    Fg => 0,
    Bg => 0,
  };
  return { %$Cell } 
      if @_ == 0
      ;
  return $_[0] 
      if @_ == 1 
      && _HASH($_[0])
      && (all { exists $_[0]->{$_} } keys %$Cell)
      && (all { exists $Cell->{$_} } keys %{$_[0]})
      && length(_STRING($_[0]->{Ch}))
      && defined(_NONNEGINT($_[0]->{Fg}))
      && defined(_NONNEGINT($_[0]->{Fg}))
      ;
  return { 
      Ch => $_[0], 
      Fg => $_[1],
      Bg => $_[2],
    } if @_ == 3
      && length(_STRING($_[0]))
      && defined(_NONNEGINT($_[1]))
      && defined(_NONNEGINT($_[2]))
      ;
  return;
}

# ------------------------------------------------------------------------
# Constants --------------------------------------------------------------
# ------------------------------------------------------------------------

# use constant::boolean;
use constant {
  TRUE   => !!1,
  FALSE  => !! '',
};

# Key constants, see Event->{Key} field.
use constant {
  KeyF1           => 0xffff - 0,
  KeyF2           => 0xffff - 1,
  KeyF3           => 0xffff - 2,
  KeyF4           => 0xffff - 3,
  KeyF5           => 0xffff - 4,
  KeyF6           => 0xffff - 5,
  KeyF7           => 0xffff - 6,
  KeyF8           => 0xffff - 7,
  KeyF9           => 0xffff - 8,
  KeyF10          => 0xffff - 9,
  KeyF11          => 0xffff - 10,
  KeyF12          => 0xffff - 11,
  KeyInsert       => 0xffff - 12,
  KeyDelete       => 0xffff - 13,
  KeyHome         => 0xffff - 14,
  KeyEnd          => 0xffff - 15,
  KeyPgup         => 0xffff - 16,
  KeyPgdn         => 0xffff - 17,
  KeyArrowUp      => 0xffff - 18,
  KeyArrowDown    => 0xffff - 19,
  KeyArrowLeft    => 0xffff - 20,
  KeyArrowRight   => 0xffff - 21,
  key_min         => 0xffff - 22, # see terminfo
  MouseLeft       => 0xffff - 23,
  MouseMiddle     => 0xffff - 24,
  MouseRight      => 0xffff - 25,
  MouseRelease    => 0xffff - 26,
  MouseWheelUp    => 0xffff - 27,
  MouseWheelDown  => 0xffff - 28,
};

use constant {
  KeyCtrlTilde      => 0x00,
  KeyCtrl2          => 0x00,
  KeyCtrlSpace      => 0x00,
  KeyCtrlA          => 0x01,
  KeyCtrlB          => 0x02,
  KeyCtrlC          => 0x03,
  KeyCtrlD          => 0x04,
  KeyCtrlE          => 0x05,
  KeyCtrlF          => 0x06,
  KeyCtrlG          => 0x07,
  KeyBackspace      => 0x08,
  KeyCtrlH          => 0x08,
  KeyTab            => 0x09,
  KeyCtrlI          => 0x09,
  KeyCtrlJ          => 0x0a,
  KeyCtrlK          => 0x0b,
  KeyCtrlL          => 0x0c,
  KeyEnter          => 0x0d,
  KeyCtrlM          => 0x0d,
  KeyCtrlN          => 0x0e,
  KeyCtrlO          => 0x0f,
  KeyCtrlP          => 0x10,
  KeyCtrlQ          => 0x11,
  KeyCtrlR          => 0x12,
  KeyCtrlS          => 0x13,
  KeyCtrlT          => 0x14,
  KeyCtrlU          => 0x15,
  KeyCtrlV          => 0x16,
  KeyCtrlW          => 0x17,
  KeyCtrlX          => 0x18,
  KeyCtrlY          => 0x19,
  KeyCtrlZ          => 0x1a,
  KeyEsc            => 0x1b,
  KeyCtrlLsqBracket => 0x1b,
  KeyCtrl3          => 0x1b,
  KeyCtrl4          => 0x1c,
  KeyCtrlBackslash  => 0x1c,
  KeyCtrl5          => 0x1d,
  KeyCtrlRsqBracket => 0x1d,
  KeyCtrl6          => 0x1e,
  KeyCtrl7          => 0x1f,
  KeyCtrlSlash      => 0x1f,
  KeyCtrlUnderscore => 0x1f,
  KeySpace          => 0x20,
  KeyBackspace2     => 0x7f,
  KeyCtrl8          => 0x7f,
};

# Alt modifier constant, see Event->{Mod} field and SetInputMode function.
use constant {
  ModAlt    => 1 << 0,
  ModCtrl   => 1 << 1,
  ModShift  => 1 << 2,
  ModMotion => 1 << 3,
};

# Cell colors, you can combine a color with multiple attributes using bitwise
# OR ('|').
use constant {
  ColorDefault => 0,
  ColorBlack => 1,
  ColorRed => 2,
  ColorGreen => 3,
  ColorYellow => 4,
  ColorBlue => 5,
  ColorMagenta => 6,
  ColorCyan => 7,
  ColorWhite => 8,
  ColorDarkGray => 9,
  ColorLightRed => 10,
  ColorLightGreen => 11,
  ColorLightYellow => 12,
  ColorLightBlue => 13,
  ColorLightMagenta => 14,
  ColorLightCyan => 15,
  ColorLightGray => 16,
};

# Cell attributes, it is possible to use multiple attributes by combining them
# using bitwise OR ('|'). Although, colors cannot be combined. But you can
# combine attributes and a single color.
#
# It's worth mentioning that some platforms don't support certain attributes.
# For example windows console doesn't support AttrCursive. And on some
# terminals applying AttrBold to background may result in blinking text. Use
# them with caution and test your code on various terminals.
use constant {
  AttrBold        => 1 << 9,
  AttrBlink       => 1 << 10,
  AttrHidden      => 1 << 11,
  AttrDim         => 1 << 12,
  AttrUnderline   => 1 << 13,
  AttrCursive     => 1 << 14,
  AttrReverse     => 1 << 15,
  max_attr        => 1 << 16,
};

# Event type. See Event->{Type} field.
use constant {
  EventKey        => 0,
  EventResize     => 1,
  EventMouse      => 2,
  EventError      => 3,
  EventInterrupt  => 4,
  EventRaw        => 5,
  EventNone       => 6,
};

# Input mode. See SetInputMode function.
use constant {
  InputEsc      => 1 << 0,
  InputAlt      => 1 << 1,
  InputMouse    => 1 << 2,
  InputCurrent  => 0,
};

# Output mode. See SetOutputMode function.
use constant {
  OutputCurrent   => 0,
  OutputNormal    => 1,
  Output256       => 2,
  Output216       => 3,
  OutputGrayscale => 4,
  OutputRGB       => 5,
};

# Additional commonly used constants
use constant cursor_hidden => -1;

# ------------------------------------------------------------------------
# Variables --------------------------------------------------------------
# ------------------------------------------------------------------------

# To know if termbox has been initialized or not
our $IsInit = FALSE;

# termbox inner state
our $back_buffer    = bless {}, 'cellbuf';
our $front_buffer   = bless {}, 'cellbuf';
our $input_mode     = InputEsc;
our $output_mode    = OutputNormal;
our $cursor_x       = cursor_hidden;
our $cursor_y       = cursor_hidden;
our $foreground     = ColorDefault;
our $background     = ColorDefault;
our $in             = 0;
our $out            = 0;
our $input_comm     :shared = Thread::Queue->new();
our $interrupt_comm :shared = Thread::Queue->new();

# ------------------------------------------------------------------------
# Classes ----------------------------------------------------------------
# ------------------------------------------------------------------------

# private API, common OS agnostic part

# Initializes the internally used buffer
sub cellbuf::init { # void ($self, $width, $height)
  my ($self, $width, $height) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! =  @_ < 3                        ? EINVAL
        : @_ > 3                        ? E2BIG
        : !_INSTANCE($self, 'cellbuf')  ? EINVAL
        : !_POSINT($width)              ? EINVAL
        : !_POSINT($height)             ? EINVAL
        : undef
        ;

  $self->{width} = $width;
  $self->{height} = $height;
  $self->{cells} = [ map { Cell() } 1..$width*$height ];
  return;
}

# Adjusts the already initialized internal buffer to the new screen 
# resolution.
sub cellbuf::resize { # void ($self, $width, $height)
  my ($self, $width, $height) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! =  @_ < 3                        ? EINVAL
        : @_ > 3                        ? E2BIG
        : !_INSTANCE($self, 'cellbuf')  ? EINVAL
        : !_POSINT($width)              ? EINVAL
        : !_POSINT($height)             ? EINVAL
        : undef
        ;

  q/*
  require Data::Dumper;
  local $Data::Dumper::Varname = '[X,Y]';
  STDERR->print(Data::Dumper::Dumper $self->{cells});
  */ if 0;
  if ($width < $self->{width}) {
    # width--
    for my $y (1..$self->{height}) {
      my $len = $self->{width} - $width;
      my $offset = $y * $width;
      splice(@{$self->{cells}}, $offset, $len);
    }
    $self->{width} = $width;
    q/*
    local $Data::Dumper::Varname = '[X--,Y]';
    STDERR->print(Data::Dumper::Dumper $self->{cells});
    */ if 0;
  }

  if ($height < $self->{height}) {
    # height--
    my $offset = $self->{width} * $height;
    splice(@{$self->{cells}}, $offset);
    $self->{height} = $height;
    q/*
    local $Data::Dumper::Varname = '[X,Y--]';
    STDERR->print(Data::Dumper::Dumper $self->{cells});
    */ if 0;
  }

  if ($width > $self->{width}) {
    # width++
    for my $y (1..$self->{height}) {
      my $len = $width - $self->{width};
      my $offset = $y * $width - $len;
      my @list = map {{
        Ch => ' ',
        Fg => ColorDefault(),
        Bg => ColorDefault(),
      }} 1..$len;
      splice(@{ $self->{cells} }, $offset, 0, @list);
    }
    $self->{width} = $width;
    q/*
    local $Data::Dumper::Varname = '[X++,Y]';
    STDERR->print(Data::Dumper::Dumper $self->{cells});
    */ if 0;
  }

  if ($height > $self->{height}) {
    # height++
    my $len = $width * $height - @{ $self->{cells} };
    my @list = map {{
      Ch => ' ',
      Fg => ColorDefault(),
      Bg => ColorDefault(),
    }} 1..$len;
    push(@{ $self->{cells} }, @list);
    $self->{height} = $height;
    q/*
    local $Data::Dumper::Varname = '[X,Y++]';
    STDERR->print(Data::Dumper::Dumper $self->{cells});
    */ if 0;
  }

  return;
}

# Clears the internally used buffer.
sub cellbuf::clear { # void ($self)
  my ($self) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! =  @_ < 1                        ? EINVAL
        : @_ > 1                        ? E2BIG
        : !_INSTANCE($self, 'cellbuf')  ? EINVAL
        : undef
        ;

  foreach my $c (@{ $self->{cells} }) {
    $c->{Ch} = ' ';
    $c->{Fg} = $foreground;
    $c->{Bg} = $background;
  }
  return;
}

=for comment

# Initializes a new instance of the ArgumentException class.
# @param $message    The error message that explains the reason for the exception.
# @param $paramName  The name of the parameter that caused the current exception.
sub ArgumentException::new { # $object ($class, $message=, $paramName=)
  my ($class, $msg, $param) = @_;
  my $self = {
    message   => $msg   // $class,
    paramName => $param // '',
  };
  return bless $self, $class;
}

# This method is called by C<die> with file and line number parameters if 
# C<die> is called without arguments (or with an empty string) and C<$@> 
# contains a reference to this object.
sub ArgumentException::PROPAGATE { # $string ($self, $file, $line)
  my ($self, $file, $line) = @_;
  my $sub = __CALLER__(2)->{subroutine} // '__ANON__';
  my $rv = usage($self->stringify(), $file, $sub);
  unless ($rv =~ /\n$/s) {
    $rv .= sprintf(" at %s line %d\n", 
      __CALLER__(2)->{filename} // $file,
      __CALLER__(2)->{line}     // $line
    );
  }
  return $rv;
}

# Creates and returns a string representation of the current exception.
sub ArgumentException::stringify { # $string ($self)
  my ($self) = @_;
  return sprintf($self->{message}, $self->{paramName});
}

# defines an anonymous subroutine for implementing stringification.
require overload;
ArgumentException->overload::OVERLOAD(
  q("") => sub { shift->stringify() }
);

=end comment

=cut

# ------------------------------------------------------------------------
# Functions --------------------------------------------------------------
# ------------------------------------------------------------------------

# AttributeToRGB converts an Attribute to the underlying rgb triplet.
# This is only useful if termbox is in Full RGB mode and the specified
# attribute is also an attribute with r, g, b specified
sub AttributeToRGB { # $r, $g, $b ($attr)
  my ($attr) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
      @_ < 1                      ? EINVAL
    : @_ > 1                      ? E2BIG
    : !defined(_NONNEGINT($attr)) ? EINVAL
    : (undef $!)
    ;
  
  my $color = int($attr / max_attr);
  # Have to right-shift with the highest attribute bit.
  # For this, we divide by max_attr
  my $b = $color & 0xff;
  my $g = $color >> 8 & 0xff;
  my $r = $color >> 16 & 0xff;
  return ($r, $g, $b);
}

# RGBToAttribute is used to convert an rgb triplet into a termbox attribute.
# This attribute can only be applied when termbox is in Full RGB mode,
# otherwise it'll be ignored and no color will be drawn.
# R, G, B have to be in the range of 0 and 255.
sub RGBToAttribute { # $attr ($r, $g, $b)
  my ($r, $g, $b) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
      @_ < 3                    ? EINVAL
    : @_ > 3                    ? E2BIG
    : !defined(_NONNEGINT($r))  ? EINVAL
    : !defined(_NONNEGINT($g))  ? EINVAL
    : !defined(_NONNEGINT($b))  ? EINVAL
    : (undef $!)
    ;

  my $color = int($b);
  $color += int($g) << 8;
  $color += int($r) << 16;
  # A termbox attribute requires at least a 2**42 integer value (1+25+16 bits).
  # On a 32-bit perl system with IEEE double-precision float we can represent 
  # all integers from -2**53 to 2**53 (inclusive) without loss.
  # https://stackoverflow.com/a/25083776
  $color += 1 << 25;
  $color *= max_attr;
  # Left-shift back to the place where rgb is stored.
  return $color;
}

# Returns a boolean value indicating whether the cursor is hidden.
sub is_cursor_hidden { # $bool ($x, $y)
  my ($x, $y) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
      @_ < 2                ? EINVAL
    : @_ > 2                ? E2BIG
    : !defined(_NUMBER($x)) ? EINVAL
    : !defined(_NUMBER($y)) ? EINVAL
    : (undef $!)
    ;

  return $x == cursor_hidden || $y == cursor_hidden
}

1;

__END__

=head1 NAME

Termbox::Go::Common - OS independent implementation for Termbox

=head1 DESCRIPTION

This module contains some common constants, vars, functions and classes for 
the implementation of Termbox.

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

L<api_common.go|https://raw.githubusercontent.com/nsf/termbox-go/master/api_common.go>

L<termbox_common.go|https://raw.githubusercontent.com/nsf/termbox-go/master/termbox_common.go>

=cut

#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 SUBROUTINES

=head2 AttributeToRGB

 my ($r, $g, $b) = AttributeToRGB($attr);

AttributeToRGB converts an Attribute to the underlying rgb triplet.
This is only useful if termbox is in Full RGB mode and the specified
attribute is also an attribute with r, g, b specified


=head2 Cell

 my \%hashref = Cell( | \%hashref | @array);

A cell, single conceptual entity on the screen. The screen is basically a 2d
array of cells. 'Ch' is a unicode character, 'Fg' and 'Bg' are foreground
and background attributes respectively.


=head2 Event

 my \%hashref = Event( | \%hashref | @array);

This type represents a termbox event. The 'Mod', 'Key' and 'Ch' fields are
valid if 'Type' is EventKey. The 'Width' and 'Height' fields are valid if
'Type' is EventResize. The 'Err' field is valid if 'Type' is EventError.


=head2 RGBToAttribute

 my $attr = RGBToAttribute($r, $g, $b);

RGBToAttribute is used to convert an rgb triplet into a termbox attribute.
This attribute can only be applied when termbox is in Full RGB mode,
otherwise it'll be ignored and no color will be drawn.
R, G, B have to be in the range of 0 and 255.


=head2 cellbuf::clear

 cellbuf::clear($self);

Clears the internally used buffer.


=head2 cellbuf::init

 cellbuf::init($self, $width, $height);

Initializes the internally used buffer


=head2 cellbuf::resize

 cellbuf::resize($self, $width, $height);

Adjusts the already initialized internal buffer to the new screen
resolution.


=head2 is_cursor_hidden

 my $bool = is_cursor_hidden($x, $y);

Returns a boolean value indicating whether the cursor is hidden.


=head2 usage

 my $string = usage($message, $filename, $subroutine);

Print usage messages from embedded (auto)pod in file.



=cut

