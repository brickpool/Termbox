use strict;
use warnings;

use Test::More;

use Termbox::PP;
use Termbox qw( :api :return :color );

use constant MAX_INT => ~0 >> 1;

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

my $w = tb_width(); 
my $h = tb_height();

# try to set a cell out of bounds
my $err = tb_set_cell(MAX_INT, MAX_INT, 'x', 0, 0);
my $errmsg = tb_strerror($err);

tb_printf(0, 0, 0, 0, "oob err=%d errmsg=%s", $err, $errmsg);

my $got = screencap { tb_present() };

tb_shutdown();

my $expected = do { local $/; <DATA> };

is($got, $expected, 'out matches expected data');

done_testing;

__DATA__
#5[0moob err=-9 errmsg=Out of bounds[0m
