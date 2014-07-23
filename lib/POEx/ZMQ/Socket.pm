package POEx::ZMQ::Socket;

use v5.10;
use strictures 1;
use Carp;

use Scalar::Util 'blessed';

use List::Objects::Types -types;
use POEx::ZMQ::Types     -types;
use Types::Standard      -types;

use POEx::ZMQ::Constants -all;
use POEx::ZMQ::Buffered;
use POEx::ZMQ::FFI::Context;

use POE;


use Moo; use MooX::late;


with 'MooX::Role::POE::Emitter';
has '+event_prefix'    => ( default => sub { 'zmq_' } );
has '+register_prefix' => ( default => sub { 'ZMQ_' } );
has '+shutdown_signal' => ( default => sub { 'SHUTDOWN_ZMQ' } );


has type => (
  required  => 1,
  is        => 'ro',
  isa       => ZMQSocketType,
  coerce    => 1,
);


has zcontext => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQContext,
  builder   => sub { POEx::ZMQ::FFI::Context->new },
);

has filter => (
  lazy      => 1,
  is        => 'ro',
  isa       => Maybe[ InstanceOf['POE::Filter'] ],
  builder   => sub { undef },
);


has zsock => (
  # FIXME wrap _clear_zsock to pxz_sock_unwatch if session is active?
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket,
  clearer   => '_clear_zsock',
  builder   => sub {
    my ($self) = @_;
    $self->zcontext->create_socket( $self->type )
  },
);

has is_closed => (
  lazy      => 1,
  is        => 'ro',
  isa       => Bool,
  writer    => '_set_is_closed',
  builder   => sub { 0 },
);


has _zsock_fh => (
  lazy      => 1,
  is        => 'ro',
  isa       => FileHandle,
  clearer   => '_clear_zsock_fh',
  predicate => '_has_zsock_fh',
  builder   => sub { shift->zsock->get_handle },
);

has _zsock_buf => (
  lazy      => 1,
  is        => 'ro',
  isa       => ArrayObj,
  coerce    => 1,
  writer    => '_set_zsock_buf',
  builder   => sub { [] },
);

has [qw/_zsock_connects _zsock_binds/] => (
  lazy      => 1,
  is        => 'ro',
  isa       => ArrayObj,
  coerce    => 1,
  builder   => sub { [] },
);

# FIXME default pluggable_type_prefixes?
#       or do we not really care?

