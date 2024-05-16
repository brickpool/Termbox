use 5.014;
use warnings;

use Test::More tests => 6;
use Test::Exception;
use Devel::StrictMode;
use POSIX qw( :errno_h );

use_ok 'Termbox::Go::Common', qw( usage __FUNCTION__ );
use_ok 'Termbox::Go::Win32::Backend', qw(
  set_console_active_screen_buffer
  set_console_screen_buffer_size
  get_console_mode
);

package Test {

=head1 FUNCTIONS

=head2 croak

  croak($message);

Pod for testing croak with Pod::Usage only.

=cut

  # Comment for testing croak with Pod::Autopod
  sub croak { # void ($message)
    require Carp;
    require Termbox::Go::Common;
    Carp::croak(
      Termbox::Go::Common::usage(
        shift,
        __FILE__,
        Termbox::Go::Common::__FUNCTION__()
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
diag "\n$@" if STRICT;

dies_ok {
  set_console_active_screen_buffer()
    or die $^E 
} 'ERROR_BAD_ARGUMENTS';
diag "\n$@" if STRICT;

dies_ok {
  set_console_screen_buffer_size(1, { x => 0, y => undef })
    or die $^E 
} 'ERROR_INVALID_PARAMETER';
diag "\n$@" if STRICT;

dies_ok {
  get_console_mode(1, \0)
    or die $^E 
} 'ERROR_INVALID_CRUNTIME_PARAMETER';
diag "\n$@" if STRICT;

done_testing;
