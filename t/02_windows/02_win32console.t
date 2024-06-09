use 5.014;
use warnings;

use Test::More;
use Test::Exception;

if ($^O ne 'MSWin32') {
  plan skip_all => 'Windows OS required for testing';
}
else {
  plan tests => 15;
}

use Data::Dumper;
use Devel::StrictMode;
BEGIN {
  require List::Util;
  if (exists &List::Util::pairvalues) {
    List::Util->import(qw( pairvalues ));
  } else {
    # pairvalues is not available, so we have to use our own variant
    *pairvalues = sub { return @_[ grep { $_ % 2 } 1..0+@_ ] };
  }
}

use_ok 'Win32';
use_ok 'Win32::Console';
use_ok 'Termbox::Go::Common', qw( $in $out );
use_ok 'Termbox::Go::Win32::Backend', qw( :syscalls );

sub DbgPrint { # $success ($fmt, @args);
  my ($fmt, @args) = @_;
  Win32::OutputDebugString(sprintf($fmt, @args));
}

our $in = Win32::Console::_GetStdHandle(STD_INPUT_HANDLE());
our $out = Win32::Console::_GetStdHandle(STD_ERROR_HANDLE());
ok(
  $in > 0 && $out > 0,
  'GetStdHandle()'
);

lives_ok(
  sub {
    set_console_active_screen_buffer($out)
      or die "$^E\n";
  },
  'set_console_active_screen_buffer()'
);

my $window;
lives_ok(
  sub {
    get_console_screen_buffer_info($out, my $info = {})
      or die "$^E\n";
    DbgPrint Dumper $info if STRICT;
    $window = {
      top => 0,
      bottom => $info->{window}->{bottom} - $info->{window}->{top},
      left => 0,
      right => $info->{window}->{right} - $info->{window}->{left},
    };
  },
  'get_console_screen_buffer_info()'
);

lives_ok(
  sub {
    set_console_window_info($out, $window)
      or die "$^E\n";
  },
  'set_console_window_info()'
);

lives_ok(
  sub {
    get_console_cursor_info($out, my $info = {})
      or die "$^E\n";
    DbgPrint Dumper $info if STRICT;
  },
  'get_console_cursor_info()'
);

lives_ok(
  sub {
    # Note '_WriteConsoleInput' is not implemented correctly (in v0.10):
    # - dwControlKeyState is missing (means a undefined value is used) and 
    # - uChar is (depending on the UNICODE pragma) either at $event[5] or 
    #   $event[6].
    my @event = pairvalues (
      EventType         => 1,  # KEY_CODE
      bKeyDown          => 1,  # TRUE
      wRepeatCount      => 1,  # 1
      wVirtualKeyCode   => 65, # VK_KEY_A
      wVirtualScanCode  => 30, # VK_A
      uChar             => 97, # ord('a'),
      dwControlKeyState => 32, # NUMLOCK_ON
    );
    $event[6] = $event[5] if $Win32::Console::VERSION <= 0.1;
    # Empty the console input buffer, as it is a LIFO buffer.
    Win32::Console::_FlushConsoleInputBuffer($in);
    # Write my own data to the console input buffer
    Win32::Console::_WriteConsoleInput($in, @event)
      or die "$^E\n";
    read_console_input($in, my $record = {})
      or die "$^E\n";
    DbgPrint Dumper $record if STRICT;
  },
  'read_console_input()'
);

my $mode;
lives_ok(
  sub {
    my $handle = get_console_mode($in, \$mode)
      or die "$^E\n";
    DbgPrint $mode if STRICT;
  },
  'get_console_mode()'
);

lives_ok(
  sub {
    my $handle = set_console_mode($in, $mode)
      or die "$^E\n";
  },
  'set_console_mode()'
);

lives_ok(
  sub {
    my $handle = fill_console_output_character($out, ' ', 1)
      or die "$^E\n";
  },
  'fill_console_output_character()'
);

lives_ok(
  sub {
    my $handle = fill_console_output_attribute($out, 0, 1)
      or die "$^E\n";
  },
  'fill_console_output_attribute()'
);

lives_ok(
  sub {
    my $handle = get_current_console_font($out, my $info = {})
      or die "$^E\n";
    DbgPrint Dumper $info if STRICT;
  },
  'get_current_console_font()'
);

done_testing;
