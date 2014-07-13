package POEx::ZMQ::Role::Socket;

use v5.10;
use strictures 1;
use Carp;

use IO::Handle ();
sub fdopen {
  my ($fno, $mode) = @_;
  IO::Handle->new_from_fd($fno, ($mode || 'r'))
}

use Scalar::Util 'blessed';

use Types::Standard  -types;
use POEx::ZMQ::Types -types;

use ZMQ::FFI;
# FIXME grab constants directly or via an importer pkg?


use POE;


use Moo::Role;
with 'MooX::Role::POE::Emitter';


has zeromq => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQContext,
  builder   => sub { ZMQ::FFI->new },
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
  # FIXME consider clearer & trigger that set up or tear down watchers if
  #       session is active?
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket,
  builder   => sub {
    my ($self) = @_;
    $self->zeromq->socket( $self->type )
  },
);

has _zsock_fd => (
  lazy      => 1,
  is        => 'ro',
  isa       => Int,
  clearer   => '_clear_zsock_fd',
  builder   => sub {
    my ($self) = @_;
    $self->zsock->get_fd
  },
);

has _zsock_fh => (
  lazy      => 1,
  is        => 'ro',
  clearer   => '_clear_zsock_fh',
  builder   => sub {
    my ($self) = @_;
    fdopen( $self->_zsock_fd, 'r' )
  },
);

has [qw/_zsock_connects _zsock_binds/] => (
  lazy      => 1,
  is        => 'ro',
  isa       => ArrayRef,
  builder   => sub { [] },
);


has '+event_prefix'    => ( default => sub { 'zmq_' } );
has '+register_prefix' => ( default => sub { 'ZMQ_' } );
has '+shutdown_signal' => ( default => sub { 'SHUTDOWN_ZMQ' } );

# FIXME default pluggable_type_prefixes?
#       or do we not really care?

sub start {
  my ($self) = @_;

  $self->set_object_states([
    $self => +{
      emitter_started => '_pxz_emitter_started',
      emitter_stopped => '_pxz_emitter_stopped',
      # FIXME
    },
    
    # FIXME 'defined_states' attr with builder for use by consumers
    #       to add events
    ( $self->has_object_states ? @{ $self->object_states } : () ),
  ]);

  $self->_start_emitter
}

sub stop {
  my ($self) = @_;
  $self->yield(sub { $_[OBJECT]->_shutdown_emitter })
}

around _shutdown_emitter => sub {
  my ($orig, $self) = @_;
  # FIXME shut down io watchers
};


sub _pxz_emitter_started {
  # FIXME call a watch for our ->zsock
}

sub _pxz_emitter_stopped {

}

sub get_major_vers { (shift->zeromq->version)[0] }
sub get_minor_vers { (shift->zeromq->version)[1] }

sub get_context_opt { shift->zeromq->get(@_) }
sub set_context_opt { shift->zeromq->set(@_) }

sub get_socket_opt { shift->zsock->get(@_) }
sub set_socket_opt { shift->zsock->set(@_) }

sub close { 
  my $self = shift; 
  $self->zsock->close;
  $self->emit( 'closed' )
}
sub _px_close { $_[OBJECT]->close }

sub bind { 
  my $self = shift;
  for my $endpt (@_) {
    $self->zsock->bind($endpt);
    $self->emit( bind_added => $endpt )
  }
  $self
}
sub _px_bind { $_[OBJECT]->bind(@_[ARG0 .. $#_]) }

sub connect {
  my $self = shift;
  for my $endpt (@_) {
    $self->zsock->connect($endpt);
    $self->emit( connect_added => $endpt )
  }
  $self
}
sub _px_connect { $_[OBJECT]->connect(@_[ARG0 .. $#_]) }

sub disconnect {
  my $self = shift;
  
  for my $endpt (@_) {
    $self->zsock->disconnect($_);
    $self->emit( disconnect_issued => $endpt )
  }
  $self
}
sub _px_disconnect { $_[OBJECT]->disconnect(@_[ARG0 .. $#_]) }

sub send {
  # FIXME do we want a separate send_multipart or handle it here?
  # FIXME if $self->filter, use POE::Filter serializer iface
}

sub _px_send {

}

sub _pxz_send_multipart {

}

sub _pxz_sock_watch {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $kernel->select( $self->_zsock_fh, 'zsock_ready' );
  1
}

sub _pxz_sock_unwatch {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $self->yield(sub { $_[KERNEL]->select( $self->_zsock_fh ) });
  $self->yield(sub { 
    $_[OBJECT]->_clear_zsock_fh;
    $_[OBJECT]->_clear_zsock_fd;
  });
}

sub _pxz_ready {
  # FIXME nonblocking recv
  # FIXME deserialize input if $self->filter
}


1;
