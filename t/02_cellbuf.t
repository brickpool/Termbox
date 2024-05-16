use 5.014;
use warnings;

use Test::More tests => 6;
use Test::Exception;

use Data::Dumper;
use Devel::StrictMode;

use_ok 'Termbox::Go::Common', qw( :types :color :vars );

our $back_buffer;
our $front_buffer;

is( ColorDefault(), 0, 'ColorDefault' );

my $buf = $back_buffer;
subtest 'cellbuf->new()' => sub {
  plan tests => 2;
  isa_ok($back_buffer, 'cellbuf');
  isa_ok($front_buffer, 'cellbuf');
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
    [ map { Cell() } 1..$buf->{width}*$buf->{height} ],
    'exists'
  );
  diag Dumper $buf if STRICT;
};

subtest 'cellbuf->clear()' => sub {
  plan tests => 5;
  lives_ok(
    sub {
      my $i;
      $_->{Fg} = ++$i foreach @{ $buf->{cells} };
      $buf->clear();
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
      map { { Ch => ' ', Fg => 0, Bg => 0 } } 
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
      $_->{Fg} = ++$i foreach @{ $buf->{cells} };
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
      { Ch => ' ', Fg => 1, Bg => 0 },
      { Ch => ' ', Fg => 2, Bg => 0 },
      { Ch => ' ', Fg => 4, Bg => 0 },
      { Ch => ' ', Fg => 5, Bg => 0 },
      { Ch => ' ', Fg => 7, Bg => 0 },
      { Ch => ' ', Fg => 8, Bg => 0 },
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
      { Ch => ' ', Fg => 1, Bg => 0 },
      { Ch => ' ', Fg => 4, Bg => 0 },
      { Ch => ' ', Fg => 7, Bg => 0 },
      { Ch => ' ', Fg => 0, Bg => 0 },
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
      { Ch => ' ', Fg => 1, Bg => 0 },
      { Ch => ' ', Fg => 0, Bg => 0 },
      { Ch => ' ', Fg => 4, Bg => 0 },
      { Ch => ' ', Fg => 0, Bg => 0 },
    ],
    'equal'
  );

  lives_ok(
    sub {
      my $i;
      $_->{Fg} = ++$i foreach @{ $buf->{cells} };
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
      { Ch => ' ', Fg => 1, Bg => 0 },
      { Ch => ' ', Fg => 2, Bg => 0 },
      { Ch => ' ', Fg => 0, Bg => 0 },
      { Ch => ' ', Fg => 3, Bg => 0 },
      { Ch => ' ', Fg => 4, Bg => 0 },
      { Ch => ' ', Fg => 0, Bg => 0 },
    ],
    'equal'
  );
};

done_testing;
