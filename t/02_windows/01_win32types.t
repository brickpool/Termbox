use 5.014;
use warnings;

use Test::More;
use Test::Exception;

if ($^O ne 'MSWin32') {
  plan skip_all => 'Windows OS required for testing';
}
else {
  plan tests => 7;
}

use Devel::StrictMode;

use_ok 'Termbox::Go::Win32::Backend', qw( :types );

subtest 'syscallHandle' => sub {
  plan tests => 8;
  my $type;
  lives_ok  { $type = syscallHandle() } 'call empty';
  is          $type, 0, 'create empty';
  lives_ok  { $type = syscallHandle(1) } 'call param';
  is          $type, 1, 'validate param';
  lives_ok  { $type = syscallHandle(1, 2) } 'invalid call';
  is          $type, undef, 'returns undef';
  lives_ok  { $type = syscallHandle('a') } 'invalid content';
  is          $type, undef, 'returns undef';
};

subtest 'char_info' => sub {
  my $type;
  lives_ok  { $type = char_info() } 'call empty';
  is_deeply   $type, { char => 0, attr => 0 }, 'create empty';
  lives_ok  { $type = char_info(0, 1) } 'call params';
  is_deeply   $type, { char => 0, attr => 1 }, 'create params';
  lives_ok  { $type = char_info({ char => 1, attr => 2 }) } 'call hash';
  is_deeply   $type, { char => 1, attr => 2 }, 'cast hash';
  SKIP: {
    skip 'strict mode not enabled', 2 unless STRICT;
    lives_ok  { $type = char_info(0) } 'invalid call';
    is          $type, undef, 'returns undef';
    lives_ok  { $type = char_info([], 1) } 'invalid content';
    is          $type, undef, 'returns undef';
  }
};

subtest 'coord' => sub {
  my $type;
  lives_ok  { $type = coord() } 'call empty';
  is_deeply   $type, { x => 0, y => 0 }, 'create empty';
  lives_ok  { $type = coord(0, 1) } 'call params';
  is_deeply   $type, { x => 0, y => 1 }, 'create params';
  lives_ok  { $type = coord({ x => 1, y => 2 }) } 'call hash';
  is_deeply   $type, { x => 1, y => 2 }, 'cast hash';
  SKIP: {
    skip 'strict mode not enabled', 2 unless STRICT;
    lives_ok  { $type = coord(0) } 'invalid call';
    is          $type, undef, 'returns undef';
    lives_ok  { $type = coord([], 1) } 'invalid content';
    is          $type, undef, 'returns undef';
  }
};

subtest 'small_rect' => sub {
  my $type;
  lives_ok  { $type = small_rect() } 'call empty';
  is_deeply   $type, { left=>0, top=>0, right=>0, bottom=>0 }, 'create empty';
  lives_ok  { $type = small_rect(0, 1, 2, 3) } 'call params';
  is_deeply   $type, { left=>0, top=>1, right=>2, bottom=>3 }, 'create params';
  lives_ok  { $type = small_rect({ left=>1, top=>2, right=>3, bottom=>4 }) } 'call hash';
  is_deeply   $type, { left=>1, top=>2, right=>3, bottom=>4 }, 'cast hash';
  SKIP: {
    skip 'strict mode not enabled', 2 unless STRICT;
    lives_ok  { $type = small_rect(0) } 'invalid call';
    is          $type, undef, 'returns undef';
    lives_ok  { $type = small_rect('', 1, 2, 3) } 'invalid content';
    is          $type, undef, 'returns undef';
  }
};

subtest 'console_cursor_info' => sub {
  plan tests => 10;
  my $type;
  lives_ok  { $type = console_cursor_info() } 'call empty';
  is_deeply   $type, { size => 0, visible => 0 }, 'create empty';
  lives_ok  { $type = console_cursor_info(1, 0) } 'call params';
  is_deeply   $type, { size => 1, visible => 0 }, 'create params';
  lives_ok  { $type = console_cursor_info({ size => 3, visible => 1 }) } 'call hash';
  is_deeply   $type, { size => 3, visible => 1 }, 'cast hash';
  lives_ok  { $type = console_cursor_info(0) } 'invalid call';
  is          $type, undef, 'returns undef';
  lives_ok  { $type = console_cursor_info(0, !!0) } 'invalid content';
  is          $type, undef, 'returns undef';
};

subtest 'diff_msg' => sub {
  plan tests => 10;
  my $type;
  lives_ok  { $type = diff_msg() } 'call empty';
  is_deeply   $type, { pos => 0, lines => 0, chars => [] }, 'create type';
  lives_ok  { $type = diff_msg(0, 1, [2]) } 'call params';
  is_deeply   $type, { pos => 0, lines => 1, chars => [2] }, 'create params';
  lives_ok  { $type = diff_msg({ pos => 1, lines => 2, chars => [0,1] }) } 'call hash';
  is_deeply   $type, { pos => 1, lines => 2, chars => [0,1] }, 'cast hash';
  lives_ok  { $type = diff_msg(0) } 'invalid call';
  is          $type, undef, 'returns undef';
  lives_ok  { $type = diff_msg(\0, 1, []) } 'invalid content';
  is          $type, undef, 'returns undef';
};

done_testing;
