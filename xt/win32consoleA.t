#------------------------------------------------------------------------------
#   Test program which detects whether Console.xs has been compiled with pragma
#   UNICODE or not.
#
#   WriteConsoleInput() is not correctly implemented:
#   - dwControlKeyState is missing (means a undefined value is used) and 
#   - uChar is (depending on the UNICODE pragma) either at $_[6] or 
#     $_[7].
#
#   Whether we use ReadConsoleInputA or ReadConsoleInputW can be recognized by 
#   this bug. _ReadConsoleInput does not return the correct character after a 
#   _WriteConsoleInput.
#------------------------------------------------------------------------------
#   Author: 2024 J. Schneider
#------------------------------------------------------------------------------
use 5.014;
use warnings;

use Test::More tests => 6;
use Test::Exception;

plan skip_all => "Windows OS required for testing" unless $^O eq 'MSWin32';

use List::Util 1.29 qw( pairvalues );

use_ok 'Win32::Console';

our $in = Win32::Console::_GetStdHandle(
  Win32::Console::constant('STD_INPUT_HANDLE', 0));
ok $in > 0, '_GetStdHandle()';

my @event = pairvalues (
    EventType         => 1,  # KEY_CODE
    bKeyDown          => 1,  # TRUE
    wRepeatCount      => 1,  # 1
    wVirtualKeyCode   => 65, # VK_KEY_A
    wVirtualScanCode  => 30, # VK_A
    uChar             => 97, # ord('a'),
    dwControlKeyState => 32, # NUMLOCK_ON
);

# Empty the console input buffer, as it is a LIFO buffer.
lives_ok { Win32::Console::_FlushConsoleInputBuffer($in) } '_FlushConsoleInputBuffer()';
# Write my own data to the console input buffer
lives_ok { Win32::Console::_WriteConsoleInput($in, @event) } '_WriteConsoleInput()';
# Read current event from the console input buffer
lives_ok { @event = Win32::Console::_ReadConsoleInput($in) } '_ReadConsoleInput()';
ok $event[5] && $event[5] >= 32, 'valid event';

if ($event[5] == 32) {
  note 'Not compiled with pragma UNICODE.';
} else {
  note 'Compiled with pramgma UNICODE or bug fixed!';
}

done_testing;
