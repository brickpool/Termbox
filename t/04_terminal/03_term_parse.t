use 5.014;
use warnings;

use Test::More tests => 11;
use Test::Exception;

use_ok 'Termbox::Go::Common', qw(
  :keys
  :mode
  :event
  :types
  :vars
);
use_ok 'Termbox::Go::Terminfo::Builtin', qw( $xterm_keys );
use_ok 'Termbox::Go::Terminal::Backend', qw( :func );

our $keys = [ @{ our $xterm_keys } ];

my $event = Event();
my $expected = Event({Type => EventMouse()});
lives_ok(
  sub {
    (parse_mouse_event($event, "\x1b[MC\x95("))[1] or die;
  }, 'UTF-8 (1005)'
);
@$expected{qw(Mod MouseX MouseY Key)}
  = (0, 148, 39, MouseRelease());
is_deeply $event, $expected, '148x39';

lives_ok( 
  sub { 
    (parse_mouse_event($event, "\033[<35;110;11M"))[1] or die;
  }, 'SGR (1006)'
);
@$expected{qw(Mod MouseX MouseY Key)}
  = (ModMotion(), 109, 10, MouseRelease());
is_deeply $event, $expected, '109x10';

lives_ok( 
  sub { 
    (parse_mouse_event($event, "\033[97;14;10M"))[1] or die;
  }, 'URXVT (1015)'
);
@$expected{qw(Mod MouseX MouseY Key)}
  = (ModMotion(), 13, 9, MouseWheelDown());
is_deeply $event, $expected, '13x9';

$event = Event();
$expected = Event({Key => KeyArrowLeft()});
lives_ok(
  sub {
    (parse_escape_sequence($event, \"\x1bOD"))[1] or die 
  }, 'parse_escape_sequence'
);
is_deeply $event, $expected, 'KeyArrowLeft';

done_testing;
