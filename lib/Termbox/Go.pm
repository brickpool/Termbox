# ------------------------------------------------------------------------
#
#   Termbox::Go interface module
#
# ------------------------------------------------------------------------
#   Author: 2024 J. Schneider
# ------------------------------------------------------------------------

package Termbox::Go;

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
use Import::into;

my %module = (
  MSWin32 => 'Win32',
);
 
my $module = $module{$^O} || 'Win32';
 
require Termbox::Go::Legacy;
require Termbox::Go::Common;
require "Termbox/Go/$module.pm";
require Termbox::Go::Win32::Backend if $module eq 'Win32';

# ------------------------------------------------------------------------
# Exports ----------------------------------------------------------------
# ------------------------------------------------------------------------

my $target = 'termbox';

sub import {
  my ($me, @args) = @_;
  my ($caller) = caller;

  my $TB_IMPL = !!0;
  my @legacy_tags = ();
  my @common_tags = ();
  my @golang_tags = ();
  foreach my $tag (@args) {
    switch: for ($tag) {
      case: /^([!]?):DEFAULT$/ and do {
        # Nothing per default
        last;
      };
      case: /^([!]?):api$/ and do {
        push @legacy_tags, map { $1 ? "!$_" : $_ } qw( :api );
        push @golang_tags, map { $1 ? "!$_" : $_ } qw( :api );
        last;
      };
      case: /^([!]?):const$/ and do {
        push @legacy_tags, map { $1 ? "!$_" : $_ } qw( :const );
        push @common_tags, map { $1 ? "!$_" : $_ } qw( :const );
        last;
      };
      case: /^([!]?):keys$/ and do {
        push @legacy_tags, map { $1 ? "!$_" : $_ } qw( :keys );
        push @common_tags, map { $1 ? "!$_" : $_ } qw( :keys );
        last;
      };
      case: /^([!]?):colors$/ and do {
        push @legacy_tags, map { $1 ? "!$_" : $_ } qw( :color :attr );
        push @common_tags, map { $1 ? "!$_" : $_ } qw( :color :attr );
        last;
      };
      case: /^([!]?):event$/ and do {
        push @legacy_tags, map { $1 ? "!$_" : $_ } qw( :event :mode :input :output );
        push @common_tags, map { $1 ? "!$_" : $_ } qw( :event :mode :input :output );
        last;
      };
      case: /^([!]?):return$/ and do {
        push @legacy_tags, map { $1 ? "!$_" : $_ } qw( :return );
        last;
      };
      case: /^([!]?):func$/ and do {
        push @common_tags, map { $1 ? "!$_" : $_ } qw( :func );
        last;
      };
      case: /^:all$/ and do {
        push @legacy_tags, qw( :all );
        push @common_tags, qw( :all !:bool !:vars );
        push @golang_tags, qw( :all );
        last;
      };
      case: /^[!]:all$/ and do {
        push @legacy_tags, qw( !:all );
        push @common_tags, qw( !:all );
        push @golang_tags, qw( !:all );
        last;
      };
      case: /^([!]?)TB_IMPL$/ and do {
        $TB_IMPL = !$1;
        last;
      };
      default: {
        croak
          qq{"$_" is not exported by the $me module\n}
          .q{Can't continue after import errors};
        return;
      }
    }
  }

  # Import the requested tags into the caller's namespace
  if ($TB_IMPL) {
    push @legacy_tags, qw( :all ) unless @legacy_tags;
    Termbox::Go::Legacy->import::into($caller, @legacy_tags);
  } elsif (@common_tags) {
    Termbox::Go::Common->import::into($caller, @common_tags);
  } elsif (@golang_tags) {
    "Termbox::Go::$module"->import::into($caller, @golang_tags);
  } else {
    # Import ":all" into the termbox::* namespace
    Termbox::Go::Common->import::into($target, qw(
      :all
      !:bool
      !:vars
    ));
    "Termbox::Go::$module"->import::into($target, qw( 
      :all
    ));
  }

  return !0;
}

sub unimport {
  my ($caller) = caller; 
  Termbox::Go::Legacy->unimport::out_of($caller, qw( :all ));
  Termbox::Go::Common->unimport::out_of($caller, qw( :all ));
  Termbox::Go::Common->unimport::out_of($target, qw( :all ));
  "Termbox::Go::$module"->unimport::out_of($caller, qw( :all ));
  "Termbox::Go::$module"->unimport::out_of($target, qw( :all ));
}

1;

__END__

=head1 NAME

Termbox::Go - Pure Perl termbox implementation

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

L<Import::into> 

=head1 SEE ALSO

L<Termbox>

L<Go termbox implementation|http://godoc.org/github.com/nsf/termbox-go>

=cut
