use 5.014;
use warnings;

use Test::More tests => 3;
use Test::Exception;

#plan skip_all => "Windows OS not supported" if $^O eq 'MSWin32';

use_ok 'Termbox::Go::Terminal', qw( :api );

sub termbox::DebugHandler { # void ($fmt, @args)
  my ($fmt, @args) = @_;
  if ($^O eq 'MSWin32') {
    require Win32;
    Win32::OutputDebugString(sprintf($fmt, @args));
  } else {
    STDERR->printf($fmt, @args);
  }
  return;
}

lives_ok  { Init() == 0 or die $! } 'Init()';
lives_ok  { Close() == 0 or die $! } 'Close()';

done_testing;
