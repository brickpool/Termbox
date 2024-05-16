use 5.014;
use warnings;

use Test::More tests => 9;
use Test::Exception;
use Devel::StrictMode;
use POSIX qw( dup2 );

dup2(fileno(STDERR), fileno(STDOUT));
$| = 1;

use_ok 'Termbox::Go::Legacy', qw( :api :return :types );

lives_ok { tb_init() == 0 or die } 'tb_init()';

my ($w, $h) = (0,0);
lives_ok { ($w = tb_width() // -1) >= 0 or die } 'width';
lives_ok { ($h = tb_height() // -1) >= 0 or die } 'height';

subtest 'raise(SIGWINCH)' => sub {
  plan tests => 2;
  lives_ok(
    sub {
      while (tb_peek_event(my $ev = tb_event(), 200) == 0) {}
    },
    'flush event queue'
  );
  lives_ok( 
    sub {
      if ($^O eq 'MSWin32') {
        no warnings 'once';
        require Termbox::Go::Common;
        my $hConsoleOutput = $Termbox::Go::Common::out;
        require Termbox::Go::Win32;
        my ($size) = Termbox::Go::Win32::get_term_size($hConsoleOutput);
        Termbox::Go::Win32::fix_win_size($hConsoleOutput, $size);
      } else {
        kill WINCH => $$;
      }
    },
    'send myself a SIGWINCH'
  );
};

my $event = tb_event();
my $rv = 0;
TODO: {
  local $TODO = 'Windows has no SIGWINCH' if $^O eq 'MSWin32';
  lives_ok { ($rv = tb_peek_event($event, 1000)) == 0 or die } 'tb_peek_event()';
}
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
