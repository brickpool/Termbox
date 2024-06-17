#!perl
use 5.014;
use warnings;

require bytes;
use Encode;
use Getopt::Long qw( GetOptions );
use Pod::Usage;
use utf8;
use Unicode::EastAsianWidth::Detect qw( is_cjk_lang );

use lib '../lib', 'lib';
use Termbox::Go;
use Termbox::Go::WCWidth qw( wcswidth );

sub tbprint { # void ($x, $y, $fg, $bg, $msg)
  my ($x, $y, $fg, $bg, $msg) = @_;
  for my $c (split //, $msg) {
    termbox::SetCell($x, $y, $c, $fg, $bg);
    $x += wcswidth($c);
  }
  return;
}

sub fill { # void ($x, $y, $w, $h, \%cell)
  my ($x, $y, $w, $h, $cell) = @_;
  for (my $ly = 0; $ly < $h; $ly++) {
    for (my $lx = 0; $lx < $w; $lx++) {
      termbox::SetCell($x+$lx, $y+$ly, chr($cell->{Ch}), $cell->{Fg}, $cell->{Bg});
    }
  }
  return;
}

sub rune_advance_len { # $len ($r, $pos)
  my ($r, $pos) = @_;
  if ($r eq "\t") {
    return EditBox::tabstop_length() - $pos % EditBox::tabstop_length();
  }
  return wcswidth($r);
}

sub voffset_coffset { # $voffset, $coffset ($text, $boffset)
  my ($text, $boffset) = @_;
  my ($coffset, $voffset) = (0, 0);
  $text = bytes::substr($text, 0, $boffset);
  while (bytes::length($text) > 0) {
    my $r = substr(Encode::decode('UTF-8' => $text), 0, 1);
    my $size = bytes::length($r);
    $text = bytes::substr($text, $size);
    $coffset += 1;
    $voffset += rune_advance_len($r, $voffset);
  }
  return ($voffset, $coffset);
}

sub byte_slice_grow { # $octets ($s, $desired_cap)
  my ($s, $desired_cap) = @_;
  if (bytes::length($s) < $desired_cap) {
    my $ns = "\0" x $desired_cap;
    bytes::substr($ns, 0, bytes::length($s), $s);
    return $ns;
  }
  return $s;
}

sub byte_slice_remove { # $octets ($text, $from, $to)
  my ($text, $from, $to) = @_;
  my $size = $to - $from;
  bytes::substr($text, $from, $size, '');
  return $text;
}

sub byte_slice_insert { # $octets ($text, $offset, $what)
  my ($text, $offset, $what) = @_;
  bytes::substr($text, $offset, 0, $what);
  return $text
}

