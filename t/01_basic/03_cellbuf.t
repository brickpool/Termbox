use 5.010;
use warnings;

use Test::More;
use Test::Exception;

use Data::Dumper;
use Devel::StrictMode;

BEGIN {
  use_ok 'Termbox::PP';
}

my $buf;
subtest 'cellbuf->new()' => sub {
  plan tests => 2;
  $buf = new_ok( 'cellbuf' );
  isa_ok($buf, 'cellbuf');
  diag Dumper $buf if STRICT;
};

subtest 'cellbuf->init()' => sub {
  plan tests => 5;
  lives_ok(
    sub {
      $buf->init(3, 3);
    },
    'init'
  );
  is( $buf->{width},  3, 'width' );
  is( $buf->{height}, 3, 'height' );
  is (
    scalar(@{ $buf->{cells} }),
    $buf->{width} * $buf->{height}, 
    'size'
  );
  is_deeply(
    $buf->{cells},
    [ map { Termbox::Cell->new() } 1..$buf->{width}*$buf->{height} ],
    'exists'
  );
  diag Dumper $buf if STRICT;
};

subtest 'cellbuf->clear()' => sub {
  plan tests => 5;
  lives_ok(
    sub {
      my $i;
      $_->{fg} = ++$i foreach @{ $buf->{cells} };
      $buf->clear() and die;
    },
    'clear'
  );
  is( $buf->{width},  3, 'width' );
  is( $buf->{height}, 3, 'height' );
  is (
    scalar(@{ $buf->{cells} }),
    $buf->{width} * $buf->{height}, 
    'size'
  );
  is_deeply(
    $buf->{cells},
    [ 
      map { { ch => ' ', fg => 0, bg => 0 } } 
        1..$buf->{width}*$buf->{height} 
    ],
    'empty'
  );
  diag Dumper $buf if STRICT;
};

subtest 'cellbuf->resize()' => sub {
  plan tests => 12;
  lives_ok(
    sub {
      my $i;
      $_->{fg} = ++$i foreach @{ $buf->{cells} };
      $buf->resize(2, 3);
    },
    'resize 2x3'
  );
  diag Dumper $buf if STRICT;
  is (
    scalar(@{ $buf->{cells} }),
    $buf->{width} * $buf->{height}, 
    'size'
  );
  is_deeply(
    $buf->{cells},
    [
      { ch => ' ', fg => 1, bg => 0 },
      { ch => ' ', fg => 2, bg => 0 },
      { ch => ' ', fg => 4, bg => 0 },
      { ch => ' ', fg => 5, bg => 0 },
      { ch => ' ', fg => 7, bg => 0 },
      { ch => ' ', fg => 8, bg => 0 },
    ],
    'equal'
  );

  lives_ok(
    sub {
      $buf->resize(1, 4);
    },
    'resize 1x4'
  );
  diag Dumper $buf if STRICT;
  is (
    scalar(@{ $buf->{cells} }),
    $buf->{width} * $buf->{height}, 
    'size'
  );
  is_deeply(
    $buf->{cells},
    [
      { ch => ' ', fg => 1, bg => 0 },
      { ch => ' ', fg => 4, bg => 0 },
      { ch => ' ', fg => 7, bg => 0 },
      { ch => ' ', fg => 0, bg => 0 },
    ],
    'equal'
  );

  lives_ok(
    sub {
      $buf->resize(2, 2);
    },
    'resize 2x2'
  );
  diag Dumper $buf if STRICT;
  is (
    scalar(@{ $buf->{cells} }),
    $buf->{width} * $buf->{height}, 
    'size'
  );
  is_deeply(
    $buf->{cells},
    [
      { ch => ' ', fg => 1, bg => 0 },
      { ch => ' ', fg => 0, bg => 0 },
      { ch => ' ', fg => 4, bg => 0 },
      { ch => ' ', fg => 0, bg => 0 },
    ],
    'equal'
  );

  lives_ok(
    sub {
      my $i;
      $_->{fg} = ++$i foreach @{ $buf->{cells} };
      $buf->resize(3, 2);
    },
    'resize 3x2'
  );
  diag Dumper $buf if STRICT;
  is (
    scalar(@{ $buf->{cells} }),
    $buf->{width} * $buf->{height}, 
    'size'
  );
  is_deeply(
    $buf->{cells},
    [
      { ch => ' ', fg => 1, bg => 0 },
      { ch => ' ', fg => 2, bg => 0 },
      { ch => ' ', fg => 0, bg => 0 },
      { ch => ' ', fg => 3, bg => 0 },
      { ch => ' ', fg => 4, bg => 0 },
      { ch => ' ', fg => 0, bg => 0 },
    ],
    'equal'
  );
};

done_testing;
