use 5.014;
use warnings;

use Test::More;
use Test::Exception;

if ($^O ne 'MSWin32') {
  plan skip_all => 'Windows OS required for testing';
}
else {
  plan tests => 7;
}

use Devel::StrictMode;
use POSIX qw( :errno_h );

plan skip_all => "Windows OS required for testing" unless $^O eq 'MSWin32';

use_ok 'Win32';
use_ok 'Termbox::Go::Devel', qw( usage __FUNCTION__ );
use_ok 'Termbox::Go::Win32::Backend', qw(
  set_console_active_screen_buffer
  set_console_screen_buffer_size
  get_console_mode
);

sub DbgPrint { # $success ($fmt, @args);
  my ($fmt, @args) = @_;
  Win32::OutputDebugString(sprintf($fmt, @args));
}

package Test {

=head1 FUNCTIONS

=head2 croak

  croak($message);

Pod for testing croak with Pod::Usage only.

=cut

  # Comment for testing croak with Pod::Autopod
  sub croak { # void ($message)
    require Carp;
    require Termbox::Go::Devel;
    Carp::croak(
      Termbox::Go::Devel::usage(
        shift,
        __FILE__,
        Termbox::Go::Devel::__FUNCTION__()
      )
    )
  }

  1;
}

throws_ok(
  sub {
    Test::croak($! = EINVAL);
  },
  qr/(?:test(\$message))|(?:Invalid argument)/,
 'croak(EINVAL)'
);
DbgPrint "$@" if STRICT;

dies_ok {
  set_console_active_screen_buffer()
    or die $^E 
} 'ERROR_BAD_ARGUMENTS';
DbgPrint "$@" if STRICT;

SKIP: {
  skip 'strict mode not enabled', 1 unless STRICT;
  dies_ok {
    set_console_screen_buffer_size(1, { x => 0, y => undef })
      or die $^E
  } 'ERROR_INVALID_PARAMETER';
  DbgPrint do { local $_ = "$@"; s/%/%%/g; $_ } if STRICT;
}

dies_ok {
  get_console_mode(1, \0)
    or die $^E 
} 'ERROR_INVALID_CRUNTIME_PARAMETER';
DbgPrint "$@" if STRICT;

done_testing;
