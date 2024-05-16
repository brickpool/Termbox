use 5.014;
use warnings;

use Test::More tests => 2;

use_ok 'Termbox::Go::Legacy';
use_ok 'Termbox::Go', qw( TB_IMPL );

done_testing;
