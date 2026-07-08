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

my $y = 0;
tb_print_ex(0, $y++, 0, 0, undef, "foo\xc2\x00password"); # stop at NUL
tb_set_cell(0, $y++, 0xffff, 0, 0); # invalid codepoint

my $got = screencap { tb_present() };
my $expected = do { local $/; <DATA> };
is($got, $expected, 'out matches expected data');

done_testing;

__DATA__
#5[0mfoo#[0m
#5[0m#[0m
