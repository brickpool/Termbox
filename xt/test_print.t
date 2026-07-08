use strict;
use warnings;

use Test::More;

use Termbox::PP;
use Termbox qw( :api );

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

my $w = tb_width();
my $h = tb_height();

plan skip_all => 'This test requires a usable terminal'
  if $w <= 0 || $h <= 0;

my $y = 0;
tb_print(1, $y++, 0, 0, "line1\nline2\nline3");
$y += 2;

tb_print(0, $y++, 0, 0, "escape=[\x1b]");
tb_print(0, $y++, 0, 0, "tab=[\t]");

my $oob_rv1 = tb_print($w, $h, 0, 0, "oob1");
my $oob_rv2 = tb_print(-1, -1, 0, 0, "oob2");
tb_printf(0, $y++, 0, 0, "oob_rv1=%d", $oob_rv1);
tb_printf(0, $y++, 0, 0, "oob_rv2=%d", $oob_rv2);

tb_print($w - 5, $h - 5, 0, 0, str_repeat("0123456789\n", 10));

my $got = screencap { tb_present() };
my $expected = do { local $/; <DATA> };
is($got, $expected, 'out matches expected data');

done_testing;

__DATA__
#5[0m line1[0m
#5[0m line2[0m
#5[0m line3[0m
#5[0mescape=[#][0m
#5[0mtab=[#][0m
#5[0moob_rv1=-9[0m
#5[0moob_rv2=-9[0m












#5[0m                                                                           01234[0m
#5[0m                                                                           01234[0m
#5[0m                                                                           01234[0m
#5[0m                                                                           01234[0m
#5[0m                                                                           01234[0m
