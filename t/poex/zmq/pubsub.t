use Test::More;
use strict; use warnings FATAL => 'all';

use List::Objects::WithUtils;

use POE;
use POEx::ZMQ;


use File::Temp ();
my $tempdir = File::Temp::tempdir(CLEANUP => 1);
my $endpt   = "ipc://$tempdir/test-poex-ffi-$$";

my $Got = hash;
my $Expected = hash(
  # 100 messages, two subscribers:
  'subscriber got message' => 200,
);


alarm 60;

POE::Session->create(
  package_states => [
    main => [ qw/
      _start
      timeout

      check_if_done

      do_subscribe
      start_publishing

      zmq_recv
    / ],
  ],
);

sub _start {
  $_[KERNEL]->sig( ALRM => 'timeout' );
  $_[KERNEL]->yield( 'check_if_done' );
  
  my $zmq = POEx::ZMQ->new;
  $_[HEAP]->{zmq} = $zmq;

  $_[HEAP]->{pub}  = $zmq->socket( type => ZMQ_PUB )
    ->start
    ->bind($endpt);

  $_[HEAP]->{subX} = $zmq->socket( type => ZMQ_SUB )
    ->start
    ->connect($endpt);
  $_[HEAP]->{subY} = $zmq->socket( type => ZMQ_SUB )
    ->start
    ->connect($endpt);

  # delay publishing to wait for slow subscribers
  $_[KERNEL]->yield( 'do_subscribe' );
  $_[KERNEL]->delay( start_publishing => 0.3 );

  # FIXME HWM tests? publish against HWM & delay subscriber
}

sub check_if_done {
  if ($Got->keys->count == $Expected->keys->count) {
    $_[HEAP]->{$_}->stop for qw/subX subY pub/;
    $_[KERNEL]->alarm_remove_all;
  } else {
    $_[KERNEL]->delay_set( check_if_done => 0.5 );
  }
}

sub timeout {
  $_[KERNEL]->alarm_remove_all;
  fail "Timed out!"; diag explain $Got; exit 1
}

sub do_subscribe {
  $_[HEAP]->{$_}->set_sock_opt(ZMQ_SUBSCRIBE, '') for qw/subX subY/;
}

sub start_publishing {
  $_[HEAP]->{pub}->send( $_ ) for 1 .. 100;
}

sub zmq_recv {
  $Got->{'subscriber got message'}++;
}

POE::Kernel->run;

is_deeply $Got, $Expected, 'async pubsub tests ok'
  or diag explain $Got;

done_testing
