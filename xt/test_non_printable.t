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

plan skip_all => 'This test requires a usable terminal'
  if tb_width() <= 0 || tb_height() <= 0;

my @codepoints = (
    0x00, # NULL
    0x01, # control code
    0x08, # backspace
    0x09, # tab
    0x0a, # newline
    0x1f, # control code
    0x7f, # delete
);

my $y = 0;
foreach my $ch (@codepoints) {
  tb_printf(0, $y, 0, 0, "0x%02x", $ch);
  tb_set_cell(5, $y, 0, 0, chr $ch, 0, 0);
  $y += 1;
}

my $got = screencap { tb_present() };
my $expected = do { local $/; <DATA> };
is($got, $expected, 'out matches expected data');

done_testing;

__DATA__
#5[0m0x00 #[0m
#5[0m0x01 #[0m
#5[0m0x08 #[0m
#5[0m0x09 #[0m
#5[0m0x0a #[0m
#5[0m0x1f #[0m
#5[0m0x7f #[0m
