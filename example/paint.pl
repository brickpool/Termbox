#!perl
use 5.014;
use warnings;

use Getopt::Long qw( GetOptions );
use Pod::Usage;
use utf8;

use lib '../lib', 'lib';
use Termbox::Go;

my $curCol = 0;
my $curChar = 0;
my $backbuf = [];
my ($bbw, $bbh);

my $chars = [ ' ', '░', '▒', '▓', '█' ];
my $colors = [
  termbox::ColorBlack,
  termbox::ColorRed,
  termbox::ColorGreen,
  termbox::ColorYellow,
  termbox::ColorBlue,
  termbox::ColorMagenta,
  termbox::ColorCyan,
  termbox::ColorWhite,
];

sub updateAndDrawButtons { # void (\$current, $x, $y, $mx, $my, $n, \&attrf)
  my ($current, $x, $y, $mx, $my, $n, $attrf) = @_;
  my ($lx, $ly) = ($x, $y);
  for (my $i = 0; $i < $n; $i++) {
    if ($lx <= $mx && $mx <= $lx+3 && $ly <= $my && $my <= $ly+1) {
      $$current = $i;
    }
    my ($ch, $fg, $bg) = $attrf->($i);
    termbox::SetCell($lx+0, $ly+0, $ch, $fg, $bg);
    termbox::SetCell($lx+1, $ly+0, $ch, $fg, $bg);
    termbox::SetCell($lx+2, $ly+0, $ch, $fg, $bg);
    termbox::SetCell($lx+3, $ly+0, $ch, $fg, $bg);
    termbox::SetCell($lx+0, $ly+1, $ch, $fg, $bg);
    termbox::SetCell($lx+1, $ly+1, $ch, $fg, $bg);
    termbox::SetCell($lx+2, $ly+1, $ch, $fg, $bg);
    termbox::SetCell($lx+3, $ly+1, $ch, $fg, $bg);
    $lx += 4;
  }
  ($lx, $ly) = ($x, $y);
  for (my $i = 0; $i < $n; $i++) {
    if ($$current == $i) {
      my $fg = termbox::ColorRed | termbox::AttrBold;
      my $bg = termbox::ColorDefault;
      termbox::SetCell($lx+0, $ly+2, '^', $fg, $bg);
      termbox::SetCell($lx+1, $ly+2, '^', $fg, $bg);
      termbox::SetCell($lx+2, $ly+2, '^', $fg, $bg);
      termbox::SetCell($lx+3, $ly+2, '^', $fg, $bg);
    }
    $lx += 4;
  }
  return;
}

sub update_and_redraw_all { # void ($mx, $my)
  my ($mx, $my) = @_;
  termbox::Clear(termbox::ColorDefault, termbox::ColorDefault);
  if ($mx != -1 && $my != -1) {
    $backbuf->[$bbw*$my+$mx] = termbox::Cell{Ch => ord($chars->[$curChar]), Fg => $colors->[$curCol]};
  }
  copy: {
    my $cells = termbox::CellBuffer();
    pop(@$cells) while @$cells;
    push @$cells, map { {%$_} } @$backbuf;
  }
  my (undef, $h) = termbox::Size();
  updateAndDrawButtons(\$curChar, 0, 0, $mx, $my, scalar(@$chars), sub {
    return ($chars->[shift], termbox::ColorDefault, termbox::ColorDefault);
  });
  updateAndDrawButtons(\$curCol, 0, $h-3, $mx, $my, scalar(@$colors), sub {
    return (' ', termbox::ColorDefault, $colors->[shift]);
  });
  termbox::Flush();
  return;
}

sub reallocBackBuffer { # void ($w, $h)
  my ($w, $h) = @_;
  ($bbw, $bbh) = ($w, $h);
  $backbuf = [ map { termbox::Cell() } 1..$w*$h ];
  return;
}

# see https://stackoverflow.com/a/670588
sub OnLeavingScope::DESTROY { ${$_[0]}->() }

sub main { # $ ()
  my $err = termbox::Init();
  if ($err != 0) {
    die $!;
  }
  my $defer = bless \\&termbox::Close, 'OnLeavingScope';
  termbox::SetInputMode(termbox::InputEsc | termbox::InputMouse);
  reallocBackBuffer(termbox::Size());
  update_and_redraw_all(-1, -1);

mainloop:
  for (;;) {
    my ($mx, $my) = (-1, -1);
    switch: my $ev = termbox::PollEvent(); for ($ev->{Type}) {
      case: termbox::EventKey == $_ and do {
        if ($ev->{Key} == termbox::KeyEsc) {
          last mainloop
        }
        last;
      };
      case: termbox::EventMouse == $_ and do {
        if ($ev->{Key} == termbox::MouseLeft) {
          ($mx, $my) = ($ev->{MouseX}, $ev->{MouseY});
        }
        last;
      };
      case: termbox::EventResize == $_ and do {
        reallocBackBuffer($ev->{Width}, $ev->{Height});
        last;
      };
    }
    update_and_redraw_all($mx, $my);
  }
  return 0;
}

exit do {
  GetOptions('help|?' => \my $help, 'man' => \my $man) or pod2usage(2);
  pod2usage(1) if $help;
  pod2usage(-exitval => 0, -verbose => 2) if $man;
  main($#ARGV, $0, @ARGV);
};

__END__

=head1 NAME

paint.pl - sample script for the Termbox::Go module!

=head1 SYNOPSIS

  perl example/paint.pl

=head1 DESCRIPTION

This is a Termbox::Go example script, see L<Termbox::Go> for details.

=head1 OPTIONS

=over

=item B<--help|?>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 CREDITS

=over

=item * Copyright (c) 2012 by termbox-go authors

=item * Author J. Schneider E<lt>L<http://github.com/brickpool>E<gt>

=item * MIT license

=back

=cut
