use 5.014;
use warnings;

use Test::More;
use Test::Exception;
use Devel::StrictMode;

if ($^O eq 'MSWin32') {
  plan skip_all => 'Test irrelevant for Windows OS';
}
else {
  plan tests => 8;
}

use_ok 'Termbox::Go::Common', qw( :color :attr );
use_ok 'Termbox::Go::Terminal', qw( :api );

sub tb_printf { # $errno ($x, $y, $fg, $bg, $fmt, ...)
  my ($x, $y, $fg, $bg, $fmt, @vl) = @_;
  my $str = sprintf($fmt, @vl);
	for my $c (split //, $str) {
		die "$!" if SetCell($x++, $y, $c, $fg, $bg) != 0;
	}
  return 0;
}

lives_ok { Init() == 0 or die $! } 'Init()';

my ($w, $h);
lives_ok { ($w, $h) = Size(); die $! if $! } 'Size()';

my $bg = ColorBlack();
my $red = ColorRed();
my $green = ColorGreen();
my $blue = ColorBlue();
ok $bg && $red && $green && $blue, ':color';

my $y = 0;
my $has_version = length($Termbox::Go::Terminal::VERSION) > 0;
subtest 'tb_printf()' => sub {
  plan tests => 4;
  lives_ok { tb_printf(0, $y++, 0, 0, "has_version=%s", $has_version ? 'y' : 'n') == 0 or die };
  lives_ok { tb_printf(0, $y++, $red, $bg, "width=%d", $w) == 0 or die };
  lives_ok { tb_printf(0, $y++, $green, $bg, "height=%d", $h) == 0 or die };
  lives_ok { no strict 'refs';
    foreach my $attr (qw(AttrBold AttrUnderline AttrCursive AttrReverse AttrBlink AttrDim)) {
      tb_printf(0, $y++, $blue | &$attr(), $bg, "attr=%s", $attr) == 0 or die;
      do { Flush() == 0 or die } if STRICT;
      sleep(0+STRICT);
    }
  };
};

lives_ok { Flush() == 0 or die $! } 'Flush()';
sleep(0+STRICT);
lives_ok { Close() == 0 or die $! } 'Close()';

done_testing;
