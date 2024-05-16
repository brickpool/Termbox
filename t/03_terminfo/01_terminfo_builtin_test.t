use 5.014;
use warnings;

use Test::More;
use Test::Exception;

use_ok 'Termbox::Go::Terminfo::Builtin', qw( 
  $terms
  t_max_funcs
);
our $terms;

while (my ($name, $term) = each %$terms) {
  lives_ok { 
    scalar(@{ $term->{funcs} }) == t_max_funcs()
      or die sprintf("want %d got %d terminfo entries", t_max_funcs(), scalar(@{ $term->{funcs} }))
  } "$name"
}

done_testing;
