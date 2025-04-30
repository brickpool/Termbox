# ------------------------------------------------------------------------
#
#   Terminal Termbox implementation
#
#   Code based on termbox-go v1.1.1, 21. April 2021
#
#   Copyright (C) 2012 termbox-go authors
#
# ------------------------------------------------------------------------
#   Author: 2024,2025 J. Schneider
# ------------------------------------------------------------------------

package Termbox::Go::Terminal::Backend;

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

require bytes; # not use, see https://perldoc.perl.org/bytes
use Carp qw( croak );
use Devel::StrictMode;
use Encode;
use English qw( -no_match_vars );
use IO::File;
use List::Util 1.29 qw( 
  any
  all
);
use Params::Util qw(
  _STRING
  _NONNEGINT
  _SCALAR0
  _ARRAY0
  _HASH
  _HASH0
  _HANDLE
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
require utf8;

use Termbox::Go::Common qw( :all );
use Termbox::Go::Devel qw(
  __FUNCTION__
  usage
);
use Termbox::Go::Terminfo::Builtin qw( :index );

# ------------------------------------------------------------------------
# Exports ----------------------------------------------------------------
# ------------------------------------------------------------------------

=head1 EXPORTS

Nothing per default, but can export the following per request:

  :all

    :const
      coord_invalid
      attr_invalid
      event_not_extracted
      event_extracted
      esc_wait

    :func
      write_cursor
      write_sgr_fg
      write_sgr_bg
      write_sgr
      escapeRGB
      get_term_size
      send_attr
      send_char
      flush
      send_clear
      update_size_maybe
      tcsetattr
      tcgetattr
      parse_mouse_event
      parse_escape_sequence
      extract_raw_event
      extract_event
      enable_wait_for_escape_sequence

    :types
      input_event
      winsize
      syscall_Termios

    :vars
      $keys
      $funcs
      $orig_tios
      $termw
      $termh
      $outfd
      $lastfg
      $lastbg
      $lastx
      $lasty
      $inbuf
      $outbuf
      $sigwinch
      $sigio
      $quit
      $grayscale

=cut

use Exporter qw( import );

our @EXPORT_OK = qw(
);

our %EXPORT_TAGS = (

  const => [qw(
    coord_invalid
    attr_invalid
    event_not_extracted
    event_extracted
    esc_wait
  )],

  func => [qw(
    write_cursor
    write_sgr_fg
    write_sgr_bg
    write_sgr
    escapeRGB
    get_term_size
    send_attr
    send_char
    flush
    send_clear
    update_size_maybe
    tcsetattr
    tcgetattr
    parse_mouse_event
    parse_escape_sequence
    extract_raw_event
    extract_event
    enable_wait_for_escape_sequence
  )],

  types => [qw(
    input_event
    winsize
    syscall_Termios
  )],

  vars => [qw(
    $orig_tios
    $termw
    $termh
    $outfd
    $lastfg
    $lastbg
    $lastx
    $lasty
    $inbuf
    $outbuf
    $sigwinch
    $sigio
    $quit
    $grayscale
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

# Usage:
#  my $str = _STRING0($str) // die;
sub _STRING0 { # $|undef ($)
  return defined($_[0]) && !ref($_[0]) ? $_[0] : undef;
}

# Usage:
#  my \%hashref = input_event();
#  my \%hashref = input_event($bytes, $err) // die;
#  my \%hashref = input_event({
#    data => $bytes,
#    err  => $errno,
#  }) // die;
sub input_event { # \%|undef (|@|\%)
  state $input_event = {
    data => '',
    err  => 0,
  };
  return { %$input_event } 
      if @_ == 0;
  return $_[0]
      if @_ == 1
      && _HASH($_[0])
      && (all { exists $_[0]->{$_} } keys %$input_event)
      && (all { exists $input_event->{$_} } keys %{$_[0]})
      && defined(_STRING0($_[0]->{data}))
      && defined(_NONNEGINT($_[0]->{err}))
      ;
  return {
      data  => $_[0],
      err   => $_[1],
    } if @_ == 2
      && defined(_STRING0($_[0]))
      && defined(_NONNEGINT($_[1])) 
      ;
  return;
}

# Usage:
#  my \%hashref = winsize();
#  my \%hashref = winsize($rows, $cols, $xpixels, $ypixels) // die;
#  my \%hashref = winsize({
#     rows    => $rows,
#     cols    => $cols,
#     xpixels => $xpixels,
#     ypixels => $ypixels,
#  }) // die;
sub winsize { # \%|undef (|@|\%)
  state $winsize = {
    rows    => 0,
    cols    => 0,
    xpixels => 0,
    ypixels => 0,
  };
  return { %$winsize } 
      if @_ == 0;
  return $_[0]
      if @_ == 1
      && _HASH($_[0])
      && (all { exists $_[0]->{$_} } keys %$winsize)
      && (all { exists $winsize->{$_} } keys %{$_[0]})
      && (all { defined _NONNEGINT($_) } values %{$_[0]})
      ;
  return {
      rows    => $_[0],
      cols    => $_[1],
      xpixels => $_[2],
      ypixels => $_[3],
    } if @_ == 4
      && (all { defined _NONNEGINT($_) } @_)
      ;
  return;
}

# Usage:
#  my \%hashref = syscall_Termios();
#  my \%hashref = syscall_Termios(
#    $c_iflag, $c_oflag, $c_cflag, $c_lflag,
#    \@c_cc,
#    $ispeed, $ospeed,
#  ) // die;
#  my \%hashref = syscall_Termios({
#     Iflag     => $c_iflag,
#     Oflag     => $c_oflag,
#     Cflag     => $c_cflag,
#     Lflag     => $c_lflag,
#     Cc        => \@c_cc,
#     Ispeed    => $ispeed,
#     Ospeed    => $ospeed,
#  }) // die;
sub syscall_Termios { # \%|undef (|@|\%)
  state $syscall_Termios = {
    Iflag     => 0,
    Oflag     => 0,
    Cflag     => 0,
    Lflag     => 0,
    Cc        => [],
    Ispeed    => 0,
    Ospeed    => 0,
  };
  return { %$syscall_Termios } 
      if @_ == 0;
  return $_[0]
      if @_ == 1
      && _HASH($_[0])
      && (all { exists $_[0]->{$_} } keys %$syscall_Termios)
      && (all { exists $syscall_Termios->{$_} } keys %{$_[0]})
      && _ARRAY0($_[0]->{Cc})
      && ( all { defined _NONNEGINT($_[0]->{$_}) }
        grep { $_ ne 'Cc' } keys %{$_[0]}
      )
      ;
  return {
      Iflag   => $_[0],
      Oflag   => $_[1],
      Cflag   => $_[2],
      Lflag   => $_[3],
      Cc      => $_[4],
      Ispeed  => $_[5],
      Ospeed  => $_[6],
    } if @_ == 7
      && (all { defined _NONNEGINT($_) } @_[0..3, 5..6])
      && _ARRAY0($_[4])
      ;
  return;
}

# ------------------------------------------------------------------------
# Constants --------------------------------------------------------------
# ------------------------------------------------------------------------

use constant {
  coord_invalid => -2,
  attr_invalid  => 0xffff,
};

# type extract_event_res int
use constant {
  event_not_extracted => 0,
  event_extracted     => 1,
  esc_wait            => 2,
};

# ------------------------------------------------------------------------
# Variables ---------------------------------------------------------------
# ------------------------------------------------------------------------

# termbox inner state
our $orig_tios        = syscall_Termios();
our $termw            = 0;
our $termh            = 0;
our $outfd            = 0;
our $lastfg           = attr_invalid;
our $lastbg           = attr_invalid;
our $lastx            = coord_invalid;
our $lasty            = coord_invalid;
our $inbuf    :shared = '';
our $outbuf;            open($outbuf, "+>", \my $outstr);
our $sigwinch :shared = $_ = Thread::Queue->new(); $_->limit(1);
our $sigio    :shared = $_ = Thread::Queue->new(); $_->limit(1);
our $quit     :shared = Thread::Queue->new();

# grayscale indexes
our $grayscale = [
  0, 17, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244,
  245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 232,
];

# ------------------------------------------------------------------------
# Functions --------------------------------------------------------------
# ------------------------------------------------------------------------

#
sub write_cursor { # void ($x, $y)
  my ($x, $y) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                    ? EINVAL
        : @_ > 2                    ? E2BIG
        : !defined(_NONNEGINT($x))  ? EINVAL
        : !defined(_NONNEGINT($y))  ? EINVAL
        : 0;
        ;

  $outbuf->print("\033[");
  $outbuf->print($y+1);
  $outbuf->print(";");
  $outbuf->print($x+1);
  $outbuf->print("H");
  return;
}

sub write_sgr_fg { # void ($a)
  my ($a) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                    ? EINVAL
        : @_ > 1                    ? E2BIG
        : !defined(_NONNEGINT($a))  ? EINVAL
        : 0;
        ;

  switch: for ($output_mode) {
    local $==$_; # use 'any { $===$_} (1..n)' instead of '$_ ~~ [1,2,..]'
    case: any { $===$_} (Output256, Output216, OutputGrayscale) and do {
      $outbuf->print("\033[38;5;");
      $outbuf->print($a-1);
      $outbuf->print("m");
      last;
    };
    case: $_ == OutputRGB && do {
      my ($r, $g, $b) = AttributeToRGB($a);
      $outbuf->print(escapeRGB(TRUE, $r, $g, $b));
      last;
    };
    default: {
      if ($a < ColorDarkGray) {
        $outbuf->print("\033[3");
        $outbuf->print($a - ColorBlack);
        $outbuf->print("m");
      } else {
        $outbuf->print("\033[9");
        $outbuf->print($a - ColorDarkGray);
        $outbuf->print("m")
      }
    }
  }
  return;
}

sub write_sgr_bg { # void ($a)
  my ($a) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                    ? EINVAL
        : @_ > 1                    ? E2BIG
        : !defined(_NONNEGINT($a))  ? EINVAL
        : 0;
        ;

  switch: for ($output_mode) {
    local $==$_; # use 'any { $===$_} (1..n)' instead of '$_ ~~ [1,2,..]'
    case: any { $===$_} (Output256, Output216, OutputGrayscale) and do {
      $outbuf->print("\033[48;5;");
      $outbuf->print($a-1);
      $outbuf->print("m");
      last;
    };
    case: $_ == OutputRGB && do {
      my ($r, $g, $b) = AttributeToRGB($a);
      $outbuf->print(escapeRGB(TRUE, $r, $g, $b));
      last;
    };
    default: {
      if ($a < ColorDarkGray) {
        $outbuf->print("\033[4");
        $outbuf->print($a - ColorBlack);
        $outbuf->print("m");
      } else {
        $outbuf->print("\033[10");
        $outbuf->print($a - ColorDarkGray);
        $outbuf->print("m")
      }
    }
  }
  return;
}

sub write_sgr { # void ($fg, $bg)
  my ($fg, $bg) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                    ? EINVAL
        : @_ > 2                    ? E2BIG
        : !defined(_NONNEGINT($fg)) ? EINVAL
        : !defined(_NONNEGINT($bg)) ? EINVAL
        : 0;
        ;

  switch: for ($output_mode) {
    local $==$_; # use 'any { $===$_} (1..n)' instead of '$_ ~~ [1,2,..]'
    case: any { $===$_} (Output256, Output216, OutputGrayscale) and do {
      $outbuf->print("\033[38;5;");
      $outbuf->print($fg-1);
      $outbuf->print("m");
      $outbuf->print("\033[48;5;");
      $outbuf->print($bg-1);
      $outbuf->print("m");
      last;
    };
    case: $_ == OutputRGB && do {
      my ($r, $g, $b) = AttributeToRGB($fg);
      $outbuf->print(escapeRGB(TRUE, $r, $g, $b));
      ($r, $g, $b) = AttributeToRGB($bg);
      $outbuf->print(escapeRGB(FALSE, $r, $g, $b));
      last;
    };
    default: {
      if ($fg < ColorDarkGray) {
        $outbuf->print("\033[3");
        $outbuf->print($fg - ColorBlack);
        $outbuf->print(";");
      } else {
        $outbuf->print("\033[9");
        $outbuf->print($fg - ColorDarkGray);
        $outbuf->print(";");
      }
      if ($bg < ColorDarkGray) {
        $outbuf->print("4");
        $outbuf->print($bg - ColorBlack);
        $outbuf->print("m");
      } else {
        $outbuf->print("10");
        $outbuf->print($bg - ColorDarkGray);
        $outbuf->print("m");
      }
    }
  }
  return;
}

sub escapeRGB { # $string ($fg, $r, $g, $b)
  my ($fg, $r, $g, $b) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 4                    ? EINVAL
        : @_ > 4                    ? E2BIG
        : !defined(_NONNEGINT($r))  ? EINVAL
        : !defined(_NONNEGINT($g))  ? EINVAL
        : !defined(_NONNEGINT($b))  ? EINVAL
        : 0;
        ;

  my $escape = "\033[";
  if ($fg) {
    $escape .= "38";
  } else {
    $escape .= "48";
  }
  $escape .= ";2;";
  $escape .= $r .";";
  $escape .= $g .";";
  $escape .= $b ."m";
  return $escape;
}

sub get_term_size { # $cols, $rows ($fd)
  my ($fd) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                    ? EINVAL
        : @_ > 1                    ? E2BIG
        : !defined(_NONNEGINT($fd)) ? EINVAL
        : 0;
        ;

  my ($col, $row);
  local $@;
  if (eval { require Win32::Console }) {
    require Win32API::File;
    my $h = Win32API::File::FdGetOsFHandle($fd) // -1;
    if ($h != -1) {
      ($col, $row) = Win32::Console::_GetConsoleScreenBufferInfo($h);
    }
  } elsif (eval { require 'sys/ioctl.ph' }) {
    my $fh = IO::File->new_from_fd($fd, 'w');
    if (-t $fh) {
      ioctl($fh, &TIOCGWINSZ, my $sz = '');
      ($col, $row) = unpack('S2', $sz);
    }
  }
  if (!$col || !$row) {
    $! ||= ENOTTY;
    return;
  }
  return ($col, $row);
}

sub send_attr { # void ($fg, $bg)
  my ($fg, $bg) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if STRICT and
    $!  = @_ < 2                    ? EINVAL
        : @_ > 2                    ? E2BIG
        : !defined(_NONNEGINT($fg)) ? EINVAL
        : !defined(_NONNEGINT($bg)) ? EINVAL
        : 0;
        ;

  if ($fg == $lastfg && $bg == $lastbg) {
    return;
  }

  $outbuf->print($funcs->[t_sgr0]);

  my ($fgcol, $bgcol);

  switch: for ($output_mode) {
    case: $_ == Output256 and do {
      $fgcol = $fg & 0x1ff;
      $bgcol = $bg & 0x1ff;
      last;
    };
    case: $_ == Output216 and do {
      $fgcol = $fg & 0xff;
      $bgcol = $bg & 0xff;
      if ($fgcol > 216) {
        $fgcol = ColorDefault;
      }
      if ($bgcol > 216) {
        $bgcol = ColorDefault;
      }
      if ($fgcol != ColorDefault) {
        $fgcol += 0x10;
      }
      if ($bgcol != ColorDefault) {
        $bgcol += 0x10;
      }
      last;
    };
    case: $_ == OutputGrayscale and do {
      $fgcol = $fg & 0x1f;
      $bgcol = $bg & 0x1f;
      if ($fgcol > 26) {
        $fgcol = ColorDefault;
      }
      if ($bgcol > 26) {
        $bgcol = ColorDefault;
      }
      if ($fgcol != ColorDefault) {
        $fgcol = $grayscale->[$fgcol];
      }
      if ($bgcol != ColorDefault) {
        $bgcol = $grayscale->[$bgcol];
      }
      last;
    };
    case: $_ == OutputRGB and do {
      $fgcol = $fg;
      $bgcol = $bg;
      last;
    };
    default: {
      $fgcol = $fg & 0xff;
      $bgcol = $bg & 0xff;
    }
  }

  if ($fgcol != ColorDefault) {
    if ($bgcol != ColorDefault) {
      write_sgr($fgcol, $bgcol);
    } else {
      write_sgr_fg($fgcol);
    }
  } elsif ($bgcol != ColorDefault) {
    write_sgr_bg($bgcol);
  }

  if ($fg & AttrBold) {
    $outbuf->print($funcs->[t_bold]);
  }
  q/*if ($bg & AttrBold) {
    $outbuf->print($funcs->[t_blink]);
  }*/ if 0;
  if ($fg & AttrBlink) {
    $outbuf->print($funcs->[t_blink]);
  }
  if ($fg & AttrUnderline) {
    $outbuf->print($funcs->[t_underline]);
  }
  if ($fg & AttrCursive) {
    $outbuf->print($funcs->[t_cursive]);
  }
  if ($fg & AttrHidden) {
    $outbuf->print($funcs->[t_hidden]);
  }
  if ($fg & AttrDim) {
    $outbuf->print($funcs->[t_dim]);
  }
  if ($fg & AttrReverse | $bg & AttrReverse) {
    $outbuf->print($funcs->[t_reverse])
  }

  ($lastfg, $lastbg) = ($fg, $bg);
  return;
}

sub send_char { # void ($x, $y, $ch)
  my ($x, $y, $ch) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if STRICT and
    $!  = @_ < 3                    ? EINVAL
        : @_ > 3                    ? E2BIG
        : !defined(_NONNEGINT($x))  ? EINVAL
        : !defined(_NONNEGINT($y))  ? EINVAL
        : !defined(_STRING($ch))    ? EINVAL
        : 0;
        ;

  if ($x-1 != $lastx || $y != $lasty) {
    write_cursor($x, $y);
  }
  ($lastx, $lasty) = ($x, $y);
  $outbuf->print(Encode::encode('UTF-8' => $ch));
  return;
}

sub flush { # $succeded ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  $outbuf->flush();
  my $err = defined(syswrite($out, $outstr)) ? 0 : $!+0;
  $outbuf->seek(0, 0);
  $err ||= $!+0;
  $outstr = '';
  return $err ? undef : "0E0";
}

sub send_clear { # $succeded ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  send_attr($foreground, $background);
  $outbuf->print($funcs->[t_clear_screen]);
  if (!is_cursor_hidden($cursor_x, $cursor_y)) {
    write_cursor($cursor_x, $cursor_y);
  }

  # we need to invalidate cursor position too and these two vars are
  # used only for simple cursor positioning optimization, cursor
  # actually may be in the correct place, but we simply discard
  # optimization once and it gives us simple solution for the case when
  # cursor moved
  $lastx = coord_invalid;
  $lasty = coord_invalid;

  return flush();
}

sub update_size_maybe { # $succeded ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  my ($w, $h) = get_term_size($outfd);
  if ($w != $termw || $h != $termh) {
    ($termw, $termh) = ($w, $h);
    $back_buffer->resize($termw, $termh);
    $front_buffer->resize($termw, $termh);
    $front_buffer->clear();
    return send_clear();
  }
  return "0E0";
}

sub tcsetattr { # $succeded ($fd, \%termios)
  my ($fd, $termios) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                              ? EINVAL
        : @_ > 2                              ? E2BIG
        : !defined(_NONNEGINT($fd))           ? EINVAL
        : !defined(syscall_Termios($termios)) ? EINVAL
        : 0;
        ;

  my $term;
  local $@;
  try: eval {
    $term = POSIX::Termios->new();
  };
  catch: if ($@) {
    $! = $!{ENOTSUP} ? &Errno::ENOTSUP : ENOTTY;
    return;
  }
  $term->getattr($fd);

  # put current values into Termios structure
  $term->setcflag($termios->{Cflag});
  $term->setlflag($termios->{Lflag});
  $term->setiflag($termios->{Iflag});
  $term->setoflag($termios->{Oflag});
  $term->setispeed($termios->{Ispeed});
  $term->setospeed($termios->{Ospeed});
  my $field = 0;
  foreach my $value (@{ $termios->{Cc} }) {
    $term->setcc($field, $value // 0);
  } continue { $field++ }

  # setattr returns undef on failure
  my $r = $term->setattr($fd, &POSIX::TCSANOW);
  if (!defined $r) {
    return;
  }
  return "0E0";
}

sub tcgetattr { # $succeded ($fd, \%termios)
  my ($fd, $termios) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                              ? EINVAL
        : @_ > 2                              ? E2BIG
        : !defined(_NONNEGINT($fd))           ? EINVAL
        : !defined(syscall_Termios($termios)) ? EINVAL
        : 0;
        ;

  my $term;
  local $@;
  try: eval {
    $term = POSIX::Termios->new();
  };
  catch: if ($@) {
    $! = $!{ENOTSUP} ? &Errno::ENOTSUP : ENOTTY;
    return;
  }
  $term->getattr($fd);

  # get the current Termios values
  $termios->{Cflag} = $term->getcflag();
  $termios->{Lflag} = $term->getlflag();
  $termios->{Iflag} = $term->getiflag();
  $termios->{Oflag} = $term->getoflag();
  $termios->{Ispeed} = $term->getispeed();
  $termios->{Ospeed} = $term->getospeed();
  my $field = 0;
  foreach (@{ $termios->{Cc} }) {
    my $value = $term->getcc($field) // 0;
    $termios->{Cc}->[$field] = $value;
  } continue { $field++ }
  return "0E0";
}

sub parse_mouse_event { # $count, $succeded (\%event, $buf)
  my ($event, $buf) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                    ? EINVAL
        : @_ > 2                    ? E2BIG
        : !defined(_HASH0($event))  ? EINVAL
        : !defined(_STRING0($buf))  ? EINVAL
        : 0;
        ;

  $event->{Type} //= 0;
  if ($buf =~ /^\033\[M/ && length($buf) >= 6) {
    # X10 mouse encoding, the simplest one
    # \033 [ M Cb Cx Cy
    my $b = ord(substr($buf, 3, 1));
    switch: for ($b & 3) {
      case: $_ == 0 and do {
        if ($b & 64) {
          $event->{Key} = MouseWheelUp;
        } else {
          $event->{Key} = MouseLeft;
        }
        last;
      };
      case: $_ == 1 and do {
        if ($b & 64) {
          $event->{Key} = MouseWheelDown;
        } else {
          $event->{Key} = MouseMiddle;
        }
        last;
      };
      case: $_ == 2 and do {
        $event->{Key} = MouseRight;
        last;
      };
      case: $_ == 3 and do {
        $event->{Key} = MouseRelease;
        last;
      };
      default: {
        return (6, FALSE);
      }
    }
    $event->{Type} = EventMouse; # KeyEvent by default
    if ($b & 32) {
      $event->{Mod} //= 0;
      $event->{Mod} |= ModMotion;
    }

    # the coord is 1,1 for upper left
    $event->{MouseX} = ord(substr($buf, 4, 1)) - 1;
    $event->{MouseY} = ord(substr($buf, 5, 1)) - 1;
    return (6, TRUE);
  } elsif ($buf =~ /^\033\[<?/) {
    # xterm 1006 extended mode or urxvt 1015 extended mode
    # xterm: \033 [ < Cb ; Cx ; Cy (M or m)
    # urxvt: \033 [ Cb ; Cx ; Cy M

    # find the first M or m, that's where we stop
    if ($buf !~ /[Mm]/g) {
      return (0, FALSE);
    }
    my $mi = pos($buf) - 1;

    # whether it's a capital M or not
    my $isM = substr($buf, $mi, 1) eq 'M';

    # whether it's urxvt or not
    my $isU = FALSE;

    # substr($buf, 2, 1) is safe here, because having M or m found means we 
    # have at least 3 bytes in a string
    if (substr($buf, 2, 1) eq '<') {
      $buf = substr($buf, 3, $mi - 3);
    } else {
      $isU = TRUE;
      $buf = substr($buf, 2, $mi - 2);
    }

    # not found or invalid
    my ($n1, $n2, $n3) = $buf =~ /^([\s\d]+);([\s\d]+);([\s\d]+)$/;
    if (!defined($n1) || !defined($n2) || !defined($n3)) {
      return (0, FALSE);
    }

    # on urxvt, first number is encoded exactly as in X10, but we need to
    # make it zero-based, on xterm it is zero-based already
    if ($isU) {
      $n1 -= 32;
    }
    switch: for ($n1 & 3) {
      case: $_ == 0 and do {
        if ($n1 & 64) {
          $event->{Key} = MouseWheelUp;
        } else {
          $event->{Key} = MouseLeft;
        }
        last;
      };
      case: $_ == 1 and do {
        if ($n1 & 64) {
          $event->{Key} = MouseWheelDown;
        } else {
          $event->{Key} = MouseMiddle;
        }
        last;
      };
      case: $_ == 2 and do {
        $event->{Key} = MouseRight;
        last;
      };
      case: $_ == 3 and do {
        $event->{Key} = MouseRelease;
        last;
      };
      default: {
        return ($mi + 1, FALSE);
      }
    }
    if (!$isM) {
      # on xterm mouse release is signaled by lowercase m
      $event->{Key} = MouseRelease;
    }

    $event->{Type} = EventMouse; # KeyEvent by default
    if ($n1 & 32) {
      $event->{Mod} //= 0;
      $event->{Mod} |= ModMotion;
    }

    $event->{MouseX} = $n2 - 1;
    $event->{MouseY} = $n3 - 1;
    return ($mi + 1, TRUE);
  }

  return (0, FALSE);
}

sub parse_escape_sequence { # $count, $succeded (\%event, \$buf)
  my ($event, $buf) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                    ? EINVAL
        : @_ > 2                    ? E2BIG
        : !defined(_HASH0($event))  ? EINVAL
        : !defined(_SCALAR0($buf))  ? EINVAL
        : 0;
        ;

  my $bufstr = $$buf;
  my $i = 0;
  foreach my $key (@$keys) {
    if (index($bufstr, $key) == 0) {
      $event->{Type}  = EventKey;
      $event->{Ch}    = 0;
      $event->{Key}   = 0xffff - $i;
      return (length($key), TRUE);
    }
  } continue { $i++ }

  # if none of the keys match, let's try mouse sequences
  return parse_mouse_event($event, $bufstr);
}

sub extract_raw_event { # $succeded (\$data, \%event)
  my ($data, $event) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 2                    ? EINVAL
        : @_ > 2                    ? E2BIG
        : !defined(_SCALAR0($data)) ? EINVAL
        : !defined(_HASH0($event))  ? EINVAL
        : 0;
        ;

  my $n = bytes::length($inbuf);
  if (!$n) {
    return FALSE;
  }

  if (my $size = bytes::length($$data)) {
    $n = $size if $size < $n;
  }

  $$data = bytes::substr($inbuf, 0, $n);
  $inbuf = bytes::substr($inbuf, $n);

  $event->{N} = $n;
  $event->{Type} = EventRaw;
  return TRUE;
}

sub extract_event { # $extract_event_res (\$inbuf, \%event, $allow_esc_wait)
  my ($inbuf_ref, $event, $allow_esc_wait) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 3                          ? EINVAL
        : @_ > 3                          ? E2BIG
        : !defined(_SCALAR0($inbuf_ref))  ? EINVAL
        : !defined(_HASH0($event))        ? EINVAL
        : ref($allow_esc_wait)            ? EINVAL
        : 0;
        ;

  if (!length($$inbuf_ref)) {
    $event->{N} = 0;
    return event_not_extracted;
  }

  my $inbuf0 = substr($$inbuf_ref, 0, 1);
  if ($inbuf0 eq "\033") {
    # possible escape sequence
    my ($n, $ok) = parse_escape_sequence($event, $inbuf_ref);
    if ($n != 0) {
      $event->{N} = $n;
      if ($ok) {
        return event_extracted;
      } else {
        return event_not_extracted;
      }
    }

    # possible partially read escape sequence; trigger a wait if appropriate
    if (enable_wait_for_escape_sequence() && $allow_esc_wait) {
      $event->{N} = 0;
      return esc_wait;
    }

    # it's not escape sequence, then it's Alt or Esc, check $input_mode
    switch: {
      case: ($input_mode & InputEsc) and do {
        # if we're in escape mode, fill Esc event, pop buffer, return success
        $event->{Ch} = 0;
        $event->{Key} = KeyEsc;
        $event->{Mod} = 0;
        $event->{N} = 1;
        return event_extracted;
      };
      case ($input_mode & InputAlt) and do {
        # if we're in alt mode, set Alt modifier to event and redo parsing
        $event->{Mod} = ModAlt;
        $$inbuf_ref =~ s/^\033//;
        my $status = extract_event($inbuf_ref, $event, FALSE);
        $$inbuf_ref =~ s/^/\033/;
        if ($status == event_extracted) {
          $event->{N}++;
        } else {
          $event->{N} = 0;
        }
        return $status;
      };
      default: {
        croak("unreachable");
      }
    }
  }

  # if we're here, this is not an escape sequence and not an alt sequence
  # so, it's a FUNCTIONAL KEY or a UNICODE character

  # first of all check if it's a functional key
  if (ord($inbuf0) <= KeySpace || ord($inbuf0) == KeyBackspace2) {
    # fill event, pop buffer, return success
    $event->{Ch} = 0;
    $event->{Key} = ord($inbuf0);
    $event->{N} = 1;
    return event_extracted;
  }

  # the only possible option is utf8
  my ($r, $n) = do {
    # Decode the first character (UTF-8 uses a maximum of 4-byte code points
    # and 'utf8::decode' handles any - even incomplete - encoding)
    utf8::decode(my $str = bytes::substr($$inbuf_ref, 0, 4));
    my $r = substr($str, 0, 1);
    my $n = utf8::upgrade($r);
    ($r, $n);
  };
  if ($r && $n) {
    $event->{Ch} = ord($r);
    $event->{Key} = 0;
    $event->{N} = $n;
    return event_extracted;
  }

  return event_not_extracted;
}

# from escwait.go/escwait_darwin.go

# On macOS, enable behavior which will wait before deciding that the escape
# key was pressed, to account for partially send escape sequences, especially
# with regard to lengthy mouse sequences.
# See L<https://github.com/nsf/termbox-go/issues/132>
sub enable_wait_for_escape_sequence() { # $ ()
	$OSNAME eq 'darwin';
}

1;

__END__

=head1 NAME

Termbox::Go::Terminal::Backend - Terminal Backend implementation for Termbox

=head1 DESCRIPTION

This module contains some private API functions for the implementation of 
Termbox for Terminal.

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

=head1 SEE ALSO

L<termbox.go|https://raw.githubusercontent.com/nsf/termbox-go/master/termbox.go>

=cut


#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 SUBROUTINES

=head2 enable_wait_for_escape_sequence

 my $scalar = enable_wait_for_escape_sequence();

On macOS, enable behavior which will wait before deciding that the escape
key was pressed, to account for partially send escape sequences, especially
with regard to lengthy mouse sequences.
See L<https://github.com/nsf/termbox-go/issues/132>


=head2 escapeRGB

 my $string = escapeRGB($fg, $r, $g, $b);

=head2 extract_event

 my $extract_event_res = extract_event(\$inbuf, \%event, $allow_esc_wait);

=head2 extract_raw_event

 my $succeded = extract_raw_event(\$data, \%event);

=head2 flush

 my $succeded = flush();

=head2 get_term_size

 my ($cols, $rows) = get_term_size($fd);

=head2 input_event

 my \%hashref | undef = input_event( | @array | \%hashref);

Usage:
 my \%hashref = input_event();
 my \%hashref = input_event($bytes, $err) // die;
 my \%hashref = input_event({
   data => $bytes,
   err  => $errno,
 }) // die;


=head2 parse_escape_sequence

 my ($count, $succeded) = parse_escape_sequence(\%event, \$buf);

=head2 parse_mouse_event

 my ($count, $succeded) = parse_mouse_event(\%event, $buf);

=head2 send_attr

 send_attr($fg, $bg);

=head2 send_char

 send_char($x, $y, $ch);

=head2 send_clear

 my $succeded = send_clear();

=head2 syscall_Termios

 my \%hashref | undef = syscall_Termios( | @array | \%hashref);

Usage:
 my \%hashref = syscall_Termios();
 my \%hashref = syscall_Termios(
   $c_iflag, $c_oflag, $c_cflag, $c_lflag,
   \@c_cc,
   $ispeed, $ospeed,
 ) // die;
 my \%hashref = syscall_Termios({
    Iflag     => $c_iflag,
    Oflag     => $c_oflag,
    Cflag     => $c_cflag,
    Lflag     => $c_lflag,
    Cc        => \@c_cc,
    Ispeed    => $ispeed,
    Ospeed    => $ospeed,
 }) // die;


=head2 tcgetattr

 my $succeded = tcgetattr($fd, \%termios);

=head2 tcsetattr

 my $succeded = tcsetattr($fd, \%termios);

=head2 update_size_maybe

 my $succeded = update_size_maybe();

=head2 winsize

 my \%hashref | undef = winsize( | @array | \%hashref);

Usage:
 my \%hashref = winsize();
 my \%hashref = winsize($rows, $cols, $xpixels, $ypixels) // die;
 my \%hashref = winsize({
    rows    => $rows,
    cols    => $cols,
    xpixels => $xpixels,
    ypixels => $ypixels,
 }) // die;


=head2 write_cursor

 write_cursor($x, $y);

=head2 write_sgr

 write_sgr($fg, $bg);

=head2 write_sgr_bg

 write_sgr_bg($a);

=head2 write_sgr_fg

 write_sgr_fg($a);


=cut

