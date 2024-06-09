#!perl
use 5.014;
use warnings;

use Getopt::Long qw( GetOptions );
use Pod::Usage;

use lib '../lib', 'lib';
use Termbox::Go;
use Termbox::Go::Common qw( :bool );
use Termbox::Go::WCWidth qw( wcswidth );

my $fgR = 150;
my $fgG = 100;
my $fgB = 50;

my $bgR = 50;
my $bgG = 100;
my $bgB = 150;

my $currentBold = TRUE;
my $currentUnderline = FALSE;
my $currentReverse = FALSE;
my $currentRGB = TRUE;
my $currentCursive = FALSE;
my $currentHidden = FALSE;
my $currentBlink = FALSE;
my $currentDim = FALSE;

my $boolLabel = [];

use constant preview => " Here is some example text ";
use constant padding => "                           ";

use constant coldef => termbox::ColorDefault;

sub tbprint { # void ($x, $y, $fg, $bg, $msg)
  my ($x, $y, $fg, $bg, $msg) = @_;
  for my $c (split //, $msg) {
    termbox::SetCell($x, $y, $c, $fg, $bg);
    $x += wcswidth($c);
  }
  return;
}

sub redraw_all { # void ()
  tbprint(20, 1, coldef, coldef, " - Current Settings - ");

  my ($r, $g, $b);
  $r = sprintf("%3d", $fgR);
  $g = sprintf("%3d", $fgG);
  $b = sprintf("%3d", $fgB);
  tbprint(4, 3, coldef, coldef, "Foreground Red:");
  tbprint(5, 4, coldef, coldef, "[h] $r [l]");
  tbprint(4, 5, coldef, coldef, "Foreground Green:");
  tbprint(5, 6, coldef, coldef, "[j] $g [k]");
  tbprint(4, 7, coldef, coldef, "Foreground Blue:");
  tbprint(5, 8, coldef, coldef, "[u] $b [i]");

  $r = sprintf("%3d", $bgR);
  $g = sprintf("%3d", $bgG);
  $b = sprintf("%3d", $bgB);
  tbprint(23, 3, coldef, coldef, "Background Red:");
  tbprint(24, 4, coldef, coldef, "[H] $r [L]");
  tbprint(23, 5, coldef, coldef, "Background Green:");
  tbprint(24, 6, coldef, coldef, "[J] $g [K]");
  tbprint(23, 7, coldef, coldef, "Background Blue:");
  tbprint(24, 8, coldef, coldef, "[U] $b [I]");

  my ($bold, $ul, $rev, $rgb, $cur, $hid, $blink, $dim);
  $bold = $boolLabel->[$currentBold];
  $ul = $boolLabel->[$currentUnderline];
  $rev = $boolLabel->[$currentReverse];
  $rgb = $boolLabel->[$currentRGB];
  $cur = $boolLabel->[$currentCursive];
  $hid = $boolLabel->[$currentHidden];
  $blink = $boolLabel->[$currentBlink];
  $dim = $boolLabel->[$currentDim];

  tbprint(42, 3, coldef, coldef, "Bold:");
  tbprint(43, 4, coldef, coldef, "$bold [w]");
  tbprint(42, 5, coldef, coldef, "Underline:");
  tbprint(43, 6, coldef, coldef, "$ul [a]");
  tbprint(42, 7, coldef, coldef, "Reverse:");
  tbprint(43, 8, coldef, coldef, "$rev [s]");
  tbprint(42, 9, coldef, coldef, "Full RGB:");
  tbprint(43, 10, coldef, coldef, "$rgb [t]");
  tbprint(54, 3, coldef, coldef, "Cursive:");
  tbprint(55, 4, coldef, coldef, "$cur [d]");
  tbprint(54, 5, coldef, coldef, "Hidden:");
  tbprint(55, 6, coldef, coldef, "$hid [e]");
  tbprint(54, 7, coldef, coldef, "Blink:");
  tbprint(55, 8, coldef, coldef, "$blink [r]");
  tbprint(54, 9, coldef, coldef, "Dim:");
  tbprint(55, 10, coldef, coldef, "$dim [f]");

  tbprint(20, 12, coldef, coldef, "Quit with [q] or [ESC]");
  tbprint(6, 13, coldef, coldef, "Note that RGB may be incompatible with other modifiers");

  my ($fg, $bg);
  if ($currentRGB) {
    termbox::SetOutputMode(termbox::OutputRGB);
    $fg = termbox::RGBToAttribute($fgR, $fgG, $fgB);
    $bg = termbox::RGBToAttribute($bgR, $bgG, $bgB);
  } else {
    termbox::SetOutputMode(termbox::OutputNormal);
    $fg = termbox::ColorRed;
    $bg = termbox::ColorDefault;
  }
  my $tfg = $fg; # tfg are the attributes that should be applied to the text
  if ($currentBold) {
    $tfg |= termbox::AttrBold;
  }
  if ($currentUnderline) {
    $tfg |= termbox::AttrUnderline;
  }
  if ($currentReverse) {
    $fg |= termbox::AttrReverse;
    $tfg |= termbox::AttrReverse;
  }
  if ($currentCursive) {
    $tfg |= termbox::AttrCursive;
  }
  if ($currentHidden) {
    $fg |= termbox::AttrHidden;
    $tfg |= termbox::AttrHidden;
  }
  if ($currentBlink) {
    $fg |= termbox::AttrBlink;
    $tfg |= termbox::AttrBlink;
  }
  if ($currentDim) {
    $fg |= termbox::AttrDim;
    $tfg |= termbox::AttrDim;
  }
  tbprint(18, 15, $fg, $bg, padding);
  tbprint(18, 16, $tfg, $bg, preview);
  tbprint(18, 17, $fg, $bg, padding);

  termbox::Flush();
  return;
}

