use 5.014;
use warnings;

use Test::More tests => 7;
use Test::Exception;
use Devel::StrictMode;
use POSIX qw( dup2 );

dup2(fileno(STDERR), fileno(STDOUT));
$| = 1;

use_ok 'Termbox::Go::Legacy', qw( :api :return :types );

lives_ok { tb_init() == TB_OK() or die $! } 'tb_init()';

my ($ev, $rv) = (tb_event(), TB_ERR());
lives_ok(
  sub {
    while (tb_peek_event(local $_ = tb_event(), 200) == TB_OK()) {
      $rv = TB_OK();
      $ev = $_;
    } 
  }, 'tb_peek_event(), try receive an event'
);
SKIP: {
  skip ".. no event received", 1 unless $rv == TB_OK();
  is $rv, TB_OK(), "TB_OK";
}
diag "Last event: @{[%$ev]}" if STRICT;

lives_ok( 
  sub { 
    $rv = tb_peek_event($ev, 200)
  }, 'tb_peek_event(), try to reach timeout'
);
SKIP: {
  skip ".. received an event", 1 if $rv == TB_OK();
  is $rv, TB_ERR_NO_EVENT(), "TB_ERR_NO_EVENT";
}
diag "Event: @{[%$ev]}" if STRICT;

lives_ok { tb_shutdown() == TB_OK() or die $! } 'tb_shutdown()';

done_testing;
