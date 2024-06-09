# ------------------------------------------------------------------------
#
#   terminfo Termbox implementation
#
#   Code based on termbox-go v1.1.1, 21. April 2021
#
#   Copyright (C) 2012 termbox-go authors
#
# ------------------------------------------------------------------------
#   Author => 2024 J. Schneider
# ------------------------------------------------------------------------

package Termbox::Go::Terminfo;

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
use Config;
use Params::Util qw(
  _STRING
  _NONNEGINT
  _HANDLE
);
use POSIX qw( :errno_h );

use Termbox::Go::Common qw(
  key_min
  $keys
  $funcs
);
use Termbox::Go::Devel qw(
  usage
  __FUNCTION__
);
use Termbox::Go::Terminfo::Builtin qw( :all );

# ------------------------------------------------------------------------
# Exports ----------------------------------------------------------------
# ------------------------------------------------------------------------

=head1 EXPORTS

Nothing per default, but can export the following per request:

  :all

    :func
      load_terminfo
      ti_try_path
      setup_term_builtin
      setup_term
      ti_read_string

=cut

use Exporter qw( import );

our @EXPORT_OK = qw(
);

our %EXPORT_TAGS = (

  func => [qw(
    load_terminfo
    ti_try_path
    setup_term_builtin
    setup_term
    ti_read_string
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
# Variables ---------------------------------------------------------------
# ------------------------------------------------------------------------

# "Maps" the function constants from C<Terminal::Backend> to the number of the 
# respective string capability in the terminfo file. Taken from (ncurses) 
# C<term.h>.
my $ti_funcs = [
  28,   # enter ca
  40,   # exit ca
  16,   # show cursor
  13,   # hide cursor
  5,    # clear screen
  39,   # sgr0
  36,   # underline
  27,   # bold
  32,   # hidden
  26,   # blink
  30,   # dim
  311,  # cursive
  34,   # reverse
  89,   # enter keypad ("keypad_xmit")
  88,   # exit keypad ("keypad_local")
];

# Same as above for the special keys.
my $ti_keys = [
  66, 68, # apparently not a typo; 67 is F10 for whatever reason
  69, 70,
  71, 72, 73, 74, 75, 67, 216, 217, 77, 59, 76, 164, 82, 81, 87, 61, 79, 83,
];

# ------------------------------------------------------------------------
# Functions --------------------------------------------------------------
# ------------------------------------------------------------------------

#
sub load_terminfo { # \$data|undef ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  my $data;

  my $term = $ENV{"TERM"};
  if (!$term) {
    $! = ENOENT;
    $@ = "termbox: TERM not set";
    return;
  }

  # The following behaviour follows the one described in terminfo(5) as
  # distributed by ncurses.

  my $terminfo = $ENV{"TERMINFO"};
  if ($terminfo) {
    # if TERMINFO is set, no other directory should be searched
    return ti_try_path($terminfo);
  }

  # next, consider ~/.terminfo
  my $home = $ENV{"HOME"};
  if ($home) {
    $data = ti_try_path("$home/.terminfo");
    if (not $!) {
      return $data;
    }
  }

  # next, TERMINFO_DIRS
  my $dirs = $ENV{"TERMINFO_DIRS"};
  if ($dirs) {
    for my $dir (split(/\:/, $dirs)) {
      # "" -> "/usr/share/terminfo"
      $dir ||= "/usr/share/terminfo";
      $data = ti_try_path($dir);
      if (not $!) {
        return $data;
      }
    }
  }

  # next, /lib/terminfo
  $data = ti_try_path("/lib/terminfo");
  if (not $!) {
    return $data;
  }

  # fall back to /usr/share/terminfo
  return ti_try_path("/usr/share/terminfo");
}

sub ti_try_path { # \$data|undef ($path)
  my ($path) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 1                    ? EINVAL
        : @_ > 1                    ? E2BIG
        : !defined(_STRING($path))  ? EINVAL
        : 0;
        ;

  # load_terminfo already made sure it is set
  my $term = $ENV{"TERM"} || '';

  # first try, the typical *nix path
  my $terminfo = $path . "/" . substr($term, 0, 1) . "/" . $term;
  my $data = eval { # ReadFile
    use autodie;
    local $/; # enable localized slurp mode
    open(my $fh, '<:raw', $terminfo);
    my $content = <$fh>;
    close($fh);
    \$content;
  };
  if (not $@) {
    return $data;
  }

  # fallback to darwin specific dirs structure
  $terminfo = $path . "/" . sprintf("%x", ord($term)) . "/" . $term;
  $data = eval { # ReadFile
    use autodie;
    local $/; # enable localized slurp mode
    open my $fh, '<:raw', $terminfo;
    my $content = <$fh>;
    close($fh);
    \$content;
  };
  if (not $@) {
    return $data;
  }

  $! = ENOENT;
  return;
}

sub setup_term_builtin { # $success ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  my $name = $ENV{"TERM"};
  if (!$name) {
    $! = ENOENT;
    $@ = "termbox: TERM environment variable not set";
    return;
  }

  if (exists $terms->{$name}) {
    my $t = $terms->{$name};
    $keys = $t->{keys};
    $funcs = $t->{funcs};
    return "0E0";
  }

  state $compat_table = {
    "xterm" => {
      keys    => $xterm_keys,
      funcs   => $xterm_funcs,
    },
    "rxvt" => {
      keys    => $rxvt_unicode_keys, 
      funcs   => $rxvt_unicode_funcs,
    },
    "linux" => {
      keys    => $linux_keys,
      funcs   => $linux_funcs,
    },
    "Eterm" => {
      keys    => $eterm_keys,
      funcs   => $eterm_funcs,
    },
    "screen" => {
      keys    => $screen_keys,
      funcs   => $screen_funcs,
    },
    # let's assume that 'cygwin' is xterm compatible
    "cygwin" => {
      keys    => $xterm_keys,
      funcs   => $xterm_funcs,
    },
    "st" => {
      keys    => $xterm_keys,
      funcs   => $xterm_funcs,
    },
  };

  # try compatibility variants
  foreach (keys %$compat_table) {
    if (index($name, $_) != -1) {
      my $it = $compat_table->{$_};
      $keys = $it->{keys};
      $funcs = $it->{funcs};
      return "0E0";
    }
  }

  $! = EFAULT;
  $@ = "termbox: unsupported terminal";
  return; 
}

sub setup_term { # $success ()
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $! = @_ ? E2BIG : 0;

  my $data;
  my @header = (0) x 6;
  my ($str_offset, $table_offset);

  $data = load_terminfo();
  if ($!) {
    return setup_term_builtin();
  }

  open(my $rd, '<:raw', $data);
  # 0: magic number, 1: size of names section, 2: size of boolean section, 3:
  # size of numbers section (in integers), 4: size of the strings section (in
  # integers), 5: size of the string table

  read($rd, my $buf, scalar(@header)*$Config{i16size});
  if ($!) {
    return;
  } else {
    @header = unpack('v*', $buf);
  }
  
  my $number_sec_len = 2;
  if ($header[0] == 542) {
    # doc says it should be octal 0542, but what I see it terminfo files 
    # is 542, learn to program please... thank you..
    $number_sec_len = 4;
  }

  if (($header[1]+$header[2])%2 != 0) {
    # old quirk to align everything on word boundaries
    $header[2] += 1;
  }
  $str_offset = ti_header_length + $header[1] + $header[2] + $number_sec_len*$header[3];
  $table_offset = $str_offset + 2*$header[4];

  $keys = [];
  for my $i (0 .. 0xffff - key_min -1) {
    $keys->[$i] = ti_read_string($rd, $str_offset+2*$ti_keys->[$i], $table_offset);
    if ($!) {
      return;
    }
  }
  $funcs = [];
  # the last two entries are reserved for mouse. because the table offset is
  # not there, the two entries have to fill in manually
  for my $i (0 .. t_max_funcs - 2 -1) {
    $funcs->[$i] = ti_read_string($rd, $str_offset+2*$ti_funcs->[$i], $table_offset);
    if ($!) {
      return;
    }
  }
  $funcs->[t_enter_mouse] = ti_mouse_enter;
  $funcs->[t_exit_mouse] = ti_mouse_leave;
  return "0E0";
  # Lexical filehandles with my are closed when their scope is left
  # or their reference count drops to zero.
}

sub ti_read_string { # $string ($rd, $str_off, $table)
  my ($rd, $str_off, $table) = @_;
  croak(usage("$!", __FILE__, __FUNCTION__)) if
    $!  = @_ < 3                          ? EINVAL
        : @_ > 3                          ? E2BIG
        : !defined(_HANDLE($rd))          ? EBADF
        : !defined(_NONNEGINT($str_off))  ? EINVAL
        : !defined(_NONNEGINT($table))    ? EINVAL
        : 0;
        ;

  my $off;

  seek($rd, $str_off, 0);
  if ($!) {
    return "";
  }
  read($rd, my $buf, $Config{i16size});
  if ($!) {
    return "";
  } else {
    ($off) = unpack('v', $buf);
  }
  seek($rd, $table + $off, 0);
  if ($!) {
    return "";
  }
  my $bs = '';
  for (;;) {
    read($rd, $b, $Config{u8size});
    if ($!) {
      return "";
    }
    if ($b eq "\0") {
      last;
    }
    $bs .= $b;
  }
  return $bs;
}

1;

__END__

=head1 NAME

Termbox::Go::Terminfo - Terminfo implementation for Termbox

=head1 DESCRIPTION

This module contains some Terminfo functions for the implementation of 
Termbox for *nix.

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

=head1 SEE ALSO

L<terminfo.go|https://raw.githubusercontent.com/nsf/termbox-go/master/terminfo.go>

=cut

#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 SUBROUTINES

=head2 load_terminfo

 my \$data | undef = load_terminfo();

=head2 setup_term

 my $success = setup_term();

=head2 setup_term_builtin

 my $success = setup_term_builtin();

=head2 ti_read_string

 my $string = ti_read_string($rd, $str_off, $table);

=head2 ti_try_path

 my \$data | undef = ti_try_path($path);


=cut

