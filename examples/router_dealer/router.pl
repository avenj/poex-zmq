#!/usr/bin/env perl
use v5.10;
use strictures 1;
use Data::Dumper;

my $endpt = $ARGV[0] || 'tcp://127.0.0.1:5600';

use POE;
use POEx::ZMQ;

POE::Session->create(
  inline_states => +{
    _start => sub {
      $_[HEAP]->{rtr} = POEx::ZMQ::Socket
        ->new(type => ZMQ_ROUTER)
        ->start
        ->bind($endpt);
    },
    zmq_recv_multipart => sub {
      my $parts = $_[ARG0];
      my $envelope = $parts->items_before(sub { $_ eq '' });
      my $body     = $parts->items_after(sub { $_ eq '' });

      say "Received message body: ".Dumper($body);
    },
  },
);

POE::Kernel->run