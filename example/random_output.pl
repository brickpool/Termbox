#!perl
use 5.014;
use strict;
use warnings;

use Getopt::Long qw( GetOptions );
use Pod::Usage;
use threads;
use Thread::Queue;
use Time::HiRes;

use lib '../lib', 'lib';
use Termbox::Go;

sub draw { # void ()
  my ($w, $h) = termbox::Size();
  for (my $y = 0; $y < $h; $y++) {
    for (my $x = 0; $x < $w; $x++) {
      termbox::SetCell($x, $y, ' ', termbox::ColorDefault, int(rand(8)+1));
    }
  }
  termbox::Flush();
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
  
  my $event_queue = Thread::Queue->new();
  threads->create( 
    sub {
      for (;;) {
        $event_queue->enqueue(termbox::PollEvent())
      }
    }
  )->detach();

  draw();
loop:
  for (;;) {
    select: {
      case: $event_queue->pending() and do {
        my $ev = $event_queue->dequeue();
        if ($ev->{Type} == termbox::EventKey && $ev->{Key} == termbox::KeyEsc) {
          last loop
        }
        last;
      };
      default: {
        draw();
        Time::HiRes::sleep(0.01); # 10ms
      }
    }
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

random_output.pl - an app that usually prints random colors on console/tty.

=head1 SYNOPSIS

  perl example/random_output.pl

Quit with ESC.

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
