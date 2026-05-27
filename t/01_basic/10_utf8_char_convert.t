use 5.010;
use strict;
use warnings;
use utf8;

use Test::More;
binmode( Test::More->builder->failure_output(), ':utf8');
binmode( Test::More->builder->output(), ':utf8');

BEGIN {
  require_ok 'Termbox::PP';
  use_ok 'Termbox', qw(
    tb_utf8_char_to_unicode
    tb_utf8_unicode_to_char
  );
}

# -----------------------------
note 'tb_utf8_char_to_unicode';
# -----------------------------

subtest 'tb_utf8_char_to_unicode - ASCII and Unicode' => sub {
  plan tests => 4;
  my ($out, $len);

  $len = tb_utf8_char_to_unicode(\$out, 'A');
  is($out, ord('A'), 'ASCII: A => 0x41');
  is($len, 1, 'ASCII: length 1');

  $len = tb_utf8_char_to_unicode(\$out, "\x{00E9}");
  is($out, 0xE9, 'Unicode: é => 0xE9');
  is($len, 2, 'Unicode: é length 2');
};

# -----------------------------
note 'tb_utf8_unicode_to_char';
# -----------------------------

subtest 'tb_utf8_unicode_to_char - ASCII and Unicode' => sub {
  plan tests => 4;
  my ($out, $len);

  $len = tb_utf8_unicode_to_char(\$out, 0x41);
  is($out, 'A', '0x41 => ASCII A');
  is($len, 1, 'ASCII: length 1');

  $len = tb_utf8_unicode_to_char(\$out, 0xE9);
  is($out, "\x{00E9}", '0xE9 => UTF-8 é');
  is($len, 2, 'Unicode: é length 2');
};

done_testing();
