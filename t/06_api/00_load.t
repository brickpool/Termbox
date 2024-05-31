use 5.014;
use warnings;

use Test::More tests => 1;

use_ok 'Termbox::Go', qw( :DEFAULT );

diag @Termbox::Go::ISA;

done_testing;
