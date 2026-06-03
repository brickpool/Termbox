use 5.010;
use strict;
use warnings;

use Test::More;

BEGIN {
  require_ok 'Termbox::PP';
  use_ok 'Termbox', qw( :api :func :event :color );
}

ok exists(&tb_set_func),              ':api';
ok exists(&tb_cell_buffer),           ':api';
ok exists(&TB_FUNC_EXTRACT_PRE),      ':func';
ok exists(&TB_FUNC_EXTRACT_POST),     ':func';
if (Termbox::TB_OPT_ATTR_W == 16) {
  ok exists(&TB_256_BLACK),           ':color';
} else {
  ok exists(&TB_TRUECOLOR_BOLD),      ':color';
  ok exists(&TB_TRUECOLOR_UNDERLINE), ':color';
  ok exists(&TB_TRUECOLOR_REVERSE),   ':color';
  ok exists(&TB_TRUECOLOR_ITALIC),    ':color';
  ok exists(&TB_TRUECOLOR_BLINK),     ':color';
  ok exists(&TB_TRUECOLOR_BLACK),     ':color';
}
ok exists(&Termbox::TB_OPT_TRUECOLOR), 'TB_OPT_TRUECOLOR';

done_testing;
