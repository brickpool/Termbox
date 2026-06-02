use 5.010;
use strict;
use warnings;

use Test::More;

BEGIN {
  use_ok 'Params::Check';
  require_ok 'Termbox::PP';
}

sub _check {
  my ($tmpl, $vals) = @_;
  my %tmpl = %{$tmpl};
  my %vals = %{$vals};

  local $Params::Check::SANITY_CHECK_TEMPLATE = 1;
  local $Params::Check::NO_DUPLICATES         = 1;
  local $Params::Check::ALLOW_UNKNOWN         = 0;

  return Params::Check::check({ v => \%tmpl }, \%vals) ? 1 : 0;
}

subtest 'numeric templates' => sub {
  plan tests => 10;

  is(_check(Termbox::_POSINT(), { v => 1 }), 1, '_POSINT accepts 1');
  is(_check(Termbox::_POSINT(), { v => 0 }), 0, '_POSINT rejects 0');

  is(_check(Termbox::_NONNEGINT(), { v => 0 }), 1, '_NONNEGINT accepts 0');
  is(_check(Termbox::_NONNEGINT(), { v => -1 }), 0, '_NONNEGINT rejects -1');

  is(_check(Termbox::_INT(), { v => -10 }), 1, '_INT accepts negative');
  is(_check(Termbox::_INT(), { v => 0 }),   1, '_INT accepts zero');
  is(_check(Termbox::_INT(), { v => 'x' }), 0, '_INT rejects non-numeric');

  is(_check(Termbox::_BOOL(), { v => 0 }), 1, '_BOOL accepts 0');
  is(_check(Termbox::_BOOL(), { v => 1 }), 1, '_BOOL accepts 1');
  is(_check(Termbox::_BOOL(), { v => 2 }), 0, '_BOOL rejects 2');
};

subtest 'string and class templates' => sub {
  plan tests => 6;

  is(_check(Termbox::_STRING(), { v => 'abc' }), 1, 
    '_STRING accepts non-empty string');
  is(_check(Termbox::_STRING(), { v => '' }), 0, 
    '_STRING rejects empty string');

  is(_check(Termbox::_STRING0(), { v => '' }), 1, 
    '_STRING0 accepts empty string');
  is(_check(Termbox::_STRING0(), { v => 'x' }), 1, 
    '_STRING0 accepts non-empty string');

  is(_check(Termbox::_CLASS(), { v => 'Termbox::Event' }), 1,
    '_CLASS accepts package-like name');
  is(_check(Termbox::_CLASS(), { v => 'Termbox-Event' }), 0,
    '_CLASS rejects invalid class name');
};

subtest 'reference and instance templates' => sub {
  plan tests => 12;

  my $x = 42;
  is(_check(Termbox::_REF0(), { v => \$x }), 1, '_REF0 accepts scalar ref');
  is(_check(Termbox::_REF0(), { v => $x }),  0, '_REF0 rejects non-ref');

  is(_check(Termbox::_ARRAY0(), { v => [] }), 1, '_ARRAY0 accepts array ref');
  is(_check(Termbox::_ARRAY0(), { v => {} }), 0, '_ARRAY0 rejects hash ref');

  my $s = 'abc';
  is(_check(Termbox::_SCALAR0(), { v => \undef }), 1,
    '_SCALAR0 accepts \undef');
  is(_check(Termbox::_SCALAR0(), { v => \0 }), 1,
    '_SCALAR0 accepts scalar int ref');
  is(_check(Termbox::_SCALAR0(), { v => \$s }), 1,
    '_SCALAR0 accepts scalar string ref');
  is(_check(Termbox::_SCALAR0(), { v => undef }), 0,
    '_SCALAR0 rejects undef');
  is(_check(Termbox::_SCALAR0(), { v => $s }), 0,
    '_SCALAR0 rejects non-ref scalar');
  is(_check(Termbox::_SCALAR0(), { v => [] }), 0,
    '_SCALAR0 rejects array ref');

  my $event = Termbox::Event->new();
  is(_check(Termbox::_INSTANCE(), { v => $event }), 1,
    '_INSTANCE accepts blessed object');
  is(_check(Termbox::_INSTANCE(), { v => [] }), 0,
    '_INSTANCE rejects unblessed ref');
};

done_testing;
