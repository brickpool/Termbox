use strict;
use warnings;
use utf8;

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

plan skip_all => 'This will only work with extended grapheme cluster support'
  if tb_has_egc();

tb_init();

plan skip_all => 'This test requires a usable terminal'
  if tb_width() <= 0 || tb_height() <= 0;

tb_print(0, 0, 0, 0, "STARG\xce\x9b\xcc\x8aTE SG-1");
tb_print(0, 1, 0, 0, "a = v\xcc\x87 = r\xcc\x88, a\xe2\x83\x91 \xe2\x8a\xa5 b\xe2\x83\x91");

my $got = screencap { tb_present() };
my $expected = do { local $/; <DATA> };
is($got, $expected, 'out matches expected data');

done_testing;

__DATA__
#5[0mSTARGΛ̊TE SG-1[0m
#5[0ma = v̇ = r̈, a⃑ ⊥ b⃑[0m
