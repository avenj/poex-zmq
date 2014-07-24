use Test::More;
use strict; use warnings FATAL => 'all';

use List::Objects::WithUtils;

use POE;
use POEx::ZMQ;
use POEx::ZMQ::Constants -all;

my $endpt = "ipc:///tmp/test-poex-zmq-$$";


my $Got = hash;
my $Expected = hash(
  'rtr got 3 items'   => 1,
  'rtr got id'        => 1,
  'null part empty'   => 1,
  'multipart body ok' => 1,


);


alarm 60;

POE::Session->create(
  package_states => [
    main => [ qw/
      _start
      timeout

      router_req_setup

      zmq_connect_added
      zmq_bind_added

      zmq_recv
      zmq_recv_multipart
    / ],
  ],
);


sub _start {
  $_[KERNEL]->sig( ALRM => 'timeout' );

  $_[HEAP]->{ctx} = POEx::ZMQ->context;

  $_[HEAP]->{rtr} = POEx::ZMQ::Socket->new(
    context => $_[HEAP]->{ctx},
    type    => ZMQ_ROUTER,
  )->start;

  $_[HEAP]->{req} = POEx::ZMQ::Socket->new(
    context => $_[HEAP]->{ctx},
    type    => ZMQ_REQ,
  )->start;
  
#  $_[KERNEL]->call( $_->alias, subscribe => 'all' );

  $_[KERNEL]->yield( 'router_req_setup' );
}

sub router_req_setup {
  $_[HEAP]->{req}->connect($endpt);

  $_[HEAP]->{rtr}->bind($endpt);

  $_[HEAP]->{req}->send( 'foo' );
}

sub zmq_connect_added {
  # FIXME
}

sub zmq_bind_added {
  # FIXME
}

sub zmq_recv {
  # FIXME  
}

sub zmq_recv_multipart {
  my $parts = $_[ARG0];

  $Got->set('rtr got 3 items' => 1) if $parts->count == 3;

  my ($id, $nul, $content) = $parts->all;
  $Got->set('rtr got id' => 1) if defined $id;
  $Got->set('null part empty' => 1) if $nul eq '';
  $Got->set('multipart body ok' => 1) if $content eq 'foo';
}


sub timeout {
  $_[KERNEL]->alarm_remove_all;
  fail "Timed out!"; exit 1
}

POE::Kernel->run;

is_deeply $Got, $Expected, 'async socket tests ok'
  or diag explain $Got;

done_testing
