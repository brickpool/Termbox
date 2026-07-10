use strict;
use warnings;

use Test::More;

use Termbox::PP;
use Termbox qw( :api :color );

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

tb_init();

my $w = tb_width(); 
my $h = tb_height();

plan skip_all => 'This test requires a usable terminal'
  if $w <= 0 || $h <= 0;

# try to set a cell out of bounds
my $err = tb_set_cell(MAX_INT, MAX_INT, 'x', 0, 0);
my $errmsg = tb_strerror($err);

tb_printf(0, 0, 0, 0, "oob err=%d errmsg=%s", $err, $errmsg);

my $got = screencap { tb_present() };
my $expected = do { local $/; <DATA> };
is($got, $expected, 'out matches expected data');

done_testing;

__DATA__
#5[0moob err=-9 errmsg=Out of bounds[0m