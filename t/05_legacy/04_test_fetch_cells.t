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

use_ok 'Termbox::Go::Legacy', qw( :api :color :return :types );

lives_ok { tb_init() == TB_OK() or die $! } 'tb_init()';
lives_ok { tb_set_cell(0, 0, ord('@'), TB_WHITE(), TB_BLUE()) } 'tb_set_cell()';

my $cells;
lives_ok { $cells = tb_cell_buffer() } 'tb_cell_puffer()';

subtest 'FETCH()' => sub {
  plan tests => 3;
  lives_ok { $cells->[0]->{ch} == ord('@')    or die $! } 'ch';
  lives_ok { $cells->[0]->{fg} == TB_WHITE()  or die $! } 'fg';
  lives_ok { $cells->[0]->{bg} == TB_BLUE()   or die $! } 'bg';
};
if (STRICT) {
  my $cell = $cells->[0];
  diag "Cells: @{[%$cell]}";
}

dies_ok { $cells->[0] = tb_cell() } '!STORE()';
lives_ok { 0+@$cells >= 0 or die $! } 'FETCHSIZE()';

lives_ok { tb_shutdown() == TB_OK() or die $! } 'tb_shutdown()';

done_testing;
