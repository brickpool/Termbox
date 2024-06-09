use 5.014;
use warnings;

use Test::More tests => 20;
use Test::Exception;
use Devel::StrictMode;
use POSIX qw( :errno_h );

use_ok 'Termbox::Go::Devel', qw( :all );

#----------------
note 'debug/set';
#----------------
lives_ok { DEBUG('DEBUG') } 'DEBUG';
lives_ok { DEBUG_FMT('DEBUG_FMT: %s', 'ok') } 'DEBUG_FMT';
subtest 'SET_ERROR' => sub {
  plan tests => 2;
  undef $!;
  lives_ok { SET_ERROR($!, EINVAL, 'SET_ERROR') } 'lives';
  is $!+0, EINVAL, '$!';
};
lives_ok { DEBUG_ERROR($!+0, 'DEBUG_ERROR') } 'DEBUG_ERROR';
lives_ok { SET_FAIL($!, 'SET_FAIL') } 'SET_FAIL';
lives_ok { DEBUG_FAIL('DEBUG_FAIL') } 'DEBUG_FAIL';

#------------
note 'trace';
#------------
lives_ok { TRACE("%s", 'TRACE') } 'TRACE';
lives_ok { TRACE_VOID() } 'TRACE_VOID';

#-------------
note 'return';
#-------------
is RETURN_UNDEF(), undef, 'RETURN_UNDEF';
subtest 'RETURN_OK' => sub {
  plan tests => 2;
  ok RETURN_OK(), '"0 but true"';
  ok !(0+RETURN_OK()), '!!0';
};

#-----------
note 'show';
#-----------
subtest 'SHOW_CODE' => sub {
  plan tests => 2;
  my $result;
  lives_ok { $result = SHOW_CODE($!=ENXIO) } 'lives';
  ok length($result), '$result';
};
is SHOW_CODEVAL($!), $!+0, 'SHOW_CODEVAL';
like SHOW_ERROR($!, 'SHOW_ERROR'), qr/$!/, 'SHOW_ERROR';
is SHOW_FAIL('SHOW_FAIL'), undef, 'SHOW_FAIL';
is SHOW_INT(-1), -1, 'SHOW_INT';
is SHOW_STRING('SHOW_STRING'), 'SHOW_STRING', 'SHOW_STRING';
subtest 'SHOW_POINTER' => sub {
  plan tests => 2;
  my $result;
  lives_ok { $result = SHOW_POINTER(\undef) } 'lives';
  ok length($result), '$result';
};

#--------------------
note 'debug handler';
#--------------------
SKIP: {
  skip 'strict mode not enabled', 1 unless STRICT;

  subtest 'DebugHandler' => sub {
    plan tests => 2;
    no warnings 'once';
    local *termbox::DebugHandler = sub {
      my ($fmt, @args) = @_;
      diag sprintf($fmt, @args);
      pass;
    };
    lives_ok { DEBUG('termbox::DebugHandler() called') } 'lives';
  }
};

#-------------
note 'dumper';
#-------------
SKIP: {
  skip 'Devel::PartialDump not installed', 1 
    unless eval { require Devel::PartialDump };

  subtest 'Devel::PartialDump' => sub {
    plan tests => 3;
    no warnings 'once';
    our $default_dumper = $Devel::PartialDump::default_dumper;
    isa_ok($default_dumper, 'Devel::PartialDump');
    lives_ok {
      $default_dumper->max_length(0);
      is $default_dumper->dump('abc'), '...', 'dump';
    } 'lives';
  }
};

done_testing;
