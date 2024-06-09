#!perl
use 5.014;
use warnings;

use Getopt::Long qw( GetOptions );
use Pod::Usage;
use Unicode::EastAsianWidth;
use utf8;

use lib '../lib', 'lib';
use Termbox::Go;
use Termbox::Go::Common qw( :bool );
use Termbox::Go::WCWidth qw( wcswidth );
INIT {
  use if $^O eq 'MSWin32', 'Termbox::Go::Win32::Backend', qw( $is_cjk );
  our $is_cjk = 1;
}

use constant chars => "nnnnnnnnnbbbbbbbbbuuuuuuuuuBBBBBBBBB";

our $output_mode = termbox::OutputNormal;

sub next_char { # $ ($current)
  my ($current) = @_;
  $current++;
  if ($current >= length(chars)) {
    return 0;
  }
  return $current;
}

sub print_combinations_table { # void ($sx, $sy, \@attrs)
  my ($sx, $sy, $attrs) = @_;
  my $bg;
  my $current_char = 0;
  my $y = $sy;

  state $all_attrs = [
    0,
    termbox::AttrBold,
    termbox::AttrUnderline,
    termbox::AttrBold | termbox::AttrUnderline,
  ];

  my $draw_line = sub {
    my $x = $sx;
    foreach my $a (@$all_attrs) {
      for (my $c = termbox::ColorDefault; $c <= termbox::ColorWhite; $c++) {
        my $fg = $a | $c;
        termbox::SetCell($x, $y, substr(chars, $current_char, 1), $fg, $bg);
        $current_char = next_char($current_char);
        $x++;
      }
    }
  };

  foreach my $a (@$all_attrs) {
    for (my $c = termbox::ColorDefault; $c <= termbox::ColorWhite; $c++) {
      $bg = $a | $c;
      $draw_line->();
      $y++;
    }
  }
  return;
}

sub print_wide { # void ($x, $y, $s)
  my ($x, $y, $s) = @_;
  state $red = FALSE;
  foreach my $r (split //, $s) {
    my $c = termbox::ColorDefault;
    if ($red) {
      $c = termbox::ColorRed;
    }
    termbox::SetCell($x, $y, $r, termbox::ColorDefault, $c);
    my $w = wcswidth($r);
    if ($w <= 0 || $w == 2 && $r =~ /\p{InEastAsianAmbiguous}/) {
      $w = 1;
    }
    $x += $w;

    $red = !$red;
  }
  return;
}

use constant hello_world => "こんにちは世界!";

