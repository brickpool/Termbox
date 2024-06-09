#!perl
use 5.014;
use warnings;

require bytes;
use Getopt::Long qw( GetOptions );
use Pod::Usage;

use lib '../lib', 'lib';
use Termbox::Go;
use Termbox::Go::Common qw( :bool );

sub tbprint { # void ($x, $y, $fg, $bg, $msg)
  my ($x, $y, $fg, $bg, $msg) = @_;
  for my $c (split //, $msg) {
    termbox::SetCell($x, $y, $c, $fg, $bg);
    $x++;
  }
  return;
}

my $current;
my $curev = termbox::Event;

sub mouse_button_str { # $string ($k)
  my ($k) = @_;
  switch: for ($k) {
    case: $_ == termbox::MouseLeft and
      return "MouseLeft";
    case: $_ == termbox::MouseMiddle and
      return "MouseMiddle";
    case: $_ == termbox::MouseRight and
      return "MouseRight";
    case: $_ == termbox::MouseRelease and
      return "MouseRelease";
    case: $_ == termbox::MouseWheelUp and
      return "MouseWheelUp";
    case: $_ == termbox::MouseWheelDown and
      return "MouseWheelDown";
  }
  return "Key";
}

sub mod_str { # $string ($m)
  my ($m) = @_;
  my @out = ();
  if ($m & termbox::ModAlt) {
    push(@out, "ModAlt");
  }
  if ($m & termbox::ModMotion) {
    push(@out, "ModMotion");
  }
  return join(" | ", @out);
}

sub redraw_all { # void ()
  use constant coldef => termbox::ColorDefault;
  termbox::Clear(coldef, coldef);
  tbprint(0, 0, termbox::ColorMagenta, coldef, "Press 'q' to quit");
  tbprint(0, 1, coldef, coldef, $current);
  switch: for ($curev->{Type}) {
    case: $_ == termbox::EventKey and do {
      tbprint(0, 2, coldef, coldef,
        sprintf("EventKey: k: %d, c: %c, mod: %s", $curev->{Key}, 
          $curev->{Ch}, mod_str($curev->{Mod})));
      last;
    };
    case: $_ == termbox::EventMouse and do {
      tbprint(0, 2, coldef, coldef,
        sprintf("EventMouse: x: %d, y: %d, b: %s, mod: %s",
          $curev->{MouseX}, $curev->{MouseY}, mouse_button_str($curev->{Key}), 
            mod_str($curev->{Mod})));
      last;
    };
    case: $_ == termbox::EventNone and do {
      tbprint(0, 2, coldef, coldef, "EventNone");
      last;
    };
  }
  tbprint(0, 3, coldef, coldef, sprintf("%d", $curev->{N}));
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
  termbox::SetInputMode(termbox::InputEsc | termbox::InputMouse);
  redraw_all();

  my $data = '';
mainloop:
  for (;;) {
    my $d = "\0" x 32;
    my $ev = termbox::PollRawEvent($d); $data .= $d; 
    switch: for ($ev->{Type}) {
      case: $_ == termbox::EventRaw and do {
        $current = sprintf("%s", substr($data, 0, 1));
        if ($current eq "q") {
          last mainloop;
        }
        for (;;) {
          $ev = termbox::ParseEvent($data);
          if ($ev->{N} == 0) {
            last;
          }
          $curev = { %$ev };
          $data = bytes::substr($data, $curev->{N});
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

raw_input.pl - sample script that demonstrate the PollRawEvent() function.

=head1 SYNOPSIS

  perl example/raw_input.pl

Quit with 'q'.

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
