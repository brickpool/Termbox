use 5.014;
use warnings;

use Test::More;
use Test::Exception;
use Devel::StrictMode;
use POSIX qw( dup2 );

if ($^O eq 'MSWin32') {
  plan skip_all => 'Test irrelevant for Windows OS';
}
else {
  plan tests => 9;
}

dup2(fileno(STDERR), fileno(STDOUT));
$| = 1;

use_ok 'Termbox::Go::Legacy', qw( :api :return :types );

lives_ok { tb_init() == 0 or die } 'tb_init()';

my ($w, $h) = (0,0);
lives_ok { ($w = tb_width() // -1) >= 0 or die } 'width';
lives_ok { ($h = tb_height() // -1) >= 0 or die } 'height';

subtest 'raise(SIGWINCH)' => sub {
  plan tests => 2;
  lives_ok { while (tb_peek_event(my $ev = tb_event(), 200) == 0) {} }
    'flush event queue';
  lives_ok { kill WINCH => $$ } 'send myself a SIGWINCH';
};

my $event = tb_event();
my $rv = 0;
lives_ok { ($rv = tb_peek_event($event, 1000)) == 0 or die } 'tb_peek_event()';
lives_ok { tb_printf(0, 0, 0, 0, "event rv=%d type=%d ow=%d oh=%d w=%d h=%d",
    $rv,
    $event->{type},
    $w,
    $h,
    $event->{w},
    $event->{h},
  ) == 0 or die;
} 'tb_printf()';

lives_ok { tb_present() == 0 or die } 'tb_present()';
sleep(0+STRICT);

lives_ok { tb_shutdown() == 0 or die } 'tb_shutdown()';

done_testing;
