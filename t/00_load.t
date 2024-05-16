use 5.014;
use warnings;

use Test::More tests => 7;

use_ok 'Termbox::Go::Common';
use_ok 'Termbox::Go::WCWidth::Tables';
use_ok 'Termbox::Go::WCWidth';
use_ok 'Termbox::Go::Win32::Backend';
use_ok 'Termbox::Go::Win32';
use_ok 'Termbox::Go::Legacy';
use_ok 'Termbox::Go', qw( :DEFAULT );

done_testing;
