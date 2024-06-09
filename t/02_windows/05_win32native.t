use 5.014;
use warnings;

use Test::More;
use Test::Exception;

if ($^O ne 'MSWin32') {
  plan skip_all => 'Windows OS required for testing';
}
else {
  plan tests => 12;
}

use Data::Dumper;
use Devel::StrictMode;

use_ok 'Win32';
use_ok 'Win32::Console';
use_ok 'Termbox::Go::Common', qw( :vars );
use_ok 'Termbox::Go::Win32::Backend', qw( :func :vars );

sub DbgPrint { # $success ($fmt, @args);
  my ($fmt, @args) = @_;
  Win32::OutputDebugString(sprintf($fmt, @args));
}

our $in = Win32::Console::_GetStdHandle(
  Win32::Console::constant('STD_INPUT_HANDLE', 0));
our $out = Win32::Console::_GetStdHandle(
  Win32::Console::constant('STD_ERROR_HANDLE', 0));
ok(
  $in > 0 && $out > 0,
  'GetStdHandle()'
);

lives_ok(
  sub {
    my $cursor = get_cursor_position($out);
    DbgPrint Dumper $cursor if STRICT;
  },
  'get_console_cursor_info()'
);

lives_ok(
  sub {
    my ($coord, $rect) = get_term_size($out);
    DbgPrint("%s%s", Dumper($coord), Dumper($rect)) if STRICT;
  },
  'get_term_size()'
);

lives_ok(
  sub {
    my $coord = get_win_min_size($out);
    DbgPrint Dumper $coord if STRICT;
  },
  'get_win_min_size()'
);

my $size;
lives_ok(
  sub {
    $size = get_win_size($out);
    DbgPrint Dumper $size if STRICT;
  },
  'get_win_size()'
);

lives_ok(
  sub {
    fix_win_size($out, $size)
      or die "$^E\n";
  },
  'fix_win_size()'
);

subtest 'setup' => sub {
  plan tests => 3;
  our $term_size;
  our $back_buffer;
  our $front_buffer;
  isa_ok($back_buffer, 'cellbuf');
  isa_ok($front_buffer, 'cellbuf');
  lives_ok(
    sub {
      ($term_size) = get_term_size($out) or die $!;
      $back_buffer->init($term_size->{x}, $term_size->{y});
      $front_buffer->init($term_size->{x}, $term_size->{y});
    },
    'lives'
  );
};

SKIP: {
  skip 'extended testing', 1 unless STRICT;
  lives_ok(
    sub {
      # mock clear()
      no warnings qw( redefine once );
      local *Termbox::Go::Win32::Backend::clear = sub {};

      update_size_maybe() 
        or die "$^E\n";
    },
    'update_size_maybe()'
  );
}

done_testing;
