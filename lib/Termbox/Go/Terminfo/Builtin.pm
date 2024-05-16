# ------------------------------------------------------------------------
#
#   terminfo builtin Termbox implementation
#
#   Code based on termbox-go v1.1.1, 21. April 2021
#
#   Copyright (C) 2012 termbox-go authors
#
# ------------------------------------------------------------------------
#   Author => 2024 J. Schneider
# ------------------------------------------------------------------------

package Termbox::Go::Terminfo::Builtin;

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

BEGIN {
  require List::Util;
  if (exists &List::Util::pairvalues) {
    List::Util->import(qw( pairvalues ));
  } else {
    # pairvalues is not available, so we have to use our own variant
    *pairvalues = sub { return @_[ grep { $_ % 2 } 1..0+@_ ] };
  }
}

# ------------------------------------------------------------------------
# Exports ----------------------------------------------------------------
# ------------------------------------------------------------------------

=head1 EXPORTS

Nothing per default, but can export the following per request:

  :all

    :index
      t_enter_ca
      t_exit_ca
      t_show_cursor
      t_hide_cursor
      t_clear_screen
      t_sgr0
      t_underline
      t_bold
      t_hidden
      t_blink
      t_dim
      t_cursive
      t_reverse
      t_enter_keypad
      t_exit_keypad
      t_enter_mouse
      t_exit_mouse
      t_max_funcs

    :const
      ti_magic
      ti_header_length
      ti_mouse_enter
      ti_mouse_leave

    :vars
      $eterm_keys
      $eterm_funcs
      $screen_keys
      $screen_funcs
      $xterm_keys
      $xterm_funcs
      $rxvt_unicode_keys
      $rxvt_unicode_funcs
      $linux_keys
      $linux_funcs
      $rxvt_256color_keys
      $rxvt_256color_funcs
      $terms

=cut

use Exporter qw( import );

our @EXPORT_OK = qw(
);

