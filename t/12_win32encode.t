use 5.014;
use warnings;

use Test::More tests => 6;
plan skip_all => "Windows OS required for testing" unless $^O eq 'MSWin32';

use Devel::Peek;
use Devel::StrictMode;
use Win32::Console;
use Encode;

my $out = Win32::Console->new(STD_ERROR_HANDLE);
isa_ok $out, 'Win32::Console';
ok Win32::Console::OutputCP(65001), 'is CP65001';

my $char;
# $char = "A"; Encode::_utf8_on($char);
$char = "\x{261D}";
#$char = "\x{1F732}";

is length($char), 1, 'length == 1';
ok Encode::is_utf8($char), 'is utf8';
if (STRICT) {
  STDERR->print('# write: ');
  Dump $char ;
}

my ($x, $y) = $out->Cursor();
my $write_ok = $out->WriteChar($char, $x, $y);
my $read = $out->ReadRect($x,$y,$x,$y);

if (STRICT) {
  print "\n";
  diag 'read: ', map { sprintf("\\x%04x", $_) } unpack('S*', $read);
}
ok $write_ok, 'write';
is unpack('S', $read), 0x261D, 'read';

done_testing;
