use 5.014;
use warnings;

use Test::More;
use Test::Exception;
use Devel::StrictMode;
use POSIX qw( dup2 );

if ($^O eq 'MSWin32') {
  my $fd = fileno(\*STDERR);
  my $has_console = !$ENV{AUTOMATED_TESTING} && defined $fd && $fd >= 0;
  if (!$has_console) {
    plan skip_all => 'Test requires a valid console (not available)';
  }
} else {
  my $has_tty = !$ENV{AUTOMATED_TESTING} && -w '/dev/tty';
  if (!$has_tty) {
    plan skip_all => 'Test requires a TTY device (not available)';
  }
}

dup2(fileno(STDERR), fileno(STDOUT));
$| = 1;

use_ok 'Termbox::Go::Legacy', qw( :api :color :attr :types );

lives_ok { tb_init() == 0 or die } 'tb_init()';

my ($w, $h);
lives_ok { ($w = tb_width() // -1) >= 0 or die } 'width';
lives_ok { ($h = tb_height() // -1) >= 0 or die } 'height';

my $bg = TB_BLACK();
my $red = TB_RED();
my $green = TB_GREEN();
my $blue = TB_BLUE();
ok $bg && $red && $green && $blue, ':color';

my $y = 0;
my $version_str;
lives_ok { $version_str = tb_version() } 'tb_version()';
my $has_version = defined($version_str) && length($version_str) > 0;
subtest 'tb_printf()' => sub {
  plan tests => 4;
  lives_ok { tb_printf(0, $y++, 0, 0, "has_version=%s", $has_version ? 'y' : 'n') == 0 or die };
  lives_ok { tb_printf(0, $y++, $red, $bg, "width=%d", $w) == 0 or die };
  lives_ok { tb_printf(0, $y++, $green, $bg, "height=%d", $h) == 0 or die };
  lives_ok { no strict 'refs';
    foreach my $attr (qw(TB_BOLD TB_UNDERLINE TB_ITALIC TB_REVERSE TB_BLINK TB_DIM)) {
      tb_printf(0, $y++, $blue | &$attr(), $bg, "attr=%s", $attr) == 0 or die;
      do { tb_present() == 0 or die } if STRICT;
      sleep(0+STRICT);
    }
  };
};

my $event = tb_event();
my $rv = 0;
lives_ok { $rv = tb_peek_event($event, 1000) } 'tb_peek_event()';

lives_ok { tb_printf(0, $y++, $blue, $bg, "event rv=%d %s", $rv, "@{[%$event]}") == 0 or die };

lives_ok { tb_present() == 0 or die } 'tb_present()';
sleep(0+STRICT);

lives_ok { tb_shutdown() == 0 or die } 'tb_shutdown()';

done_testing;