sub start {
  my ($self) = @_;

  $self->set_object_states([
    $self => +{
      emitter_started   => '_pxz_emitter_started',
      emitter_stopped   => '_pxz_emitter_stopped',

      pxz_sock_watch    => '_pxz_sock_watch',
      pxz_sock_unwatch  => '_pxz_sock_unwatch',
      pxz_ready         => '_pxz_ready',
      pxz_nb_read       => '_pxz_nb_read',
      pxz_nb_write      => '_pxz_nb_write',

      bind            => '_px_bind',
      connect         => '_px_connect',
      unbind          => '_px_unbind',
      disconnect      => '_px_disconnect',
      send            => '_px_send',
      send_multipart  => '_px_send_multipart',
    },
    
    # FIXME 'defined_states' attr with builder for use by consumers
    #       to add events?
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
  $self->call( 'pxz_sock_unwatch' );
};


sub _pxz_emitter_started {
  my ($kernel, $self) = @_[KRENEL, OBJECT];
  $self->call( 'pxz_sock_watch' );
}

sub _pxz_emitter_stopped {
  # FIXME cleanups?
}


sub get_context_opt { shift->zcontext->get_ctx_opt(@_) }
sub set_context_opt { shift->zcontext->set_ctx_opt(@_) }

sub get_socket_opt { shift->zsock->get_sock_opt(@_) }
sub set_socket_opt { shift->zsock->set_sock_opt(@_) }

sub close { 
  my $self = shift; 
  # FIXME call for a poll and yield the clear?
  $self->_clear_zsock;
  $self->_set_is_closed(1);
  $self->emit( 'closed' )
}
sub _px_close { $_[OBJECT]->close }

sub unbind {
  my $self = shift;
  for my $endpt (@_) {
    $self->zsock->unbind($endpt);
    $self->emit( bind_removed => $endpt )
  }
  $self
}
sub _px_unbind { $_[OBJECT]->unbind(@_[ARG0 .. $#_]) }

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
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($msg, $flags)   = @_[ARG0, ARG1];

  # FIXME queue filtered if $self->filter

  $self->_zsock_buf->push( 
    POEx::ZMQ::Buffered->new(
      item      => $msg,
      item_type => 'single',
      ( defined $flags ? (flags => $flags) : () ),
    )
  );

  $self->call('pxz_nb_write');
}
sub _px_send { $_[OBJECT]->send(@_[ARG0 .. $#_]) }

sub send_multipart {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($parts, $flags) = @_[ARG0, ARG1];

  # FIXME filter each part if $self->filter

  $self->_zsock_buf->push(
    POEx::ZMQ::Buffered->new(
      item      => $parts,
      item_type => 'multipart',
      ( defined $flags ? (flags => $flags) : () ),
    )
  );
}
sub _px_send_multipart { $_[OBJECT]->send_multipart(@_[ARG0 .. $#_]) }


sub _pxz_sock_watch {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $kernel->select( $self->_zsock_fh, 'zsock_ready' );
  1
}

sub _pxz_sock_unwatch {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $kernel->select( $self->_zsock_fh );
  $self->_clear_zsock_fh;
}

sub _pxz_ready {
  my ($kernel, $self) = @_[KERNEL, OBJECT];

  if ($self->zsock->has_event_pollin) {
    $self->call('nb_read');
  }

  if ($self->zsock->has_event_pollout) {
    $self->call('nb_write');
  }

}

sub _pxz_nb_read {
  my ($kernel, $self) = @_[KERNEL, OBJECT];

  my $recv_err;
  RECV: while (1) {
    try {
      my $msg = $self->zsock->recv(ZMQ_DONTWAIT);
      my @parts;
      while ( $self->zsock->get_sock_opt(ZMQ_RCVMORE) ) {
        push @parts, $self->zsock->recv;
      }

      if (@parts) {
        $self->emit( recv_multipart => [ $msg, @parts ] );
      } else {
        $self->emit( recv => $msg );
      }
    } catch {
      my $maybe_fatal = $_;
      if (blessed $maybe_fatal) {
        my $errno = $maybe_fatal->errno;
        if ($errno == EAGAIN || $errno == EINTR) {
          $self->yield('pxz_ready');
        }
      } else {
        $recv_err = $maybe_fatal;
      }
    };
  } # RECV

  # FIXME handle maybe_fatal


  # FIXME can do nb read (w/ ZMQ_DONTWAIT?)
  # FIXME deserialize input if $self->filter
}

sub _pxz_nb_write {
  my ($kernel, $self) = @_[KERNEL, OBJECT];

  return unless $self->_zsock_buf->has_any;

  my $send_error;
  until ($self->_zsock_buf->is_empty || $send_error) {
    my $msg = $self->_zsock_buf->shift;
    my $flags = $msg->flags | ZMQ_DONTWAIT;
    try {
      if ($msg->item_type eq 'single') {
        $self->zsock->send( $msg->item, $msg->flags );
      } elsif ($msg->item_type eq 'multipart') {
        $self->zsock->send_multipart( $msg->item, $msg->flags );
      }
    } catch {
      my $maybe_fatal = $_;
      if (blessed $maybe_fatal) {
        my $errno = $maybe_fatal->errno;
        if ($errno == EAGAIN || $errno == EINTR) {
          $self->_zsock_buf->unshift($msg);
          $self->yield('pxz_ready');
        }
      } else {
        $send_error = $maybe_fatal
      } 
    };
  }

  if (defined $send_error) {
    # FIXME something nasty happened, see zmq_msg_send(3)
  }

}

# FIXME monitor support

1;
