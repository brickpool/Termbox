#!perl
use 5.014;
use warnings;

use Getopt::Long qw( GetOptions );
use Pod::Usage;

use lib '../lib', 'lib';
use Termbox::Go;

my $letters = ['o', 'x', 'i', 'n', 'u', 's', ' '];

my $color = 0;

sub main { # $ ()
  my $err = termbox::Init();

  if ($err != 0) {
    warn $!;
    return 1;
  }

  my ($w, $h) = termbox::Size();
  for (my $x = 0; $x < $w; $x++) {
    for (my $y = 0; $y < $h; $y++) {
      termbox::SetChar($x, $y, $letters->[int(rand(scalar(@$letters)))]);
    }
  }
  termbox::Flush();

  threads->create( \&bgthread )->detach();

  for (;;) {
    my $ev = termbox::PollEvent();
    if ($ev->{Type} == termbox::EventKey) {
      if ($ev->{Ch} == ord('q') || $ev->{Key} == termbox::KeyEsc) {
        last;
      } elsif ($ev->{Ch} == ord('h') || $ev->{Key} == termbox::KeyArrowLeft) {
        $color--;
      } elsif ($ev->{Ch} == ord('l') || $ev->{Key} == termbox::KeyArrowRight) {
        $color++;
      }
      while ($color < 0) {
        $color += 9;
      }
      $color %= 9;
      fillbg($color);
      termbox::Flush();
    }
  }

  termbox::Close();
  return 0;
}

sub fillbg { # void ($bg)
  my ($bg) = @_;
  my ($w, $h) = termbox::Size();
  for (my $x = 0; $x < $w; $x++) {
    for (my $y = 0; $y < $h; $y++) {
      termbox::SetBg($x, $y, $bg);
    }
  }
  return;
}

sub bgthread { # void ()
  my $ticker = time()+1;
  for (;;) {
    my ($w, $h) = termbox::Size();
    for (my $x = 0; $x < $w; $x++) {
      for (my $y = 0; $y < $h; $y++) {
        termbox::SetFg($x, $y, int(rand(9)));
      }
    }
    if (time() > $ticker) {
      termbox::Flush();
      $ticker = time()+1;
    }
  }
  return;
}

exit do {
  GetOptions('help|?' => \my $help, 'man' => \my $man) or pod2usage(2);
  pod2usage(1) if $help;
  pod2usage(-exitval => 0, -verbose => 2) if $man;
  main($#ARGV, $0, @ARGV);
};

__END__

=head1 NAME

advanced_editing.pl - sample script for the Termbox library

=head1 SYNOPSIS

  perl example/advanced_editing.pl

=head1 DESCRIPTION

A number of colored letters are displayed.
You can change the background color using the arrow keys.
the foreground color changes randomly over time.

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
