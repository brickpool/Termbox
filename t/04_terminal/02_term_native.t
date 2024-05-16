use 5.014;
use warnings;

use Test::More tests => 18;
use Test::Exception;

use_ok 'Termbox::Go::Common', qw(
  :keys
  :mode
  :color
  :event
  :types
  :vars
);
use_ok 'Termbox::Go::Terminal::Backend', qw( 
  :func
  :types
  :vars
);

our $out = \*STDERR;
our $outfd = fileno($out);
our $back_buffer; $back_buffer->init(1,1);
our $front_buffer; $front_buffer->init(1,1);
my $sequence = "\x1b[MC\x95(";
our $inbuf = 'abc';

lives_ok { write_cursor(0, 0) } 'write_cursor';
lives_ok { write_sgr_fg(ColorYellow()) } 'write_sgr_fg';
lives_ok { write_sgr_bg(ColorBlue()) } 'write_sgr_bg';
lives_ok { write_sgr(ColorWhite(), ColorBlack()) } 'write_sgr';
lives_ok { get_term_size($outfd) // die $! } 'get_term_size';
lives_ok { send_attr(0, 0) } 'send_attr';
lives_ok { send_char(0, 0, 'a') } 'send_char';
lives_ok { flush() or die $! } 'flush';
lives_ok { send_clear() or die $! } 'send_clear';
lives_ok { update_size_maybe() or die $! } 'update_size_maybe';
SKIP: {
  skip "not implemented on Windows OS", 2 if $^O eq 'MSWin32';
  my $termios = syscall_Termios();
  lives_ok { tcgetattr($outfd, $termios) or die $! } 'tcgetattr';
  lives_ok { tcsetattr($outfd, $termios) or die $! } 'tcsetattr';
}
lives_ok { (parse_mouse_event(my $event = {}, $sequence))[1] or die }
  'parse_mouse_event';
lives_ok { (parse_escape_sequence(my $event = {}, \$sequence))[1] or die }
  'parse_escape_sequence';
lives_ok { extract_raw_event(\(my $data = '1'), my $event = {}) or die }
  'extract_raw_event';
lives_ok { extract_event(\(my $data = ''), my $event = {}, !!1) }
  'extract_event';

done_testing;