sub draw_all { # void ()
  termbox::Clear(termbox::ColorDefault, termbox::ColorDefault);

  switch: for ($output_mode) {
    case: $_ == termbox::OutputNormal and do {
      print_combinations_table(1, 1, [0, termbox::AttrBold]);
      print_combinations_table(2+length(chars), 1, [termbox::AttrReverse]);
      print_wide(2+length(chars), 11, hello_world);
      last;
    };
    case: $_ == termbox::OutputGrayscale and do {
      for (my $y = 0; $y < 26; $y++) {
        for (my $x = 0; $x < 26; $x++) {
          termbox::SetCell($x, $y, 'n',
            termbox::Attribute($x+1),
            termbox::Attribute($y+1));
          termbox::SetCell($x+27, $y, 'b',
            termbox::Attribute($x+1) | termbox::AttrBold,
            termbox::Attribute(26-$y));
          termbox::SetCell($x+54, $y, 'u',
            termbox::Attribute($x+1) | termbox::AttrUnderline,
            termbox::Attribute($y+1));
        }
        termbox::SetCell(82, $y, 'd',
          termbox::Attribute($y+1),
          termbox::ColorDefault);
        termbox::SetCell(83, $y, 'd',
          termbox::ColorDefault,
          termbox::Attribute(26-$y));
      }
      last;
    };
    case: $_ == termbox::Output216 and do {
      for (my $r = 0; $r < 6; $r++) {
        for (my $g = 0; $g < 6; $g++) {
          for (my $b = 0; $b < 6; $b++) {
            my $y = $r;
            my $x = $g + 6*$b;
            my $c1 = termbox::Attribute(1 + $r*36 + $g*6 + $b);
            my $bg = termbox::Attribute(1 + $g*36 + $b*6 + $r);
            my $c2 = termbox::Attribute(1 + $b*36 + $r*6 + $g);
            my $bc1 = $c1 | termbox::AttrBold;
            my $uc1 = $c1 | termbox::AttrUnderline;
            my $bc2 = $c2 | termbox::AttrBold;
            my $uc2 = $c2 | termbox::AttrUnderline;
            termbox::SetCell($x, $y, 'n', $c1, $bg);
            termbox::SetCell($x, $y+6, 'b', $bc1, $bg);
            termbox::SetCell($x, $y+12, 'u', $uc1, $bg);
            termbox::SetCell($x, $y+18, 'B', $bc1 | $uc1, $bg);
            termbox::SetCell($x+37, $y, 'n', $c2, $bg);
            termbox::SetCell($x+37, $y+6, 'b', $bc2, $bg);
            termbox::SetCell($x+37, $y+12, 'u', $uc2, $bg);
            termbox::SetCell($x+37, $y+18, 'B', $bc2 | $uc2, $bg);
          }
          my $c1 = termbox::Attribute(1 + $g*6 + $r*36);
          my $c2 = termbox::Attribute(6 + $g*6 + $r*36);
          termbox::SetCell(74+$g, $r, 'd', $c1, termbox::ColorDefault);
          termbox::SetCell(74+$g, $r+6, 'd', $c2, termbox::ColorDefault);
          termbox::SetCell(74+$g, $r+12, 'd', termbox::ColorDefault, $c1);
          termbox::SetCell(74+$g, $r+18, 'd', termbox::ColorDefault, $c2);
        }
      }
      last;
    };
    case: $_ == termbox::Output256 and do {
      for (my $y = 0; $y < 4; $y++) {
        for (my $x = 0; $x < 8; $x++) {
          for (my $z = 0; $z < 8; $z++) {
            my $bg = termbox::Attribute(1 + $y*64 + $x*8 + $z);
            my $c1 = termbox::Attribute(256 - $y*64 - $x*8 - $z);
            my $c2 = termbox::Attribute(1 + $y*64 + $z*8 + $x);
            my $c3 = termbox::Attribute(256 - $y*64 - $z*8 - $x);
            my $c4 = termbox::Attribute(1 + $y*64 + $x*4 + $z*4);
            my $bold = $c2 | termbox::AttrBold;
            my $under = $c3 | termbox::AttrUnderline;
            my $both = $c1 | termbox::AttrBold | termbox::AttrUnderline;
            termbox::SetCell($z+8*$x, $y, ' ', 0, $bg);
            termbox::SetCell($z+8*$x, $y+5, 'n', $c4, $bg);
            termbox::SetCell($z+8*$x, $y+10, 'b', $bold, $bg);
            termbox::SetCell($z+8*$x, $y+15, 'u', $under, $bg);
            termbox::SetCell($z+8*$x, $y+20, 'B', $both, $bg);
          }
        }
      }
      for (my $x = 0; $x < 12; $x++) {
        for (my $y = 0; $y < 2; $y++) {
          my $c1 = termbox::Attribute(233 + $y*12 + $x);
          termbox::SetCell(66+$x, $y, 'd', $c1, termbox::ColorDefault);
          termbox::SetCell(66+$x, 2+$y, 'd', termbox::ColorDefault, $c1);
        }
      }
      for (my $x = 0; $x < 6; $x++) {
        for (my $y = 0; $y < 6; $y++) {
          my $c1 = termbox::Attribute(17 + $x*6 + $y*36);
          my $c2 = termbox::Attribute(17 + 5 + $x*6 + $y*36);
          termbox::SetCell(66+$x, 6+$y, 'd', $c1, termbox::ColorDefault);
          termbox::SetCell(66+$x, 12+$y, 'd', $c2, termbox::ColorDefault);
          termbox::SetCell(72+$x, 6+$y, 'd', termbox::ColorDefault, $c1);
          termbox::SetCell(72+$x, 12+$y, 'd', termbox::ColorDefault, $c2);
        }
      }
      last;
    };
  }

  termbox::Flush();
  return;
}

my $available_modes = [
  termbox::OutputNormal,
  termbox::OutputGrayscale,
  termbox::Output216,
  termbox::Output256,
];

my $output_mode_index = 0;

sub switch_output_mode { # void ($direction)
  my ($direction) = @_;
  $output_mode_index += $direction;
  if ($output_mode_index < 0) {
    $output_mode_index = scalar(@$available_modes) - 1;
  } elsif ($output_mode_index >= scalar(@$available_modes)) {
    $output_mode_index = 0;
  }
  $output_mode = termbox::SetOutputMode($available_modes->[$output_mode_index]);
  termbox::Clear(termbox::ColorDefault, termbox::ColorDefault);
  termbox::Sync();
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

  draw_all();

loop:
  for (;;) {
    switch: my $ev = termbox::PollEvent(); for ($ev->{Type}//0) {
      case: $_ == termbox::EventKey and do {
        switch: for ($ev->{Key}//0) {
          case: $_ == termbox::KeyEsc and do {
            last loop;
          };
          case: $_ == termbox::KeyArrowUp || $_ == termbox::KeyArrowRight and do {
            switch_output_mode(1);
            draw_all();
            last;
          };
          case: $_ == termbox::KeyArrowDown || $_ == termbox::KeyArrowLeft and do {
            switch_output_mode(-1);
            draw_all();
            last;
          };
        }
        last;
      };
      case: $_ == termbox::EventResize and do {
        draw_all();
        last;
      };
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

output.pl - sample script that shows the termbox output modes.

=head1 SYNOPSIS

  perl example/output.pl

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
