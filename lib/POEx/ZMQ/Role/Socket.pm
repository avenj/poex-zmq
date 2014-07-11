package POEx::ZMQ::Role::Socket;

use strictures 1;
use Carp;

use Scalar::Util 'blessed';

use Types::Standard  -types;
use POEx::ZMQ::Types -types;


# FIXME zmq_context Util managing version-dependent singletons?
#  or just some sugar for a ZMQ::FFI->new(@_) ?
use POEx::ZMQ::Util qw/
  zmq_context
/;
# FIXME grab constants directly or via an importer pkg?


use Moo::Role;
with 'POEx::ZMQ::Role::EmitEvents';


has zeromq => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQContext,
  builder   => sub { zmq_context },
);

has type => (
  required  => 1,
  is        => 'ro',
  isa       => ZMQSocketType,
);


has zsock => (
  lazy      => 1,
  is        => 'ro',
  isa      => ZMQSocket,
  builder   => sub {
    my ($self) = @_;
    $self->zeromq->socket( $self->type )
  },
);


sub start {
  # FIXME set up attrs
  # FIXME _start_emitter
}

sub stop {
  # FIXME close out, shutdown emitter
}


sub _pxz_emitter_started {

}

sub _pxz_emitter_stopped {

}


sub opt {
  # FIXME sockopt getter/setter
}


sub connect {

}

sub _px_connect {

}


sub bind {

}

sub _px_bind {

}


sub disconnect {

}

sub _px_disconnect {

}


sub close {

}

sub _px_close {

}


sub send {

}

sub _px_send {

}


sub _pxz_sock_watch {

}

sub _pxz_sock_unwatch {

}

sub _pxz_ready {

}


1;
