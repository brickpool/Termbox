#!perl
use 5.014;
use warnings;

use Getopt::Long qw( GetOptions );
use Pod::Usage;

use lib '../lib', 'lib';
use Termbox::Go;
use Termbox::Go::WCWidth qw( wcswidth );

sub main { # $ ()
  my $err = termbox::Init();

  if ($err != 0) {
    warn $!;
    return 1;
  }

  tbprint(2, 2, termbox::ColorRed, termbox::ColorDefault, "Hello terminal!");
  termbox::Flush();

  sleep(1);
  termbox::Close();
  return 0;
}

# This function is often useful.
sub tbprint { # void ($x, $y, $fg, $bg, $msg)
  my ($x, $y, $fg, $bg, $msg) = @_;
  for my $c (split //, $msg) {
    termbox::SetCell($x, $y, $c, $fg, $bg);
    $x += wcswidth($c);
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

hello_world.pl - sample script that usually prints "Hello terminal!"

=head1 SYNOPSIS

  perl example/hello_world.pl

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
