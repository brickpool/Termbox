use 5.010;
use strict;
use warnings;

use Test::More;

BEGIN {
  require_ok 'Termbox::PP';
  use_ok 'Termbox', qw( :api :return );
}

# Mock all internal helpers used by tb_init_rwfd
no warnings 'redefine';
local *Termbox::tb_reset               = sub { };
local *Termbox::init_term_attrs        = sub { TB_OK };
local *Termbox::init_term_caps         = sub { TB_OK };
local *Termbox::init_cap_trie          = sub { TB_OK };
local *Termbox::init_resize_handler    = sub { TB_OK };
local *Termbox::send_init_escape_codes = sub { TB_OK };
local *Termbox::send_clear             = sub { TB_OK };
local *Termbox::update_term_size       = sub { TB_OK };
local *Termbox::init_cellbuf           = sub { TB_OK };
local *Termbox::tb_deinit = sub { $Termbox::global->{initialized} = 0 };

# POSIX helpers
local *POSIX::isatty = sub { 1 };

# ----------------------------------------------
note 'tb_init_rwfd / tb_init_fd / tb_init_file';
# ----------------------------------------------

subtest 'tb_init_rwfd success path' => sub {
  plan tests => 5;

  local $Termbox::global->{initialized} = 0;

  is(
    tb_init_rwfd(10, 11),
    TB_OK,
    'tb_init_rwfd returns TB_OK'
  );

  ok($Termbox::global->{initialized}, 'global initialized set');
  is($Termbox::global->{rfd}, 10, 'rfd stored');
  is($Termbox::global->{wfd}, 11, 'wfd stored');
  is($Termbox::global->{ttyfd}, 10, 'ttyfd resolved via isatty');
};

subtest 'tb_init_fd delegates to tb_init_rwfd' => sub {
  plan tests => 2;

  local $Termbox::global->{initialized} = 0;

  is(
    tb_init_fd(7),
    TB_OK,
    'tb_init_fd returns TB_OK'
  );

  is($Termbox::global->{rfd}, 7, 'rfd == wfd == ttyfd');
};

subtest 'tb_init_file already initialized' => sub {
  plan tests => 1;

  local $Termbox::global->{initialized} = 1;

  is(
    tb_init_file('/dev/tty'),
    TB_ERR_INIT_ALREADY,
    'tb_init_file fails when already initialized'
  );
};

# -----------------
note 'tb_shutdown';
# -----------------

subtest 'tb_shutdown basic behaviour' => sub {
  plan tests => 2;

  local $Termbox::global->{initialized} = 1;

  is(
    tb_shutdown(),
    TB_OK,
    'tb_shutdown returns TB_OK'
  );

  ok(
    !$Termbox::global->{initialized},
    'global initialized cleared'
  );
};

subtest 'tb_shutdown when not initialized' => sub {
  plan tests => 1;

  local $Termbox::global->{initialized} = 0;

  is(
    tb_shutdown(),
    TB_ERR_NOT_INIT,
    'tb_shutdown fails when not initialized'
  );
};

done_testing;
