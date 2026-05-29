use 5.010;
use strict;
use warnings;

use Test::More;

BEGIN {
  require_ok 'Termbox::PP';
  use_ok 'Termbox', qw( :return );
}

sub valid_preinit_status {
  my ($rv) = @_;
  return 1
    if $rv == TB_ERR_NOT_INIT()
    || $rv == TB_ERR_OUT_OF_BOUNDS()
    || $rv == TB_ERR();
  return 0;
}

subtest 'pre-init status checks' => sub {
  plan tests => 4;

  my $rv = Termbox::tb_set_cell(0, 0, ord('A'), 0, 0);
  ok(valid_preinit_status($rv), 'tb_set_cell returns expected pre-init status');

  $rv = Termbox::tb_set_cell_ex(0, 0, [ord('A')], 1, 0, 0);
  ok(
    valid_preinit_status($rv), 
    'tb_set_cell_ex returns expected pre-init status'
  );

  $rv = Termbox::tb_extend_cell(0, 0, 0x0301);
  ok(
    valid_preinit_status($rv),
    'tb_extend_cell returns expected pre-init status'
  );

  $rv = Termbox::tb_set_cell_ex(0, 0, [], 0, 0, 0);
  ok(
    valid_preinit_status($rv),
    'tb_set_cell_ex handles empty cluster pre-init'
  );
};

subtest 'set-cell APIs after init' => sub {
  local $SIG{__WARN__} = sub { };

  $Termbox::global->{initialized} = 1;
  $Termbox::global->{width} = 80;
  $Termbox::global->{height} = 24;

  my $rv = Termbox::init_cellbuf();
  plan skip_all => 'init_cellbuf failed in this environment'
    if $rv != TB_OK();

  plan tests => 8;

  $rv = Termbox::tb_set_cell(0, 0, ord('A'), 0, 0);
  is($rv, TB_OK(), 'tb_set_cell writes one codepoint');

  my $cells = Termbox::tb_cell_buffer();
  is($cells->[0]->{ch}, 'A', 'tb_set_cell stores expected text');

  $rv = Termbox::tb_set_cell_ex(0, 0, [ord('A'), 0x0301], 2, 0, 0);
  is($rv, TB_OK(), 'tb_set_cell_ex writes a cluster');
  is($cells->[0]->{ch}, "A\x{0301}", 'tb_set_cell_ex stores combined grapheme');

  $rv = Termbox::tb_extend_cell(0, 0, 0x0327);
  is($rv, TB_OK(), 'tb_extend_cell appends one codepoint');
  is(
    $cells->[0]->{ch},
    "A\x{0301}\x{0327}",
    'tb_extend_cell appends to existing grapheme'
  );

  $rv = Termbox::tb_set_cell_ex(0, 0, [], 0, 0, 0);
  is($rv, TB_ERR(), 'tb_set_cell_ex rejects empty cluster after init');
  is(Termbox::tb_deinit(), TB_OK(), 'tb_deinit succeeds');
};

done_testing();
