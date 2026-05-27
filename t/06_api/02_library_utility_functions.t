use 5.010;
use strict;
use warnings;

use Test::More;

BEGIN {
  require_ok 'Termbox::PP';
  use_ok 'Termbox', qw( :return );
}

subtest 'version and feature utilities' => sub {
  plan tests => 5;

  my $v = Termbox::tb_version();
  ok(defined($v) && length($v) > 0, 'tb_version returns a non-empty string');
  is($v, Termbox::TB_VERSION_STR(), 'tb_version matches TB_VERSION_STR');

  my $has_truecolor = Termbox::tb_has_truecolor();
  ok(
    defined($has_truecolor) && ($has_truecolor == 0 || $has_truecolor == 1), 
    'tb_has_truecolor returns 0 or 1'
  );
  my $has_egc = Termbox::tb_has_egc();
  ok(
    defined($has_egc) && ($has_egc == 0 || $has_egc == 1), 
    'tb_has_egc returns 0 or 1'
  );
  my $attr_w = Termbox::tb_attr_width();
  ok(
    $attr_w == 16 || $attr_w == 32 || $attr_w == 64, 
    'tb_attr_width is one of 16/32/64'
  );
};

subtest 'error utilities' => sub {
  plan tests => 5;

  is(Termbox::tb_last_errno(), 0, 'tb_last_errno is 0 by default');
  is(
    Termbox::tb_strerror(TB_OK()), 
    'Success',
    'tb_strerror(TB_OK)'
  );
  is(
    Termbox::tb_strerror(TB_ERR_NEED_MORE()), 
    'Not enough input', 
    'tb_strerror(TB_ERR_NEED_MORE)'
  );
  my $msg = Termbox::tb_strerror(TB_ERR());
  ok(
    defined($msg) && length($msg) >= 0, 
    'tb_strerror(TB_ERR) returns a string'
  );
  $msg = Termbox::tb_strerror(123456);
  ok(
    defined($msg) && length($msg) >= 0,
    'tb_strerror(unknown) returns a fallback string'
  );
};

subtest 'tb_cell_buffer deprecation + return shape' => sub {
  plan tests => 4;

  my @warnings;
  local $SIG{__WARN__} = sub { push @warnings, @_ };

  my $first = Termbox::tb_cell_buffer();
  my $second = Termbox::tb_cell_buffer();

  is(
    ref($first), 
    'ARRAY',
    'tb_cell_buffer returns an array-ref'
  );
  is(
    ref($second),
    'ARRAY',
    'tb_cell_buffer keeps returning an array-ref'
  );
  is(scalar(@warnings), 1, 'tb_cell_buffer warns exactly once');
  like(
    $warnings[0],
    qr/deprecated/i,
    'tb_cell_buffer warning mentions deprecation'
  );
};

done_testing();
