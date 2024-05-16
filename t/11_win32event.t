use 5.014;
use warnings;

use Test::More tests => 6;
use Test::Exception;

plan skip_all => "Windows OS required for testing" unless $^O eq 'MSWin32';

use_ok 'Win32API::File';
use_ok 'Termbox::Go::Win32::Backend', qw(
  create_event
  wait_for_multiple_objects
  set_event
);

my $handle;

lives_ok(
  sub {
    $handle = create_event()
      or die "$^E\n";
  },
  'create_event()'
);

lives_ok(
  sub {
    set_event($handle)
      or die "$^E\n";
  },
  'set_event()'
);

lives_ok(
  sub {
    wait_for_multiple_objects([$handle])
      or die "$^E\n";
  },
  'wait_for_multiple_objects()'
);

lives_ok(
  sub {
    Win32API::File::CloseHandle($handle)
      or die "$^E\n";
  },
  'CloseHandle()'
);

done_testing;
