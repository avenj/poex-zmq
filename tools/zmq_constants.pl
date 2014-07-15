#!/usr/bin/env perl

use feature 'say';
use strictures 1;

use List::Objects::WithUtils;

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;

my @headers = (
  'https://raw.githubusercontent.com/zeromq/zeromq3-x/master/include/zmq.h',
  'https://raw.githubusercontent.com/zeromq/zeromq4-x/master/include/zmq.h',
);

my %const;

sub parse_consts {
  my ($lines) = @_;
  die "No data?" unless $lines->has_any;
  my $defs = $lines->grep(sub { /^#define ZMQ/ });
  die "No defines?" unless $defs->has_any;
  DEF: for my $thisdef ($defs->all) {
    my (undef, $sym, $val) = split /\s+/, $thisdef;
    next DEF if $sym =~ /^ZMQ_VERSION|MAKE_VERSION/;
    if ($val =~ /[A-Z]/i) {
      if (exists $const{$val}) {
        warn "Aliasing $sym to $val\n";
        $const{$sym} = $const{$val}
      }
    } else {
      $const{$sym} = $val
    }
  }
}


for my $header (@headers) {
  my $rs = $ua->get($header);
  unless ($rs->is_success) {
    die "Failed retrieval: $header: ".$rs->status_line
  }
  parse_consts( array(split /\n|\r\n/, $rs->decoded_content) )
}


my $output = <<'HEADER';
package POEx::ZMQ::Constants;

use strict; use warnings FATAL => 'all';
use parent 'Exporter::Tiny';
our @EXPORT = our @EXPORT_ALL = qw/
HEADER

for my $constant (keys %const) {
  $output .= "  $constant\n"
}
$output .= "/;\n\n";

for my $constant (keys %const) {
  my $val = $const{$constant};
  $output .= "sub $constant () { $val }\n";
}

$output .= "\n1;\n";

print $output;

# FIXME constants generator ...
#  - static links to headers
#  - grab defines
#  - some filtering to drop things we don't want

