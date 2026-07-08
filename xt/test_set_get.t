use strict;
use warnings;

use Test::More;

use Termbox::PP;
use Termbox qw( :api :color );

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

my $green = TB_GREEN;
my $cellp = Termbox::Cell->new();
my $back = 1;
my $front = 0;

my %result = ();

$result{set} = tb_set_cell(0, 0, ord('a'), $green, 0); # 0 (TB_OK)

$result{invalid_get} = tb_get_cell(-1, -1, $back, \$cellp); # -9 (TB_ERR_OUT_OF_BOUNDS)

$result{back_get} = tb_get_cell(0, 0, $back, \$cellp); # 0 (TB_OK)
$result{back_ch} = chr($cellp->ch); # 'a'
$result{back_fg} = $cellp->fg; # 3 (green)
$result{back_bg} = $cellp->bg; # 0

$result{front1_get} = tb_get_cell(0, 0, $front, \$cellp);
$result{front1_ch} = chr($cellp->ch); # <space> (front buffer empty)
$result{front1_fg} = $cellp->fg; # 0
$result{front1_bg} = $cellp->bg; # 0

$result{present} = tb_present(); # 0 (TB_OK) (front buffer now populated)

$result{front2_get} = tb_get_cell(0, 0, $front, \$cellp); # 0 (TB_OK)
$result{front2_ch} = chr($cellp->ch); # 'a'
$result{front2_fg} = $cellp->fg; # 3 (green)
$result{front2_bg} = $cellp->bg; # 0

my $y = 1;
foreach my $k (qw(
  set invalid_get 
  back_get   back_ch   back_fg   back_bg 
  front1_get front1_ch front1_fg front1_bg
  present 
  front2_get front2_ch front2_fg front2_bg
)) {
  my $v = $result{$k};
  tb_printf(0, $y++, 0, 0, '%s=%s', $k, "$v");
}

my $got = screencap { tb_present() };
my $expected = do { local $/; <DATA> };
is($got, $expected, 'out matches expected data');

done_testing;

__DATA__
#5[0m[0;32ma[0m
#5[0mset=0[0m
#5[0minvalid_get=-9[0m
#5[0mback_get=0[0m
#5[0mback_ch=a[0m
#5[0mback_fg=3[0m
#5[0mback_bg=0[0m
#5[0mfront1_get=0[0m
#5[0mfront1_ch=[0m
#5[0mfront1_fg=0[0m
#5[0mfront1_bg=0[0m
#5[0mpresent=0[0m
#5[0mfront2_get=0[0m
#5[0mfront2_ch=a[0m
#5[0mfront2_fg=3[0m
#5[0mfront2_bg=0[0m
