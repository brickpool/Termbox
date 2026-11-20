use 5.010;
use strict;
use warnings;

use Test::More;

BEGIN {
  use_ok 'Termbox::PP::Terminfo::Builtin', qw(
    @terminfo_cap_indexes
    %builtin_terms
    @builtin_terms_orders
  );
  require_ok 'Termbox::PP';
  use_ok 'Termbox', qw( :return );
}

BEGIN {
  # Set TERM to a default value on Windows if not set
  $ENV{TERM} //= 'xterm-256color' if $^O eq 'MSWin32';
}

my $expected_count = scalar @terminfo_cap_indexes;

for my $name (@builtin_terms_orders) {
  ok(
    exists $builtin_terms{$name},
    "$name is present in \%builtin_terms"
  );
  my $term = $builtin_terms{$name};
  is(
    scalar(@$term),
    $expected_count,
    "$name has $expected_count terminfo entries"
  );
}

subtest 'load_builtin_caps' => sub {
  local $Termbox::global->{caps} = [];
  local $ENV{TERM} = 'xterm';
  is(Termbox::load_builtin_caps(), TB_OK(), 'exact builtin TERM is supported');
  is_deeply($Termbox::global->{caps}, $builtin_terms{xterm},
    'exact match loads xterm capabilities');

  $ENV{TERM} = 'xterm-256color';
  is(Termbox::load_builtin_caps(), TB_OK(), 'partial builtin TERM is supported');
  is_deeply($Termbox::global->{caps}, $builtin_terms{xterm},
    'partial match loads xterm capabilities');

  $ENV{TERM} = 'dumb';
  is(Termbox::load_builtin_caps(), TB_ERR_UNSUPPORTED_TERM(),
    'unsupported TERM returns TB_ERR_UNSUPPORTED_TERM');

  delete $ENV{TERM};
  is(Termbox::load_builtin_caps(), TB_ERR_NO_TERM(),
    'missing TERM returns TB_ERR_NO_TERM');
};

done_testing;