# see https://stackoverflow.com/a/670588
sub OnLeavingScope::DESTROY { ${$_[0]}->() }

sub main { # $ ()
  $boolLabel->[FALSE] = "Off";
  $boolLabel->[TRUE] = "On ";

  my $err = termbox::Init();
  if ($err != 0) {
    die $!;
  }
  my $defer = bless \\&termbox::Close, 'OnLeavingScope';
  termbox::SetInputMode(termbox::InputEsc);

  redraw_all();
mainloop:
  for (;;) {
    my $ev = termbox::PollEvent();
    switch: for ($ev->{Type}) {
      case: $_ == termbox::EventKey and do {
        local $_;
        switch: for ($ev->{Key}) {
          case: $_ == termbox::KeyEsc and do {
            last mainloop;
          };
          default: {
            local $_;
            switch: for ($ev->{Ch}) {
              case: $_ == ord('q') || $_ == ord('Q') and do {
                last mainloop;
              };
              case: $_ == ord('h') and do {
                $fgR--;
                $fgR %= 256;
                last;
              };
              case: $_ == ord('l') and do {
                $fgR++;
                $fgR %= 256;
                last;
              };
              case: $_ == ord('j') and do {
                $fgG--;
                $fgG %= 256;
                last;
              };
              case: $_ == ord('k') and do {
                $fgG++;
                $fgG %= 256;
                last;
              };
              case: $_ == ord('u') and do {
                $fgB--;
                $fgB %= 256;
                last;
              };
              case: $_ == ord('i') and do {
                $fgB++;
                $fgB %= 256;
                last;
              };
              case: $_ == ord('H') and do {
                $bgR--;
                $bgR %= 256;
                last;
              };
              case: $_ == ord('L') and do {
                $bgR++;
                $bgR %= 256;
                last;
              };
              case: $_ == ord('J') and do {
                $bgG--;
                $bgG %= 256;
                last;
              };
              case: $_ == ord('K') and do {
                $bgG++;
                $bgG %= 256;
                last;
              };
              case: $_ == ord('U') and do {
                $bgB--;
                $bgB %= 256;
                last;
              };
              case: $_ == ord('I') and do {
                $bgB++;
                $bgB %= 256;
                last;
              };
              case: $_ == ord('w') || $_ == ord('W') and do {
                $currentBold = !$currentBold;
                last;
              };
              case: $_ == ord('a') || $_ == ord('A') and do {
                $currentUnderline = !$currentUnderline;
                last;
              };
              case: $_ == ord('s') || $_ == ord('S') and do {
                $currentReverse = !$currentReverse;
                last;
              };
              case: $_ == ord('t') || $_ == ord('T') and do {
                $currentRGB = !$currentRGB;
                last;
              };
              case: $_ == ord('d') || $_ == ord('D') and do {
                $currentCursive = !$currentCursive;
                last;
              };
              case: $_ == ord('e') || $_ == ord('E') and do {
                $currentHidden = !$currentHidden;
                last;
              };
              case: $_ == ord('r') || $_ == ord('R') and do {
                $currentBlink = !$currentBlink;
                last;
              };
              case: $_ == ord('f') || $_ == ord('F') and do {
                $currentDim = !$currentDim;
                last;
              };
            }
          }
        }
        last;
      };
      case: $_ == termbox::EventError and do {
        die $ev->{Err};
      };
    }
    redraw_all();
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

rgbcolor.pl - sample script that demonstrate RGB colors on console/tty.

=head1 SYNOPSIS

  perl example/rgbcolor.pl

=head1 DESCRIPTION

This example should demonstrate the functionality of full rgb-support, 
as well as the ability to combine rgb colors and (multiple) attributes.

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