package EditBox {

use 5.014;
use warnings;

require bytes;
use Encode;
use POSIX qw( :errno_h );

use Termbox::Go::WCWidth qw( wcswidth );

use constant preferred_horizontal_threshold => 5;
use constant tabstop_length => 8;

sub new { # $eb ($class, |\%)
  state $EditBox = {
    text            => '',
    line_voffset    => 0,
    cursor_boffset  => 0, # cursor offset in bytes
    cursor_voffset  => 0, # visual cursor offset in termbox cells
    cursor_coffset  => 0, # cursor offset in unicode code points
  };
  my $class = shift // die $! = EINVAL;
  return bless { %$EditBox }, $class if @_ == 0;
  if (@_ == 1) {
    return bless {
      map { $_ => $_[0]->{$_} // $EditBox->{$_} } keys %$EditBox
    }, $class;
  } else {
    return bless {
      map { $_ => shift // $EditBox->{$_} } keys %$EditBox
    }, $class;
  }
}

# Draws the EditBox in the given location, 'h' is not used at the moment
sub Draw { # void ($self, $x, $y, $w, $h)
  my ($eb, $x, $y, $w, $h) = @_;
  $eb->AdjustVOffset($w);

  use constant coldef => termbox::ColorDefault;
  use constant colred => termbox::ColorRed;
  use constant NBSP => 160; # Unicode No-Break Space

  # To avoid artifacts, the front buffer should not be filled with spaces 
  # and default color. 
  ::fill($x, $y, $w, $h, termbox::Cell{Ch => NBSP, Fg => coldef, Bg => coldef});

  my $t = $eb->{text};
  my $lx = 0;
  my $tabstop = 0;
  for (;;) {
    my $rx = $lx - $eb->{line_voffset};
    if (bytes::length($t) == 0) {
      last;
    }

    if ($lx == $tabstop) {
      $tabstop += tabstop_length;
    }

    if ($rx >= $w) {
      termbox::SetCell($x+$w-1, $y, $::arrowRight,
        colred, coldef);
      last;
    }
    my $r = substr(Encode::decode('UTF-8' => $t), 0, 1);
    my $size = bytes::length($r);
    if ($r eq "\t") {
      for (; $lx < $tabstop; $lx++) {
        $rx = $lx - $eb->{line_voffset};
        if ($rx >= $w) {
          goto next
        }

        if ($rx >= 0) {
          termbox::SetCell($x+$rx, $y, ' ', coldef, coldef);
        }
      }
    } else {
      if ($rx >= 0) {
        termbox::SetCell($x+$rx, $y, $r, coldef, coldef);
      }
      $lx += wcswidth($r);
    }
  next:
    $t = bytes::substr($t, $size);
  }

  if ($eb->{line_voffset} != 0) {
    termbox::SetCell($x, $y, $::arrowLeft, colred, coldef);
  }
  return;
}

# Adjusts line visual offset to a proper value depending on width
sub AdjustVOffset { # void ($self, $width)
  my ($eb, $width) = @_;
  my $ht = preferred_horizontal_threshold;
  my $max_h_threshold = int(($width - 1) / 2);
  if ($ht > $max_h_threshold) {
    $ht = $max_h_threshold;
  }

  my $threshold = $width - 1;
  if ($eb->{line_voffset} != 0) {
    $threshold = $width - $ht;
  }
  if ($eb->{cursor_voffset} - $eb->{line_voffset} >= $threshold) {
    $eb->{line_voffset} = $eb->{cursor_voffset} + ($ht - $width + 1)
  }

  if ($eb->{line_voffset} != 0 && $eb->{cursor_voffset} - $eb->{line_voffset} < $ht) {
    $eb->{line_voffset} = $eb->{cursor_voffset} - $ht;
    if ($eb->{line_voffset} < 0) {
      $eb->{line_voffset} = 0;
    }
  }
  return;
}

sub MoveCursorTo { # void ($self, $boffset)
  my ($eb, $boffset) = @_;
  $eb->{cursor_boffset} = $boffset;
  ($eb->{cursor_voffset}, $eb->{cursor_coffset}) = ::voffset_coffset($eb->{text}, $boffset);
  return;
}

sub RuneUnderCursor { # $rune, $size ($self)
  my ($eb) = @_;
  my $text = bytes::substr($eb->{text}, $eb->{cursor_boffset});
  my $r = substr(Encode::decode('UTF-8' => $text), 0, 1);
  my $size = bytes::length($r);
  return ($r, $size);
}

sub RuneBeforeCursor { # $rune, $size ($self)
  my ($eb) = @_;
  my $text = bytes::substr($eb->{text}, 0, $eb->{cursor_boffset});
  my $r = substr(Encode::decode('UTF-8' => $text), -1, 1);
  my $size = bytes::length($r);
  return ($r, $size);
}

sub MoveCursorOneRuneBackward { # void ($self)
  my ($eb) = @_;
  if ($eb->{cursor_boffset} == 0) {
    return;
  }
  my (undef, $size) = $eb->RuneBeforeCursor();
  $eb->MoveCursorTo($eb->{cursor_boffset} - $size);
  return;
}

sub MoveCursorOneRuneForward { # void ($self)
  my ($eb) = @_;
  if ($eb->{cursor_boffset} == bytes::length($eb->{text})) {
    return;
  }
  my (undef, $size) = $eb->RuneUnderCursor();
  $eb->MoveCursorTo($eb->{cursor_boffset} + $size);
  return;
}

sub MoveCursorToBeginningOfTheLine { # void ($self)
  my ($eb) = @_;
  $eb->MoveCursorTo(0);
  return;
}

sub MoveCursorToEndOfTheLine { # void ($self)
  my ($eb) = @_;
  $eb->MoveCursorTo(bytes::length($eb->{text}));
  return;
}

sub DeleteRuneBackward { # void ($self)
  my ($eb) = @_;
  if ($eb->{cursor_boffset} == 0) {
    return;
  }

  $eb->MoveCursorOneRuneBackward();
  my (undef, $size) = $eb->RuneUnderCursor();
  $eb->{text} = ::byte_slice_remove($eb->{text}, $eb->{cursor_boffset}, $eb->{cursor_boffset}+$size);
  return;
}

sub DeleteRuneForward { # void ($self)
  my ($eb) = @_;
  if ($eb->{cursor_boffset} == bytes::length($eb->{text})) {
    return;
  }
  my (undef, $size) = $eb->RuneUnderCursor();
  $eb->{text} = ::byte_slice_remove($eb->{text}, $eb->{cursor_boffset}, $eb->{cursor_boffset}+$size);
  return;
}

sub DeleteTheRestOfTheLine { # void ($self)
  my ($eb) = @_;
  $eb->{text} = bytes::substr($eb->{text}, 0, $eb->{cursor_boffset});
}

sub InsertRune { # void ($self, $r)
  my ($eb, $r) = @_;
  my $buf = Encode::encode('UTF-8' => $r);
  $eb->{text} = ::byte_slice_insert($eb->{text}, $eb->{cursor_boffset}, $buf);
  $eb->MoveCursorOneRuneForward();
  return;
}

# Please, keep in mind that cursor depends on the value of line_voffset, which
# is being set on Draw() call, so.. call this method after Draw() one.
sub CursorX() { # $ ($self)
  my ($eb) = @_;
  return $eb->{cursor_voffset} - $eb->{line_voffset}
}

1;
}

my $edit_box = EditBox->new();

use constant edit_box_width => 30;

sub redraw_all { # void ()
  use constant coldef => termbox::ColorDefault;
  termbox::Clear(coldef, coldef);
  my ($w, $h) = termbox::Size();

  my $midy = int($h / 2);
  my $midx = int(($w - edit_box_width) / 2);

  # unicode box drawing chars around the edit box
  if (is_cjk_lang) {
    termbox::SetCell($midx-1, $midy, '|', coldef, coldef);
    termbox::SetCell($midx + edit_box_width, $midy, '|', coldef, coldef);
    termbox::SetCell($midx-1, $midy-1, '+', coldef, coldef);
    termbox::SetCell($midx-1, $midy+1, '+', coldef, coldef);
    termbox::SetCell($midx + edit_box_width, $midy-1, '+', coldef, coldef);
    termbox::SetCell($midx + edit_box_width, $midy+1, '+', coldef, coldef);
    fill($midx, $midy-1, edit_box_width, 1, termbox::Cell{Ch => ord('-'), Fg => coldef, Bg => coldef});
    fill($midx, $midy+1, edit_box_width, 1, termbox::Cell{Ch => ord('-'), Fg => coldef, Bg => coldef});
  } else {
    termbox::SetCell($midx-1, $midy, '│', coldef, coldef);
    termbox::SetCell($midx + edit_box_width, $midy, '│', coldef, coldef);
    termbox::SetCell($midx-1, $midy-1, '┌', coldef, coldef);
    termbox::SetCell($midx-1, $midy+1, '└', coldef, coldef);
    termbox::SetCell($midx + edit_box_width, $midy-1, '┐', coldef, coldef);
    termbox::SetCell($midx + edit_box_width, $midy+1, '┘', coldef, coldef);
    fill($midx, $midy-1, edit_box_width, 1, termbox::Cell{Ch => ord('─'), Fg => coldef, Bg => coldef});
    fill($midx, $midy+1, edit_box_width, 1, termbox::Cell{Ch => ord('─'), Fg => coldef, Bg => coldef});
  }

  $edit_box->Draw($midx, $midy, edit_box_width, 1);
  termbox::SetCursor($midx + $edit_box->CursorX(), $midy);

  tbprint($midx+6, $midy+3, coldef, coldef, "Press ESC to quit");
  termbox::Flush();
  return;
}

our $arrowLeft = '←';
our $arrowRight = '→';

INIT {
  if (is_cjk_lang) {
    $arrowLeft = '<';
    $arrowRight = '>';
  }
}

# see https://stackoverflow.com/a/670588
sub OnLeavingScope::DESTROY { ${$_[0]}->() }

sub main { # $ ()
  my $err = termbox::Init();
  if ($err != 0) {
    die $!;
  }
  my $defer = bless \\&termbox::Close, 'OnLeavingScope';
  termbox::SetInputMode(termbox::InputEsc);

  redraw_all();
mainloop:
  for (;;) {
    switch: my $ev = termbox::PollEvent(); for ($ev->{Type}) {
      case: $_ == termbox::EventKey and do {
        local $_;
        switch: for ($ev->{Key}) {
          case: $_ == termbox::KeyEsc and do {
            last mainloop;
          };
          case: $_ == termbox::KeyArrowLeft || $_ == termbox::KeyCtrlB and do {
            $edit_box->MoveCursorOneRuneBackward();
            last;
          };
          case: $_ == termbox::KeyArrowRight || $_ == termbox::KeyCtrlF and do {
            $edit_box->MoveCursorOneRuneForward();
            last;
          };
          case: $_ == termbox::KeyBackspace || $_ == termbox::KeyBackspace2 and do {
            $edit_box->DeleteRuneBackward();
            last;
          };
          case: $_ == termbox::KeyDelete || $_ == termbox::KeyCtrlD and do {
            $edit_box->DeleteRuneForward();
            last;
          };
          case: $_ == termbox::KeyTab and do {
            $edit_box->InsertRune("\t");
            last;
          };
          case: $_ == termbox::KeySpace and do {
            $edit_box->InsertRune(' ');
            last;
          };
          case: $_ == termbox::KeyCtrlK and do {
            $edit_box->DeleteTheRestOfTheLine();
            last;
          };
          case: $_ == termbox::KeyHome || $_ == termbox::KeyCtrlA and do {
            $edit_box->MoveCursorToBeginningOfTheLine();
            last;
          };
          case: $_ == termbox::KeyEnd || $_ == termbox::KeyCtrlE and do {
            $edit_box->MoveCursorToEndOfTheLine();
            last;
          };
          default: {
            if ($ev->{Ch} != 0) {
              $edit_box->InsertRune(chr $ev->{Ch});
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

editbox.pl - sample script for the Termbox::Go module!

=head1 SYNOPSIS

  perl example/editbox.pl

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
