use 5.014;
use warnings;

$SIG{__WARN__} = sub {
  my ($msg) = @_;
  return if defined $msg
    && $msg =~ /isn't numeric in numeric (?:eq|ne) \((?:==|!=)\) at .*?(?:Test2\/API\.pm|Test2\/Hub\.pm|Test\/Builder\.pm) line \d+\.?\n?\z/s;
  warn @_;
};

use Test::More;
use Test::Exception;
use Devel::StrictMode;
use POSIX qw( dup2 getpid :fcntl_h );

if ($^O eq 'MSWin32') {
  plan skip_all => 'Test irrelevant for Windows OS';
} else {
  # POSIX: Check for a real terminal
  my $tty;
  unless (sysopen($tty, "/dev/tty", O_RDWR)) {
    plan skip_all => 'Test requires /dev/tty (not available)';
  }
  unless (-t $tty) {
    plan skip_all => 'Test requires a real TTY (not a pipe, FIFO, or stub)';
  }
}

use_ok 'Termbox::Go::Legacy', qw( :api :return :types );

lives_ok { tb_init() == 0 or die } 'tb_init()';

my ($w, $h) = (0,0);
lives_ok { ($w = tb_width() // -1) >= 0 or die } 'width';
lives_ok { ($h = tb_height() // -1) >= 0 or die } 'height';

subtest 'raise(SIGWINCH)' => sub {
  plan tests => 2;
  lives_ok { while (tb_peek_event(my $ev = tb_event(), 200) == 0) {} }
    'flush event queue';
  lives_ok {
    my ($pid) = (getpid() =~ /(\d+)/);
    kill WINCH => ($pid // 0);
  } 'send myself a SIGWINCH';
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
