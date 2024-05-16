#!perl
# ------------------------------------------------------------------------
#
#   Script to rebuild wcwidth tables
#
#   Code based on build.raku
#   https://github.com/bluebear94/Terminal-WCWidth/pull/6#issue-597471192
#
#   Copyright (c) 2020 José Joaquín Atria <https://github.com/jjatria>
#
# ------------------------------------------------------------------------
#   Author: 2024 J. Schneider
# ------------------------------------------------------------------------

use 5.014;
use strict;
use warnings;

use autodie;
use charnames ();
use FindBin qw( $Bin );
use LWP;
use POSIX;

use constant TARGET => "$Bin/../lib/Termbox/Go/WCWidth/Tables.pm";

BEGIN {
  $ENV{PERL_LWP_ENV_PROXY} = 1;
  $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
}
my $ua = LWP::UserAgent->new();

sub get_content {
  my ($url) = @_;
  my $req = HTTP::Request->new('GET', $url);
  my $response = $ua->request($req);
  if ($response->is_success) {
    return $response->content;
  } elsif ($url =~ /([^\/]+?\.txt$)/) {
    my $filename = $1;
    warn $response->status_line;
    open(my $fh, '<', "$Bin/$filename");
    my $content = '';
    while (defined($_ = <$fh>)) {
      $content .= $_;
    }
    close($fh);
    return $content;
  } else {
    die $response->status_line;
  }
}

sub parse {
  my ($haystack, $needle) = @_;
  my ($source, $date, $values);

  for my $line (split /\n/, $haystack) {
    $source //= $1 if $line =~ /^# (.+)/;
    $date   //= $1 if $line =~ /^# Date: (.+)/;

    next if $line =~ /^#/;

    # START..END;PROP
    #     or
    # START;PROP
    next unless $line =~ /^([[:xdigit:]]+)[\.]{0,2}([[:xdigit:]]*)\s*;\s*(\w+)/;

    my $prop = $3;
    my ($start, $end) = ($1, $2);

    next unless $prop && $prop =~ /^$needle$/;

    $end ||= $start;

    $values->{hex($start)} = hex($end);
  }

  die "Did not parse any values from $haystack" unless values %$values;

  return ( $date, $source, $values );
}

sub make_table { # void ($fh, $variable, $date, $source, @values)
  my ($fh, $variable, $date, $source, $values) = @_;
  my $now = POSIX::strftime("%Y-%m-%d, %H:%M:%S GMT", gmtime);
  $fh->print(<<TABLE
# Generated: $now
# Source: $source
# Date: $date
use constant $variable => [
TABLE
  );

  foreach (sort {$a <=> $b} keys %$values) {
    my ($start, $end) = ($_, $values->{$_});
    my $line = sprintf(
      "[0x%04x, 0x%04x],   # %-24.24s..%-.24s",
      $start,
      $end,
      charnames::viacode($start)  // sprintf("%04X", $start),
      charnames::viacode($end)    // sprintf("%04X", $end),
    );

    $line =~ s/^\s+|\s+$//g;
    $fh->say("  $line");
  }

  $fh->say("];\n");
  return;
}

sub write_table { # void ($fh, $url, $var, $needle)
  my ($fh, $url, $var, $needle) = @_;
  my $content = get_content( 'https://www.unicode.org/Public/UNIDATA/' . $url);
  my ($date, $source, $values) = parse($content, $needle);
  make_table($fh, $var, $date, $source, $values);
  return;
}

sub main { # $ ()
  my $content = '';
  open(my $fh, ">", \$content);
  $fh->say(<<HEADER
package Termbox::Go::WCWidth::Tables;

use Exporter qw( import );
our \@EXPORT = qw(
  ZERO_WIDTH
  WIDE_EASTASIAN
);

# Generated by $0
HEADER
  );
  write_table($fh, 'extracted/DerivedGeneralCategory.txt', 'ZERO_WIDTH', qr/M[en]/);
  write_table($fh, 'EastAsianWidth.txt', 'WIDE_EASTASIAN', qr/W|F/);
  $fh->say("1;");
  close($fh);

  open($fh, '>', TARGET);
  $fh->print($content);
  close($fh);

  return 0;
}

exit main($#ARGV, $0, @ARGV);
