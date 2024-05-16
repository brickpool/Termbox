use 5.014;
use warnings;

use Test::More tests => 4;
use Test::Exception;
use Devel::StrictMode;

BEGIN {
  # https://github.com/microsoft/terminal/issues/6045#issuecomment-631645277
  $ENV{TERM} //= 'xterm-256color' if $^O eq 'MSWin32';
}

sub termbox::DebugHandler { # void ($fmt, @args)
  STDERR->printf(@_) if STRICT;
  return;
};

use_ok 'Termbox::Go::Terminfo', qw( :all );

SKIP: {
  skip 'TERM not set', 2 unless $ENV{TERM};
  lives_ok { ti_try_path('.') } 'ti_try_path';
  lives_ok { load_terminfo() } 'load_terminfo';
}
lives_ok { setup_term() } 'setup_term';

done_testing;
