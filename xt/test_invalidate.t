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

tb_printf(0, $y++, $fg, 0, "cyan (then gray after mode switch and invalidate)");
my $got = screencap { tb_present() };

tb_set_output_mode(TB_OUTPUT_GRAYSCALE);
tb_invalidate();

tb_printf(0, $y++, $fg, 0, "gray");
$got .= screencap { tb_present() };

my $expected = do { local $/; <DATA> };
is($got, $expected, 'out matches expected data');

done_testing;

__DATA__
#5[0m[0;38:5:238mc[0;38:5:238my[0;38:5:238ma[0;38:5:238mn[0;38:5:238m [0;38:5:238m([0;38:5:238mt[0;38:5:238mh[0;38:5:238me[0;38:5:238mn[0;38:5:238m [0;38:5:238mg[0;38:5:238mr[0;38:5:238ma[0;38:5:238my[0;38:5:238m [0;38:5:238ma[0;38:5:238mf[0;38:5:238mt[0;38:5:238me[0;38:5:238mr[0;38:5:238m [0;38:5:238mm[0;38:5:238mo[0;38:5:238md[0;38:5:238me[0;38:5:238m [0;38:5:238ms[0;38:5:238mw[0;38:5:238mi[0;38:5:238mt[0;38:5:238mc[0;38:5:238mh[0;38:5:238m [0;38:5:238ma[0;38:5:238mn[0;38:5:238md[0;38:5:238m [0;38:5:238mi[0;38:5:238mn[0;38:5:238mv[0;38:5:238ma[0;38:5:238ml[0;38:5:238mi[0;38:5:238md[0;38:5:238ma[0;38:5:238mt[0;38:5:238me[0;38:5:238m)[0m
#5[0m[0;38:5:238mg[0;38:5:238mr[0;38:5:238ma[0;38:5:238my[0m
