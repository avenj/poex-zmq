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


use POE;


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

has filter => (
  lazy      => 1,
  is        => 'ro',
  isa       => Maybe[ InstanceOf['POE::Filter'] ],
  builder   => sub { undef },
);


has zsock => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket,
  clearer   => 'clear_zsock',  # ffi sock auto-closes in destructor
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


sub getsockopt { shift->zsock->get(@_) }
sub setsockopt { shift->zsock->set(@_) }

# FIXME
#  - Most of these should emit events.
#  - Probably we should track connect and bind endpoints and provide a
#    disconnect_all.
#  - Probably there should be methods to handle the above and the frontendy
#    methods & events can be maybe split out to a role later.

sub close { my $self = shift; $self->zsock->close }
sub _px_close { $_[OBJECT]->close }

sub bind { my $self = shift; $self->zsock->bind($_) for @_ }
sub _px_bind { $_[OBJECT]->bind(@_[ARG0 .. $#_]) }

sub connect { my $self = shift; $self->zsock->connect($_) for @_ }
sub _px_connect { $_[OBJECT]->connect(@_[ARG0 .. $#_]) }

sub disconnect { my $self = shift; $self->zsock->disconnect($_) for @_ }
sub _px_disconnect { $_[OBJECT]->disconnect(@_[ARG0 .. $#_]) }

sub send {
  # FIXME do we want a separate send_multipart or handle it here?
  # FIXME if $self->filter, use POE::Filter serializer iface
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
