use 5.014;
use warnings;

use Test::More tests => 25;
use Test::Exception;
use POSIX qw( dup2 );

# Alchemical symbol "Fire"
# https://en.wikipedia.org/wiki/List_of_Unicode_characters#Alchemical_symbols
# https://en.wikipedia.org/wiki/Fire_(classical_element)
my $ch = "\x{1f702}";
dup2(fileno(STDERR), fileno(STDOUT));
$| = 1;

use_ok 'Termbox::Go::Legacy', qw( TB_VERSION_STR :api :types );

lives_ok  { length(TB_VERSION_STR())      >= 0 or die } 'TB_VERSION_STR()';

lives_ok  { tb_init()                     == 0 or die } 'tb_init()';
throws_ok { tb_set_cursor()               == 0 or die } qr/argument/i, 'croak';
lives_ok  { (tb_width() // -1)            >= 0 or die } 'tb_width()';
lives_ok  { (tb_height() // -1)           >= 0 or die } 'tb_height()';
lives_ok  { tb_print(0,0,0,0,'ok')        == 0 or die } 'tb_print()';
lives_ok  { tb_hide_cursor()              == 0 or die } 'tb_hide_cursor()';
lives_ok  { tb_set_cursor(0,0)            == 0 or die } 'tb_set_cursor()';
lives_ok  { tb_set_cell(0,0,ord('@'),0,0) == 0 or die } 'tb_set_cell()';
lives_ok  { tb_set_input_mode(0)          >= 0 or die } 'tb_set_input_mode()';
lives_ok  { tb_set_output_mode(0)         >= 0 or die } 'tb_set_output_mode()';
lives_ok  { tb_peek_event(tb_event(), 200)       } 'tb_peek_event()';
lives_ok  { tb_printf(0,0,0,0,'%d',0)     == 0 or die } 'tb_printf()';
lives_ok  { @{ tb_cell_buffer() }          > 0 or die } 'tb_cell_buffer()';
lives_ok  { tb_clear()                    == 0 or die } 'tb_clear()';
lives_ok  { tb_invalidate()               == 0 or die } 'tb_invalidate()';
lives_ok  { tb_present()                  == 0 or die } 'tb_present()';
lives_ok  { tb_shutdown()                 == 0 or die } 'tb_shutdown()';

lives_ok  { tb_utf8_char_length($ch)      == 4 or die } 'tb_utf8_char_length()';
lives_ok  { tb_utf8_char_to_unicode(\$_, $ch) > 0 or die }
  'tb_utf8_char_to_unicode()';
lives_ok  { tb_utf8_unicode_to_char(\$_, ord($ch)) > 0 or die }
  'tb_utf8_unicode_to_char()';
lives_ok  { tb_last_errno()                > 0 or die } 'tb_last_errno()';
lives_ok  { length(tb_strerror(0))        >= 0 or die } 'tb_strerror()';
lives_ok  { length(tb_version())          >= 0 or die } 'tb_version()';

done_testing;
