use strict;
use warnings;

use Test::More;

use Termbox::PP;
use Termbox qw( :api :event );

sub screencap (&) {
  my ($code) = @_;

  use autodie;
  pipe my $r, my $w;
  binmode $_ for $r, $w;
  local $Termbox::global->{wfd} = fileno($w);

  my $err = do { local $@; eval { $code->() }; $@ };
  close $w;
  die $err if $err;

  local $/;
  <$r>;
}

plan skip_all => 'Author testing disabled' 
  if !$ENV{AUTHOR_TESTING};

tb_init();

plan skip_all => 'This test requires a usable terminal'
  if tb_width() <= 0 || tb_height() <= 0;

my $y = 0;
my $fg = 7;

tb_printf(0, $y++, $fg, 0, "cyan (even after mode switch)");
my $got = screencap { tb_present() };

tb_set_output_mode(TB_OUTPUT_GRAYSCALE);

tb_printf(0, $y++, $fg, 0, "gray");
$got .= screencap { tb_present() };

my $expected = do { local $/; <DATA> };
is($got, $expected, 'out matches expected data');

done_testing;

__DATA__
#5[0m[0;36mc[0;36my[0;36ma[0;36mn[0;36m [0;36m([0;36me[0;36mv[0;36me[0;36mn[0;36m [0;36ma[0;36mf[0;36mt[0;36me[0;36mr[0;36m [0;36mm[0;36mo[0;36md[0;36me[0;36m [0;36ms[0;36mw[0;36mi[0;36mt[0;36mc[0;36mh[0;36m)[0m
#5[0m[0;38:5:238mg[0;38:5:238mr[0;38:5:238ma[0;38:5:238my[0m
