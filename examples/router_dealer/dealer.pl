#!/usr/bin/env perl
use strictures 1;

my $endpt = $ARGV[0] || 'tcp://127.0.0.1:5600';

use POE;
use POEx::ZMQ;

POE::Session->create(
  inline_states => +{
    _start => sub {
      $_[HEAP]->{dlr} = POEx::ZMQ::Socket->new(type => ZMQ_DEALER)->start;
      $_[HEAP]->{dlr}->connect($endpt);
      $_[KERNEL]->delay( send_request => 1 );
    },

    send_request => sub {
      my $x = $_[ARG0] //= 0;
      $_[HEAP]->{dlr}->send_multipart(
        [ '', 'FOO', ++$x ]
      );
      $_[KERNEL]->delay( send_request => 1, $x );
    },

    zmq_recv_multipart => sub {
      # FIXME
    },
  },
);

POE::Kernel->run
