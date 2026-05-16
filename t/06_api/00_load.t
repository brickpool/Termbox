use 5.014;
use warnings;

use Test::More;

use_ok 'Termbox::Go', qw( :DEFAULT );

diag @Termbox::Go::ISA;

done_testing;
