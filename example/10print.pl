#!perl
use 5.014;
use warnings;

use Getopt::Long qw( GetOptions );
use Pod::Usage;

use lib '../lib', 'lib';
use Termbox::Go;
use List::Util qw( min );

# see https://stackoverflow.com/a/670588
sub OnLeavingScope::DESTROY { ${$_[0]}->() }

sub main { # $ ()
  die $! if termbox::Init();
  my $defer = bless \\&termbox::Close, 'OnLeavingScope';

  my ($w, $h) = termbox::Size();
  for (my $y = 0; $y < min(25, $h); $y++) {
    for (my $x = 0; $x < min(40, $w); $x++) {
      termbox::SetCell($x, $y, chr(9585.5+rand), termbox::ColorWhite, 
        termbox::ColorLightBlue);
      termbox::Flush();
    }
  }

  do {} while (termbox::PollEvent()->{Type} != termbox::EventKey);
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

10print.pl - a Commodore 64 BASIC inspired maze program.

=head1 SYNOPSIS

  perl example/10print.pl

Exit by pressing any key.

=head1 DESCRIPTION

10 PRINT is a one-line Commodore 64 BASIC program, published in November 2012. 

  10 PRINT CHR$(205.5+RND(1)); : GOTO 10

This app takes the idea and implements it with L<Termbox::Go>.

=head1 OPTIONS

=over

=item B<--help|?>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 CREDITS

=over

=item * Copyright (c) 2012 by the authors of L<10print|https://10print.org/>

=item * Author J. Schneider E<lt>L<http://github.com/brickpool>E<gt>

=item * MIT license

=back

=cut
