# ------------------------------------------------------------------------
#
#   Termbox::Go module for development tools
#
#   Debug macros based on libserialport v0.1.1, 27. Jan 2016
#
#   Copyright (C) 2014 Martin Ling <martin-libserialport@earth.li>
#   Copyright (C) 2014 Aurelien Jacobs <aurel@gnuage.org>
#
# ------------------------------------------------------------------------
#   Author: 2024 J. Schneider
# ------------------------------------------------------------------------

package Termbox::Go::Devel;

# ------------------------------------------------------------------------
# Boilerplate ------------------------------------------------------------
# ------------------------------------------------------------------------

use 5.014;
use strict;
use warnings;

# version '...'
use version;
our $VERSION = version->declare('v0.1.1_0');

# authority '...'
our $AUTHORITY = 'github:brickpool';

# ------------------------------------------------------------------------
# Imports ----------------------------------------------------------------
# ------------------------------------------------------------------------

eval { require Devel::PartialDump };
use Devel::StrictMode;
use POSIX qw( :errno_h );

# ------------------------------------------------------------------------
# Exports ----------------------------------------------------------------
# ------------------------------------------------------------------------

=head1 EXPORTS

Nothing per default, but can export the following per request:

  :all

    $default_dumper
    __CALLER__
    __FUNCTION__
    usage
    DEBUG_FMT
    DEBUG
    DEBUG_ERROR
    DEBUG_FAIL
    RETURN_UNDEF
    SHOW_CODE
    SHOW_CODEVAL
    RETURN_OK
    SHOW_ERROR
    SHOW_FAIL
    SHOW_INT
    SHOW_STRING
    SHOW_POINTER
    SET_ERROR
    SET_FAIL
    TRACE
    TRACE_VOID

=cut

use Exporter qw( import );

our @EXPORT_OK = qw(
  $default_dumper
  __CALLER__
  __FUNCTION__
  usage
  DEBUG_FMT
  DEBUG
  DEBUG_ERROR
  DEBUG_FAIL
  RETURN_UNDEF
  SHOW_CODE
  SHOW_CODEVAL
  RETURN_OK
  SHOW_ERROR
  SHOW_FAIL
  SHOW_INT
  SHOW_STRING
  SHOW_POINTER
  SET_ERROR
  SET_FAIL
  TRACE
  TRACE_VOID
);

