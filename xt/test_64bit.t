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

plan skip_all => 'This test requires 64-bit attrs'
  if tb_attr_width() != 64;

tb_init();

plan skip_all => 'This test requires a usable terminal'
  if tb_width() <= 0 || tb_height() <= 0;

my @attrs = (
  'TB_STRIKEOUT',
  # 'TB_OVERLINE', # Not supported by xterm
  'TB_INVISIBLE',
  'TB_UNDERLINE_2',
);

my $y = 0;
foreach my $attr (@attrs) {
  no strict 'refs';
  tb_printf(0, $y++, &{$attr}(), 0, 'attr=%s', $attr);
}

my $got = screencap { tb_present() };
my $expected = do { local $/; <DATA> };
is($got, $expected, 'out matches expected data');

done_testing;

__DATA__
#5[0m[0;9ma[0;9mt[0;9mt[0;9mr[0;9m=[0;9mT[0;9mB[0;9m_[0;9mS[0;9mT[0;9mR[0;9mI[0;9mK[0;9mE[0;9mO[0;9mU[0;9mT[0m
#5[0m[0;8ma[0;8mt[0;8mt[0;8mr[0;8m=[0;8mT[0;8mB[0;8m_[0;8mI[0;8mN[0;8mV[0;8mI[0;8mS[0;8mI[0;8mB[0;8mL[0;8mE[0m
#5[0m[0;21ma[0;21mt[0;21mt[0;21mr[0;21m=[0;21mT[0;21mB[0;21m_[0;21mU[0;21mN[0;21mD[0;21mE[0;21mR[0;21mL[0;21mI[0;21mN[0;21mE[0;21m_[0;21m2[0m
