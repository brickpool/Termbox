use strict;
use warnings;

use Test::More;

use Termbox::PP;
use Termbox qw( :api :return :color );

sub xvkbd {
  my ($xvkbd_cmd) = @_;
  warn "xvkbd $xvkbd_cmd\n";

  local $ENV{DISPLAY} = ':1000';
  my $exit_code = system(
    'xvkbd',
    '-remote-display', ':1000',
    '-window', 'xterm',
    '-text', $xvkbd_cmd,
  );

  return $exit_code == -1 ? 127 : ($exit_code >> 8);
}

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

my $w = tb_width();
my $h = tb_height();

my $bg = TB_BLACK;
my $red = TB_RED;
my $green = TB_GREEN;
my $blue = TB_BLUE;

my $y = 0;
my $version_str = tb_version();
my $has_version = defined($version_str) && length($version_str) > 0;
tb_printf(0, $y++, 0, 0, "has_version=%s", $has_version ? 'y' : 'n');
tb_printf(0, $y++, $red, $bg, "width=%d", $w);
tb_printf(0, $y++, $green, $bg, "height=%d", $h);
for my $attr (qw(TB_BOLD TB_UNDERLINE TB_ITALIC TB_REVERSE TB_BRIGHT TB_DIM)) {
  no strict 'refs';
  tb_printf(0, $y++, $blue | &{$attr}(), $bg, "attr=%s", $attr);
}

xvkbd("\Ca");    # Ctrl-A

my $event = Termbox::Event->new();
my $rv = tb_peek_event($event, 1000);

my $out_w = 0;
tb_printf_ex(0, $y++, $blue, $bg, \$out_w, "event rv=%d type=%d mod=%d key=%d ".
  "ch=%d w=%d h=%d x=%d y=%d",
  $rv,
  $event->type,
  $event->mod,
  $event->key,
  $event->ch,
  $event->w,
  $event->h,
  $event->x,
  $event->y
);

tb_printf(0, $y++, 0, 0, "out_w=%d", $out_w);

my $got = screencap { tb_present() };

tb_shutdown();

my $expected = do { local $/; <DATA> };

is($got, $expected, 'out matches expected data');

done_testing;

__DATA__
#5[0mhas_version=y[0m
#5[0m[0;31;40mw[0;31;40mi[0;31;40md[0;31;40mt[0;31;40mh[0;31;40m=[0;31;40m8[0;31;40m0[0m
#5[0m[0;32;40mh[0;32;40me[0;32;40mi[0;32;40mg[0;32;40mh[0;32;40mt[0;32;40m=[0;32;40m2[0;32;40m4[0m
#5[0m[0;1;34;40ma[0;1;34;40mt[0;1;34;40mt[0;1;34;40mr[0;1;34;40m=[0;1;34;40mT[0;1;34;40mB[0;1;34;40m_[0;1;34;40mB[0;1;34;40mO[0;1;34;40mL[0;1;34;40mD[0m
#5[0m[0;4;34;40ma[0;4;34;40mt[0;4;34;40mt[0;4;34;40mr[0;4;34;40m=[0;4;34;40mT[0;4;34;40mB[0;4;34;40m_[0;4;34;40mU[0;4;34;40mN[0;4;34;40mD[0;4;34;40mE[0;4;34;40mR[0;4;34;40mL[0;4;34;40mI[0;4;34;40mN[0;4;34;40mE[0m
#5[0m[0;3;34;40ma[0;3;34;40mt[0;3;34;40mt[0;3;34;40mr[0;3;34;40m=[0;3;34;40mT[0;3;34;40mB[0;3;34;40m_[0;3;34;40mI[0;3;34;40mT[0;3;34;40mA[0;3;34;40mL[0;3;34;40mI[0;3;34;40mC[0m
#5[0m[0;7;34;40ma[0;7;34;40mt[0;7;34;40mt[0;7;34;40mr[0;7;34;40m=[0;7;34;40mT[0;7;34;40mB[0;7;34;40m_[0;7;34;40mR[0;7;34;40mE[0;7;34;40mV[0;7;34;40mE[0;7;34;40mR[0;7;34;40mS[0;7;34;40mE[0m
#5[0m[0;94;40ma[0;94;40mt[0;94;40mt[0;94;40mr[0;94;40m=[0;94;40mT[0;94;40mB[0;94;40m_[0;94;40mB[0;94;40mR[0;94;40mI[0;94;40mG[0;94;40mH[0;94;40mT[0m
#5[0m[0;2;34;40ma[0;2;34;40mt[0;2;34;40mt[0;2;34;40mr[0;2;34;40m=[0;2;34;40mT[0;2;34;40mB[0;2;34;40m_[0;2;34;40mD[0;2;34;40mI[0;2;34;40mM[0m
#5[0m[0;34;40me[0;34;40mv[0;34;40me[0;34;40mn[0;34;40mt[0;34;40m [0;34;40mr[0;34;40mv[0;34;40m=[0;34;40m0[0;34;40m [0;34;40mt[0;34;40my[0;34;40mp[0;34;40me[0;34;40m=[0;34;40m1[0;34;40m [0;34;40mm[0;34;40mo[0;34;40md[0;34;40m=[0;34;40m2[0;34;40m [0;34;40mk[0;34;40me[0;34;40my[0;34;40m=[0;34;40m1[0;34;40m [0;34;40mc[0;34;40mh[0;34;40m=[0;34;40m0[0;34;40m [0;34;40mw[0;34;40m=[0;34;40m0[0;34;40m [0;34;40mh[0;34;40m=[0;34;40m0[0;34;40m [0;34;40mx[0;34;40m=[0;34;40m0[0;34;40m [0;34;40my[0;34;40m=[0;34;40m0[0m
#5[0mout_w=50[0m