our %EXPORT_TAGS = (
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
# Variables --------------------------------------------------------------
# ------------------------------------------------------------------------

our $default_dumper;
BEGIN {
  if ( exists &Devel::PartialDump::dump ) {
    $default_dumper = $Devel::PartialDump::default_dumper;
    $default_dumper->max_length(32);
  }
}

# ------------------------------------------------------------------------
# Subroutines ------------------------------------------------------------
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
  my $pkg = __CALLER__(0)->{package}    // 'main';
  my $sub = __CALLER__(1)->{subroutine} // 'main::__ANON__';
  my $__func__ = (split $pkg . '::', $sub)[-1];
  return $__func__;
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

# Debug output macro.
sub DEBUG_FMT :prototype($@) { # void ($fmt, @args)
  my ($fmt, @args) = @_;
  if (STRICT && exists &termbox::DebugHandler) {
    termbox::DebugHandler("$fmt.\n", @args);
  }
  return;
}

# Debug output macro.
sub DEBUG :prototype($) { # void ($msg)
  goto &DEBUG_FMT;
}

# Debug output macro.
sub DEBUG_ERROR :prototype($$) { # void ($err, $msg)
  my ($err, $msg) = @_;
  my $pkg = __CALLER__(0)->{package}    // 'main';
  my $sub = __CALLER__(1)->{subroutine} // 'main::__ANON__';
  my $__func__ = (split $pkg . '::', $sub)[-1];
  DEBUG_FMT("%s returning $err: $msg", $__func__);
  return;
}

# Debug output macro.
sub DEBUG_FAIL :prototype($) { # void ($msg)
  my ($msg) = @_;
  my ($errno, $errmsg) = ($!+0, "$!");
  my $pkg = __CALLER__(0)->{package}    // 'main';
  my $sub = __CALLER__(1)->{subroutine} // 'main::__ANON__';
  my $__func__ = (split $pkg . '::', $sub)[-1];
  DEBUG_FMT("%s returning $errno: $msg: %s", $__func__, $errmsg);
  return;
}

# Debug output macro.
sub RETURN_UNDEF :prototype() { # void ()
  my $pkg = __CALLER__(0)->{package}    // 'main';
  my $sub = __CALLER__(1)->{subroutine} // 'main::__ANON__';
  my $__func__ = (split $pkg . '::', $sub)[-1];
  DEBUG_FMT("%s returning", $__func__);
  return;
}

# Debug output macro.
sub SHOW_CODE :prototype($) { # $errstr ($err)
  my $pkg = __CALLER__(0)->{package}    // 'main';
  my $sub = __CALLER__(1)->{subroutine} // 'main::__ANON__';
  my $__func__ = (split $pkg . '::', $sub)[-1];
  DEBUG_FMT("%s returning %s", $__func__, 
    $default_dumper ? $default_dumper->dump($_[0]) : $_[0]);
  return $_[0];
}

# Debug output macro.
sub SHOW_CODEVAL :prototype($) { # $errno ($err)
  my $pkg = __CALLER__(0)->{package}    // 'main';
  my $sub = __CALLER__(1)->{subroutine} // 'main::__ANON__';
  my $__func__ = (split $pkg . '::', $sub)[-1];
  DEBUG_FMT("%s returning %d", $__func__, int($_[0]));
  return int($_[0]);
}

# Debug output macro.
# Returns the string "0E0", which evaluates to 0 as a number, but true as a 
# boolean.
sub RETURN_OK :prototype() { # $ ()
  $_[0] = "0E0";
  goto &SHOW_CODE;
}

# Debug output macro.
sub SHOW_ERROR :prototype($$) { # $err ($err, $msg)
  my ($err, $msg) = @_;
  my $pkg = __CALLER__(0)->{package}    // 'main';
  my $sub = __CALLER__(1)->{subroutine} // 'main::__ANON__';
  my $__func__ = (split $pkg . '::', $sub)[-1];
  DEBUG_FMT("%s returning $err: $msg", $__func__);
  return $err;
}

# Debug output macro.
sub SHOW_FAIL :prototype($) {# undef ($msg)
  my ($msg) = @_;
  my ($errno, $errmsg) = ($!+0, "$!");
  my $pkg = __CALLER__(0)->{package}    // 'main';
  my $sub = __CALLER__(1)->{subroutine} // 'main::__ANON__';
  my $__func__ = (split $pkg . '::', $sub)[-1];
  DEBUG_FMT("%s returning $errno: $msg: %s", $__func__, $errmsg);
  return;
}

# Debug output macro.
sub SHOW_INT { # $ ($)
  goto &SHOW_CODE
}

# Debug output macro.
sub SHOW_STRING { # $ ($)
  goto &SHOW_CODE
}

# Debug output macro.
sub SHOW_POINTER { # \$|\@|\% (\$|\@|\%)
  goto &SHOW_CODE
}

# Debug output macro.
# set $val to $err and prints the message $msg in STRICT mode.
sub SET_ERROR :prototype($$$) { # void ($val, $err, $msg)
  $_[0] = $_[1];
  shift; pop while @_ > 2;
  goto &DEBUG_ERROR;
}

# Debug output macro.
# Set $val to $!{EFAULT} and prints the message $msg in STRICT mode.
sub SET_FAIL :prototype($$) { # void ($val, $msg)
  $_[0] = EFAULT;
  shift; pop while @_ > 1;
  goto &DEBUG_FAIL;
}

# Debug output macro.
sub TRACE :prototype($@) { # void ($fmt, @args)
  my $fmt = shift;
  my $pkg = __CALLER__(0)->{package}    // 'main';
  my $sub = __CALLER__(1)->{subroutine} // 'main::__ANON__';
  my $__func__ = (split $pkg . '::', $sub)[-1];
  DEBUG_FMT("%s($fmt) called", $__func__, @_);
  return;
}

# Debug output macro.
sub TRACE_VOID :prototype() { # void ()
  my $pkg = __CALLER__(0)->{package}    // 'main';
  my $sub = __CALLER__(1)->{subroutine} // 'main::__ANON__';
  my $__func__ = (split $pkg . '::', $sub)[-1];
  DEBUG_FMT("%s() called", $__func__);
  return;
}

1;

__END__

=head1 NAME

Termbox::Go::Devel - Development tools module

=head1 DESCRIPTION

This module contains utility functions for the implementation of Termbox.

=head1 COPYRIGHT AND LICENCE

 This file is part of the port of Termbox.
 
 Copyright (C) 2024 by J. Schneider
 
 Some library content was taken from the libserialport implementation
 which is licensed under LGPL3 licence.
 
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

L<Devel::StrictMode>

=head1 SEE ALSO

L<Devel::TypeCheck>

L<Devel::PartialDump>

L<libserialport_internal.h|https://github.com/scottmudge/libserialport-cmake/blob/master/libserialport_internal.h>

=cut
