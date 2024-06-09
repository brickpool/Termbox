use 5.014;
use warnings;

use Test::More tests => 2;
use Test::Exception;

use_ok 'Termbox::Go::Common', qw( :types );

subtest 'Cell' => sub {
  plan tests => 10;
  my $type;
  lives_ok  { $type = Cell() } 'call empty';
  is_deeply   $type, { Ch => 0, Fg => 0, Bg => 0 }, 'create type';
  lives_ok  { $type = Cell(ord('a'), 1, 0) } 'call params';
  is_deeply   $type, { Ch => ord('a'), Fg => 1, Bg => 0 }, 'create params';
  lives_ok  { $type = Cell({ Ch => ord(' '), Fg => 2, Bg => 1 }) } 'call hash';
  is_deeply   $type, { Ch => ord(' '), Fg => 2, Bg => 1 }, 'cast hash';
  lives_ok  { $type = Cell('a') } 'invalid call';
  is          $type, undef, 'returns undef';
  lives_ok  { $type = Cell([], 1, 2) } 'invalid content';
  is          $type, undef, 'returns undef';
};

done_testing;
