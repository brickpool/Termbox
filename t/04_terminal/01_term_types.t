use 5.014;
use warnings;

use Test::More tests => 4;
use Test::Exception;

use_ok 'Termbox::Go::Terminal::Backend', qw( :types );

subtest 'input_event' => sub {
  plan tests => 10;
  my $type;
  lives_ok  { $type = input_event() } 'call empty';
  is_deeply   $type, { data => '', err => 0 }, 'create type';
  lives_ok  { $type = input_event('a', 1) } 'call params';
  is_deeply   $type, { data => 'a', err => 1 }, 'create params';
  lives_ok  { $type = input_event({ data => '', err => 2 }) } 'call hash';
  is_deeply   $type, { data => '', err => 2 }, 'cast hash';
  lives_ok  { $type = input_event('a') } 'invalid call';
  is          $type, undef, 'returns undef';
  lives_ok  { $type = input_event([], 1) } 'invalid content';
  is          $type, undef, 'returns undef';
};

subtest 'winsize' => sub {
  plan tests => 10;
  my $type;
  lives_ok  { $type = winsize() } 'call empty';
  is_deeply   $type, { rows=>0, cols=>0, xpixels=>0, ypixels=>0 }, 
    'create type';
  lives_ok  { $type = winsize(0, 1, 2, 3) } 'call params';
  is_deeply   $type, { rows=>0, cols=>1, xpixels=>2, ypixels=>3 }, 
    'create params';
  lives_ok  { $type = winsize({ rows=>1, cols=>2, xpixels=>3, ypixels=>4 }) } 
    'call hash';
  is_deeply   $type, { rows=>1, cols=>2, xpixels=>3, ypixels=>4 }, 'cast hash';
  lives_ok  { $type = winsize(0) } 'invalid call';
  is          $type, undef, 'returns undef';
  lives_ok  { $type = winsize('', 1, 2, 3) } 'invalid content';
  is          $type, undef, 'returns undef';
};

subtest 'syscall_Termios' => sub {
  plan tests => 10;
  my $type;
  lives_ok  { $type = syscall_Termios() } 'call empty';
  is_deeply   $type, { Iflag=>0, Oflag=>0, Cflag=>0, Lflag=>0, Cc=>[], 
    Ispeed=>0, Ospeed=>0 }, 'create type';
  lives_ok  { $type = syscall_Termios(0, 1, 2, 3, [], 4, 5) } 'call params';
  is_deeply   $type, { Iflag=>0, Oflag=>1, Cflag=>2, Lflag=>3, Cc=>[], 
    Ispeed=>4, Ospeed=>5 }, 'create params';
  lives_ok  { $type = syscall_Termios({ Iflag=>1, Oflag=>2, Cflag=>3, 
    Lflag=>4, Cc=>[], Ispeed=>5, Ospeed=>6 }) } 'call hash';
  is_deeply   $type, { Iflag=>1, Oflag=>2, Cflag=>3, 
    Lflag=>4, Cc=>[], Ispeed=>5, Ospeed=>6 }, 'cast hash';
  lives_ok  { $type = syscall_Termios(0) } 'invalid call';
  is          $type, undef, 'returns undef';
  lives_ok  { $type = syscall_Termios(0, 1, 2, 3, {}, 4, 5) } 
    'invalid content';
  is          $type, undef, 'returns undef';
};

done_testing;