our %EXPORT_TAGS = (

  index => [qw(
    t_enter_ca
    t_exit_ca
    t_show_cursor
    t_hide_cursor
    t_clear_screen
    t_sgr0
    t_underline
    t_bold
    t_hidden
    t_blink
    t_dim
    t_cursive
    t_reverse
    t_enter_keypad
    t_exit_keypad
    t_enter_mouse
    t_exit_mouse
    t_max_funcs
  )],

  const => [qw(
    ti_magic
    ti_header_length
    ti_mouse_enter
    ti_mouse_leave
  )],

  vars => [qw(
    $eterm_keys
    $eterm_funcs
    $screen_keys
    $screen_funcs
    $xterm_keys
    $xterm_funcs
    $rxvt_unicode_keys
    $rxvt_unicode_funcs
    $linux_keys
    $linux_funcs
    $rxvt_256color_keys
    $rxvt_256color_funcs
    $terms
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

# from termbox.go
use constant {
  # for future contributors: after adding something here,
  # you have to add the corresponding index in a terminfo
  # file to C<$Terminfo::ti_funcs>. The values can be taken
  # from (ncurses) C<term.h>. The builtin terminfo values in this module 
  # also needs adjusting with the new values.
  t_enter_ca      => 0,
  t_exit_ca       => 1,
  t_show_cursor   => 2,
  t_hide_cursor   => 3,
  t_clear_screen  => 4,
  t_sgr0          => 5,
  t_underline     => 6,
  t_bold          => 7,
  t_hidden        => 8,
  t_blink         => 9,
  t_dim           => 10,
  t_cursive       => 11,
  t_reverse       => 12,
  t_enter_keypad  => 13,
  t_exit_keypad   => 14,
  t_enter_mouse   => 15,
  t_exit_mouse    => 16,
  t_max_funcs     => 17,
};

# from terminfo.go
use constant {
  ti_magic         => 0432,
  ti_header_length => 12,
  ti_mouse_enter   => "\x1b[?1000h\x1b[?1002h\x1b[?1015h\x1b[?1006h",
  ti_mouse_leave   => "\x1b[?1006l\x1b[?1015l\x1b[?1002l\x1b[?1000l",
};

# ------------------------------------------------------------------------
# Variables ---------------------------------------------------------------
# ------------------------------------------------------------------------

# Eterm
our $eterm_keys = [
  "\x1b[11~", "\x1b[12~", "\x1b[13~", "\x1b[14~", "\x1b[15~", "\x1b[17~", 
  "\x1b[18~", "\x1b[19~", "\x1b[20~", "\x1b[21~", "\x1b[23~", "\x1b[24~", 
  "\x1b[2~", "\x1b[3~", "\x1b[7~", "\x1b[8~", "\x1b[5~", "\x1b[6~", "\x1b[A", 
  "\x1b[B", "\x1b[D", "\x1b[C",
];
our $eterm_funcs = [pairvalues(
  t_enter_ca      => "\x1b7\x1b[?47h",
  t_exit_ca       => "\x1b[2J\x1b[?47l\x1b8",
  t_show_cursor   => "\x1b[?25h",
  t_hide_cursor   => "\x1b[?25l",
  t_clear_screen  => "\x1b[H\x1b[2J",
  t_sgr0          => "\x1b[m\x0f",
  t_underline     => "\x1b[4m",
  t_bold         => "\x1b[1m",
  t_hidden       => "",
  t_blink        => "\x1b[5m",
  t_dim          => "",
  t_cursive      => "",
  t_reverse      => "\x1b[7m",
  t_enter_keypad => "",
  t_exit_keypad  => "",
  t_enter_mouse  => "",
  t_exit_mouse   => "",
)];

# screen
our $screen_keys = [
  "\x1bOP", "\x1bOQ", "\x1bOR", "\x1bOS", "\x1b[15~", "\x1b[17~", "\x1b[18~", 
  "\x1b[19~", "\x1b[20~", "\x1b[21~", "\x1b[23~", "\x1b[24~", "\x1b[2~", 
  "\x1b[3~", "\x1b[1~", "\x1b[4~", "\x1b[5~", "\x1b[6~", "\x1bOA", "\x1bOB", 
  "\x1bOD", "\x1bOC",
];
our $screen_funcs = [pairvalues(
  t_enter_ca     => "\x1b[?1049h",
  t_exit_ca      => "\x1b[?1049l",
  t_show_cursor  => "\x1b[34h\x1b[?25h",
  t_hide_cursor  => "\x1b[?25l",
  t_clear_screen => "\x1b[H\x1b[J",
  t_sgr0         => "\x1b[m\x0f",
  t_underline    => "\x1b[4m",
  t_bold         => "\x1b[1m",
  t_hidden       => "",
  t_blink        => "\x1b[5m",
  t_dim          => "",
  t_cursive      => "",
  t_reverse      => "\x1b[7m",
  t_enter_keypad => "\x1b[?1h\x1b=",
  t_exit_keypad  => "\x1b[?1l\x1b>",
  t_enter_mouse  => ti_mouse_enter,
  t_exit_mouse   => ti_mouse_leave,
)];

# xterm
our $xterm_keys = [
  "\x1bOP", "\x1bOQ", "\x1bOR", "\x1bOS", "\x1b[15~", "\x1b[17~", "\x1b[18~", 
  "\x1b[19~", "\x1b[20~", "\x1b[21~", "\x1b[23~", "\x1b[24~", "\x1b[2~", 
  "\x1b[3~", "\x1bOH", "\x1bOF", "\x1b[5~", "\x1b[6~", "\x1bOA", "\x1bOB", 
  "\x1bOD", "\x1bOC",
];
our $xterm_funcs = [pairvalues(
  t_enter_ca     => "\x1b[?1049h",
  t_exit_ca      => "\x1b[?1049l",
  t_show_cursor  => "\x1b[?12l\x1b[?25h",
  t_hide_cursor  => "\x1b[?25l",
  t_clear_screen => "\x1b[H\x1b[2J",
  t_sgr0         => "\x1b(B\x1b[m",
  t_underline    => "\x1b[4m",
  t_bold         => "\x1b[1m",
  t_hidden       => "",
  t_blink        => "\x1b[5m",
  t_dim          => "",
  t_cursive      => "",
  t_reverse      => "\x1b[7m",
  t_enter_keypad => "\x1b[?1h\x1b=",
  t_exit_keypad  => "\x1b[?1l\x1b>",
  t_enter_mouse  => ti_mouse_enter,
  t_exit_mouse   => ti_mouse_leave,
)];

# rxvt-unicode
our $rxvt_unicode_keys = [
  "\x1b[11~", "\x1b[12~", "\x1b[13~", "\x1b[14~", "\x1b[15~", "\x1b[17~", 
  "\x1b[18~", "\x1b[19~", "\x1b[20~", "\x1b[21~", "\x1b[23~", "\x1b[24~", 
  "\x1b[2~", "\x1b[3~", "\x1b[7~", "\x1b[8~", "\x1b[5~", "\x1b[6~", "\x1b[A", 
  "\x1b[B", "\x1b[D", "\x1b[C",
];
our $rxvt_unicode_funcs = [pairvalues(
  t_enter_ca     => "\x1b[?1049h",
  t_exit_ca      => "\x1b[r\x1b[?1049l",
  t_show_cursor  => "\x1b[?25h",
  t_hide_cursor  => "\x1b[?25l",
  t_clear_screen => "\x1b[H\x1b[2J",
  t_sgr0         => "\x1b[m\x1b(B",
  t_underline    => "\x1b[4m",
  t_bold         => "\x1b[1m",
  t_hidden       => "",
  t_blink        => "\x1b[5m",
  t_dim          => "",
  t_cursive      => "",
  t_reverse      => "\x1b[7m",
  t_enter_keypad => "\x1b=",
  t_exit_keypad  => "\x1b>",
  t_enter_mouse  => ti_mouse_enter,
  t_exit_mouse   => ti_mouse_leave,
)];

# linux
our $linux_keys = [
  "\x1b[[A", "\x1b[[B", "\x1b[[C", "\x1b[[D", "\x1b[[E", "\x1b[17~", 
  "\x1b[18~", "\x1b[19~", "\x1b[20~", "\x1b[21~", "\x1b[23~", "\x1b[24~", 
  "\x1b[2~", "\x1b[3~", "\x1b[1~", "\x1b[4~", "\x1b[5~", "\x1b[6~", "\x1b[A", 
  "\x1b[B", "\x1b[D", "\x1b[C",
];
our $linux_funcs = [pairvalues(
  t_enter_ca     => "",
  t_exit_ca      => "",
  t_show_cursor  => "\x1b[?25h\x1b[?0c",
  t_hide_cursor  => "\x1b[?25l\x1b[?1c",
  t_clear_screen => "\x1b[H\x1b[J",
  t_sgr0         => "\x1b[0;10m",
  t_underline    => "\x1b[4m",
  t_bold         => "\x1b[1m",
  t_hidden       => "",
  t_blink        => "\x1b[5m",
  t_dim          => "",
  t_cursive      => "",
  t_reverse      => "\x1b[7m",
  t_enter_keypad => "",
  t_exit_keypad  => "",
  t_enter_mouse  => "",
  t_exit_mouse   => "",
)];

# rxvt-256color
our $rxvt_256color_keys = [
  "\x1b[11~", "\x1b[12~", "\x1b[13~", "\x1b[14~", "\x1b[15~", "\x1b[17~", 
  "\x1b[18~", "\x1b[19~", "\x1b[20~", "\x1b[21~", "\x1b[23~", "\x1b[24~", 
  "\x1b[2~", "\x1b[3~", "\x1b[7~", "\x1b[8~", "\x1b[5~", "\x1b[6~", "\x1b[A", 
  "\x1b[B", "\x1b[D", "\x1b[C",
];
our $rxvt_256color_funcs = [pairvalues(
  t_enter_ca     => "\x1b7\x1b[?47h",
  t_exit_ca      => "\x1b[2J\x1b[?47l\x1b8",
  t_show_cursor  => "\x1b[?25h",
  t_hide_cursor  => "\x1b[?25l",
  t_clear_screen => "\x1b[H\x1b[2J",
  t_sgr0         => "\x1b[m\x0f",
  t_underline    => "\x1b[4m",
  t_bold         => "\x1b[1m",
  t_hidden       => "",
  t_blink        => "\x1b[5m",
  t_dim          => "",
  t_cursive      => "",
  t_reverse      => "\x1b[7m",
  t_enter_keypad => "\x1b=",
  t_exit_keypad  => "\x1b>",
  t_enter_mouse  => ti_mouse_enter,
  t_exit_mouse   => ti_mouse_leave,
)];

our $terms = {
  "Eterm" => {
    keys  => $eterm_keys,
    funcs => $eterm_funcs,
  },
  "screen" => {
    keys  => $screen_keys, 
    funcs => $screen_funcs,
  },
  "xterm"  => {
    keys  => $xterm_keys, 
    funcs => $xterm_funcs,
  },
  "rxvt-unicode" => {
    keys  => $rxvt_unicode_keys, 
    funcs => $rxvt_unicode_funcs,
  },
  "linux" => {
    keys  => $linux_keys, 
    funcs => $linux_funcs,
  },
  "rxvt-256color" => {
    keys  => $rxvt_256color_keys, 
    funcs => $rxvt_256color_funcs,
  },
};

1;

__END__

=head1 NAME

Termbox::Go::Terminfo::Builtin - Terminfo builtin implementation for Termbox

=head1 DESCRIPTION

This module contains some Terminfo builtin functions for the implementation of 
Termbox terminal support.

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

L<terminfo_builtin.go|https://raw.githubusercontent.com/nsf/termbox-go/master/terminfo_builtin.go>

=cut
