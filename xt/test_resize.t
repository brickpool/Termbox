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

tb_init();

my $w = tb_width();
my $h = tb_height();

plan skip_all => 'This test requires a usable terminal'
  if $w <= 0 || $h <= 0;

kill('WINCH', $$);

my $event = Termbox::Event->new();
my $rv = tb_peek_event($event, 1000);

tb_printf(0, 0, 0, 0, "event rv=%d type=%d ow=%d oh=%d w=%d h=%d",
  $rv,
  $event->type,
  $w,
  $h,
  $event->w,
  $event->h,
);

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
