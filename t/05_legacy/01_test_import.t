use 5.014;
use warnings;

use Test::More tests => 12;

use_ok 'Termbox::Go', qw( TB_IMPL );

ok exists(&tb_init),            ':api';
ok exists(&TB_VERSION_STR),     ':const';
ok exists(&TB_KEY_CTRL_TILDE),  ':keys';
ok exists(&TB_DEFAULT),         ':color';
ok exists(&TB_BOLD),            ':attr';
ok exists(&TB_EVENT_KEY),       ':event';
ok exists(&TB_MOD_ALT),         ':mode';
ok exists(&TB_INPUT_CURRENT),   ':input';
ok exists(&TB_OUTPUT_CURRENT),  ':output';
ok exists(&tb_cells),           ':types';
ok exists(&TB_OK),              ':return';

done_testing;
