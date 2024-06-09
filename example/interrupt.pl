#!perl
use 5.014;
use warnings;

use Getopt::Long qw( GetOptions );
use Pod::Usage;
use threads;

use lib '../lib', 'lib';
use Termbox::Go;

sub tbPrint { # void ($x, $y, $fg, $bg, $msg)
  my ($x, $y, $fg, $bg, $msg) = @_;
  for my $c (split //, $msg) {
    termbox::SetCell($x, $y, $c, $fg, $bg);
    $x++;
  }
  return;
}

# see https://stackoverflow.com/a/670588
sub OnLeavingScope::DESTROY { ${$_[0]}->() }

sub draw { # void ($i)
  use integer;
  my ($i) = @_;
  termbox::Clear(termbox::ColorDefault, termbox::ColorDefault);
  my $defer = bless \\&termbox::Flush, 'OnLeavingScope';

  my ($w, $h) = termbox::Size();
  my $s = sprintf("count = %d", $i);
  tbPrint(($w/2)-(length($s)/2), $h/2, termbox::ColorRed, termbox::ColorDefault, $s);
  return;
}

sub main { # $ ()
  my $err = termbox::Init();
  if ($err != 0) {
    die $!;
  }
  termbox::SetInputMode(termbox::InputEsc);

  threads->create( sub {
    local $SIG{__DIE__} = sub { exit };
    sleep(5); # time Second
    termbox::Interrupt();

    # This should never run - the Interrupt(), above, should cause the event
    # loop below to exit, which then exits the process.  If something goes
    # wrong, this panic will trigger and show what happened.
    sleep(1); # time Second
    die("this should never run\n");
  })->detach();

  my $count = 0;

  draw($count);
mainloop:
  for (;;) {
    switch: my $ev = termbox::PollEvent(); for ($ev->{Type}//0) {
      case: $_ == termbox::EventKey and do {
        if ($ev->{Ch} == ord '+') {
          $count++;
        } elsif ($ev->{Ch} == ord '-') {
          $count--;
        }
        last;
      };
      case: $_ == termbox::EventError and do {
        die($ev->{Err});
        last;
      };
      case: $_ == termbox::EventInterrupt and do {
        last mainloop;
      };
    }
    draw($count);
  }
  termbox::Close();

  say("Finished");
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

interrupt.pl - sample script that shows the usage of Interrupt()

=head1 SYNOPSIS

  perl example/interrupt.pl

The counter can be counted up or down using the '+' and '-' keys. 
After 5 seconds the app is automatically closed and a completion message 
appears.

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
