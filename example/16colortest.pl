#!perl
use 5.014;
use warnings;

use Getopt::Long qw( GetOptions );
use Pod::Usage;

use lib '../lib', 'lib';
use Termbox::Go;

sub tbprint { # void ($x, $y, $fg, $bg, $msg)
  my ($x, $y, $fg, $bg, $msg) = @_;
  for my $c (split //, $msg) {
    termbox::SetCell($x, $y, $c, $fg, $bg);
    $x += 1;
  }
  return;
}

sub main { # $ ()
  termbox::Init();

  my ($i, $j);
  my ($fg, $bg);
  my @colorRange = (
    termbox::ColorDefault,
    termbox::ColorBlack,
    termbox::ColorRed,
    termbox::ColorGreen,
    termbox::ColorYellow,
    termbox::ColorBlue,
    termbox::ColorMagenta,
    termbox::ColorCyan,
    termbox::ColorWhite,
    termbox::ColorDarkGray,
    termbox::ColorLightRed,
    termbox::ColorLightGreen,
    termbox::ColorLightYellow,
    termbox::ColorLightBlue,
    termbox::ColorLightMagenta,
    termbox::ColorLightCyan,
    termbox::ColorLightGray,
  );

  my ($row, $col);
  my $text;
  do { $i = 0; for $fg (@colorRange) {
    do { $j = 0; for $bg (@colorRange) {
      $row = $i + 1;
      $col = $j * 8;
      $text = sprintf(" %02d/%02d ", $fg, $bg);
      tbprint($col, $row+0, $fg, $bg, $text);
      q/* 
      $text = sprintf(" on ");
      tbprint($col, $row+1, $fg, $bg, $text);
      $text = sprintf(" %2d ", $bg);
      tbprint($col, $row+2, $fg, $bg, $text); 
      */ if 0;
      # print("$text\n", $col, $row);
    } continue { $j++ }};
  } continue { $i++ }};
  do { $j = 0; for $bg (@colorRange) {
    tbprint($j*8, 0, termbox::ColorDefault, $bg, "       ");
    tbprint($j*8, $i+2, termbox::ColorDefault, $bg, "       ");
  } continue { $j++ }};

  tbprint(15, $i+4, termbox::ColorDefault, termbox::ColorDefault,
    "Press any key to close...");
  termbox::Flush();
  do {} while (termbox::PollEvent()->{Type} != termbox::EventKey);
  termbox::Close();
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

16colortest.pl - an app that demonstrate 16 colors on console/tty.

=head1 SYNOPSIS

  perl example/16colortest.pl

Exit by pressing any key.

=head1 DESCRIPTION

This program can demonstrate the 16 basic colors available
for foreground and background.

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
