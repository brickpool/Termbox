#!perl
use 5.014;
use warnings;

use Getopt::Long qw( GetOptions );
use Pod::Usage;

use lib '../lib', 'lib';
use Termbox::Go;

sub draw_ramp { # void ()
  for (my $i = 0; $i < 256; $i++) {
		my $row = int(($i + 2) / 8) + 3;
		my $col = (($i + 2) % 8) * 4;
		my $text = sprintf("%03d", $i);
    for (my $j = 0; $j < 3; $j++) {
      my $ch = substr($text, $j, 1);
      termbox::SetCell($col+$j, $row, $ch, $i+1, termbox::ColorDefault);
      termbox::SetCell($col+$j+36, $row, $ch, termbox::ColorDefault, $i+1);
    }
  }
  termbox::Flush();
  return;
}

sub main { # $ ()
  my $err = termbox::Init();
  if ($err != 0) {
    die $!;
  }
  termbox::SetInputMode(termbox::InputEsc);
  termbox::SetOutputMode(termbox::Output256);

  draw_ramp();

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

256ramp.pl - sample script that prints many colors on console/tty.

=head1 SYNOPSIS

  perl example/256ramp.pl

Exit by pressing any key.

=head1 DESCRIPTION

This gives a table of the 256-color-set,
both the foreground and background variants.
It is ordered to produce many color ramps.

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
