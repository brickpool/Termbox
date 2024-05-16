# ------------------------------------------------------------------------
#
#   WCWidth - determine columns needed for a wide character
#
#   Code based on Terminal::WCWidth (a Perl 6 port), 2015
#
#   Copyright (c) 2007 Markus Kuhn (Unicode 5.0)
#                 2014 Jeff Quast <contact@jeffquast.com>
#                 2015 bluebear94 <tkook11@gmail.com>
#
# ------------------------------------------------------------------------
#   Author: 2024 J. Schneider
# ------------------------------------------------------------------------

package Termbox::Go::WCWidth;

# ------------------------------------------------------------------------
# Boilerplate ------------------------------------------------------------
# ------------------------------------------------------------------------

use 5.014;
use strict;
use warnings;

# version '...'
use version;
our $VERSION = version->declare('v0.1.0_0');

# authority '...'
our $AUTHORITY = 'github:brickpool';

# ------------------------------------------------------------------------
# Imports ----------------------------------------------------------------
# ------------------------------------------------------------------------

use Carp qw( croak );
use List::Util qw( any );
use Params::Util qw(
  _STRING
  _NONNEGINT
);
use POSIX qw( :errno_h );

use Termbox::Go::WCWidth::Tables;

# ------------------------------------------------------------------------
# Exports ----------------------------------------------------------------
# ------------------------------------------------------------------------

=head1 EXPORTS

Nothing per default, but can export the following per request:

  :all
    wcwidth
    wcswidth

=cut

use Exporter qw( import );

our @EXPORT_OK = qw(
  wcwidth
  wcswidth
);

our %EXPORT_TAGS = (

  all => [qw(
    wcwidth
    wcswidth
  )],

);

# ------------------------------------------------------------------------
# Functions --------------------------------------------------------------
# ------------------------------------------------------------------------

# Auxiliary function for binary search in interval table
sub bisearch { # $result ($ucs, \@table)
  my ($ucs, $table) = @_;
  my $lower = 0;
  my $upper = scalar(@$table) - 1;
  return 0 if $ucs < $table->[0][0] || $ucs > $table->[$upper][1];
  while ($upper >= $lower) {
    my $mid = ($lower + $upper) >> 1;
    if ($ucs > $table->[$mid][1]) {
      $lower = $mid + 1;
    } elsif ($ucs < $table->[$mid][0]) {
      $upper = $mid - 1;
    } else {
      return 1;
    }
  }
  return 0;
}

sub wcwidth { # $result ($ucs)
  my $ucs = _NONNEGINT(shift) // croak(($! = EINVAL) .' "1/ucs"');
  croak ''.($! = E2BIG) if @_;

  return 0 if (any { $ucs == $_ } (0, 0x034F, 0x2028, 0x2029)) ||
    0x200B <= $ucs && $ucs <= 0x200F ||
    0x202A <= $ucs && $ucs <= 0x202E ||
    0x2060 <= $ucs && $ucs <= 0x2063;
  return -1 if $ucs < 32 || 0x07f <= $ucs && $ucs < 0x0A0;
  return 0 if bisearch($ucs, ZERO_WIDTH);
  return 2 if bisearch($ucs, WIDE_EASTASIAN);
  return 1;
}

sub wcswidth { # $result ($str)
  my $str = _STRING(shift) // croak(($! = EINVAL) .' "1/str"');
  croak ''.($! = E2BIG) if @_;

  my $res = 0;
  for (split //, $str) {
    my $w = wcwidth(ord $_);
    return -1 if $w < 0;
    $res += $w;
  }
  return $res;
}

1;

__END__

=head1 NAME

Termbox::Go::WCWidth - determine columns needed for a wide character

=head1 DESCRIPTION

This module is mainly for console/tty programs that carefully produce output 
for Terminals, or make pretend to be an emulator.

=head1 SYNOPSIS

  sub print_right_aligned {
    my ($s) = @_;
    print " " x (80 - wcswidth($s));
    say $s;
  }
  print_right_aligned("this is right-aligned");
  print_right_aligned("another right-aligned string");

=head1 SUBROUTINES

=head2 C<wcwidth>

Takes a single I<codepoint> and outputs its width:

  wcwidth(0x3042) # "あ" - returns 2

Returns:

=item C<-1> for a control character

=item C<0> for a character that does not advance the cursor (NULL or combining)

=item C<1> for most characters

=item C<2> for full width characters

=head2 C<wcswidth>

Takes a I<string> and outputs its total width:

    wcswidth("*ウルヰ*") # returns 8 = 2 + 6

Returns -1 if any control characters are found.

Unlike the Python version, this module does not support getting the width of
only the first C<n> characters of a string, as you can use the C<substr>
method.

=head1 COPYRIGHT AND LICENCE

 This code was originally derived from C code with the name wcwidth.c.
 
 Copyright (c) 2007 by Markus Kuhn
 
 This library content was taken from the Terminal::WCWidth implementation of 
 Perl 6 which is licensed under MIT licence.
 
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

=item * 2015 by bluebear94 E<lt>tkook11@gmail.comE<gt>

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

L<wcwidth.c|https://www.cl.cam.ac.uk/~mgk25/ucs/wcwidth.c>

L<Text::CharWidth>

L<Terminal::WCWidth|https://github.com/bluebear94/Terminal-WCWidth>

=cut
