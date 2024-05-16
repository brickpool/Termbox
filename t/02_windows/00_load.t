use 5.014;
use warnings;

use Test::More tests => 2;

plan skip_all => "Windows OS required for testing" unless $^O eq 'MSWin32';

use_ok 'Termbox::Go::Win32::Backend';
use_ok 'Termbox::Go::Win32';

done_testing;
