use 5.014;
use warnings;

use Test::More tests => 4;
use Test::Exception;

use Data::Dumper;
use Devel::StrictMode;

use_ok 'Termbox::Go::Common', qw( :func max_attr );

my @rgb = (1,2,3);
my $attr;

subtest 'RGBToAttribute()' => sub {
  plan tests => 3;
  lives_ok { $attr = RGBToAttribute(@rgb) } 'lives';
  is( 
    ($attr / max_attr()) & 0xffffff, 
    0x010203, 
    'attr'
  );
  is( 
    ($attr / max_attr()) >> 25, 
    1, 
    'msb'
  );
  diag sprintf("%08x", $attr) if STRICT;
};

subtest 'AttributeToRGB()' => sub {
  plan tests => 2;
  lives_ok { @rgb = AttributeToRGB($attr) } 'lives';
  is_deeply( \@rgb, [1,2,3], 'rgb' );
  diag join(',', @rgb) if STRICT;
};

my $ok;
lives_ok { $ok = is_cursor_hidden(1, 1) } 'is_cursor_hidden()';

done_testing;
