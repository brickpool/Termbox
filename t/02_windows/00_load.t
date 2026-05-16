use 5.014;
use warnings;

use Test::More;

if ($^O ne 'MSWin32') {
  plan skip_all => 'Windows OS required for testing';
}

use_ok 'Termbox::Go::Win32::Backend';
use_ok 'Termbox::Go::Win32';

done_testing;
