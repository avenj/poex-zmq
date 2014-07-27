package POEx::ZMQ::Socket;

use v5.10;
use strictures 1;
use Carp;

use Scalar::Util 'blessed';

use List::Objects::WithUtils;

use List::Objects::Types -types;
use POEx::ZMQ::Types     -types;
use Types::Standard      -types;

use POEx::ZMQ::Constants -all;
use POEx::ZMQ::Buffered;
use POEx::ZMQ::FFI::Context;

use POE;

use Try::Tiny;


use Moo; use MooX::late;


with 'MooX::Role::POE::Emitter';

# Emitter:
has '+event_prefix'    => ( default => sub { 'zmq_' } );
has '+shutdown_signal' => ( default => sub { 'SHUTDOWN_ZMQ' } );

# Pluggable:
has '+register_prefix' => ( default => sub { 'ZMQ_' } );


has type => (
  required  => 1,
  is        => 'ro',
  isa       => ZMQSocketType,
  coerce    => 1,
);


has context => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQContext,
  builder   => sub { POEx::ZMQ::FFI::Context->new },
);


has zsock => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket,
  clearer   => '_clear_zsock',
  builder   => sub {
    my ($self) = @_;
    $self->context->create_socket( $self->type )
  },
);

has _zsock_buf => (
  lazy      => 1,
  is        => 'ro',
  isa       => ArrayObj,
  coerce    => 1,
  writer    => '_set_zsock_buf',
  builder   => sub { [] },
);

sub get_buffered_items { shift->_zsock_buf->copy }

sub _zsock_fh { shift->zsock->get_handle }

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
    
    ( $self->has_object_states ? @{ $self->object_states } : () ),
  ]);

  $self->_start_emitter
}

sub stop {
  my ($self) = @_;
  $self->call( 'pxz_sock_unwatch' );
  $self->zsock->set_sock_opt(ZMQ_LINGER, 0);
  $self->_clear_zsock;
  $self->_shutdown_emitter;
}

sub _pxz_emitter_started {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $self->call( 'pxz_sock_watch' );
}

sub _pxz_emitter_stopped {

}


=for Pod::Coverage (?:get|set)_(?:ctx|sock)_opt

=cut

sub get_context_opt { shift->context->get_ctx_opt(@_) }
sub set_context_opt { shift->context->set_ctx_opt(@_) }
{ no warnings 'once';
  *get_ctx_opt = *get_ctx_opt;
  *set_ctx_opt = *set_ctx_opt;
}

sub get_socket_opt { shift->zsock->get_sock_opt(@_) }
sub set_socket_opt { shift->zsock->set_sock_opt(@_) }
{ no warnings 'once'; 
  *get_sock_opt = *get_socket_opt;
  *set_sock_opt = *set_socket_opt;
}

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
  my ($self, $msg, $flags) = @_;

  if (blessed $msg && $msg->isa('POEx::ZMQ::Buffered')) {
    $self->_zsock_buf->push($msg);
  } else {
    $self->_zsock_buf->push( 
      POEx::ZMQ::Buffered->new(
        item      => $msg,
        item_type => 'single',
        ( defined $flags ? (flags => $flags) : () ),
      )
    );
  }

  $self->call('pxz_nb_write');
}
sub _px_send { $_[OBJECT]->send(@_[ARG0 .. $#_]) }

sub send_multipart {
  my ($self, $parts, $flags) = @_;

  $self->_zsock_buf->push(
    POEx::ZMQ::Buffered->new(
      item      => $parts,
      item_type => 'multipart',
      ( defined $flags ? (flags => $flags) : () ),
    )
  );

  $self->call('pxz_nb_write');
}
sub _px_send_multipart { $_[OBJECT]->send_multipart(@_[ARG0 .. $#_]) }


sub _pxz_sock_watch {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $kernel->select( $self->_zsock_fh, 'pxz_ready' );
  1
}

sub _pxz_sock_unwatch {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $kernel->select( $self->_zsock_fh );
}

sub _pxz_ready {
  my ($kernel, $self) = @_[KERNEL, OBJECT];

  $self->call('pxz_nb_write');
  $self->call('pxz_nb_read');
}



sub _pxz_nb_read {
  my ($kernel, $self) = @_[KERNEL, OBJECT];

  return unless $self->zsock->has_event_pollin;

  my $recv_err;
  RECV: {
    try {
      my $msg = $self->zsock->recv(ZMQ_DONTWAIT);
      my @parts;
      while ( $self->zsock->get_sock_opt(ZMQ_RCVMORE) ) {
        push @parts, $self->zsock->recv;
      }

      if (@parts) {
        $self->emit( recv_multipart => array( $msg, @parts ) );
      } else {
        $self->emit( recv => $msg )
      }
      1
    } catch {
      my $maybe_fatal = $_;
      if (blessed $maybe_fatal) {
        my $errno = $maybe_fatal->errno;
        unless ($errno == EAGAIN || $errno == EINTR) {
          $recv_err = $maybe_fatal->errstr;
        }
      } else {
        $recv_err = $maybe_fatal;
      }
      undef
    };
  } # RECV

  confess $recv_err if $recv_err;

  $self->yield('pxz_ready');
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
        if ($errno == EAGAIN || $errno == EINTR || $errno == EFSM) {
          $self->_zsock_buf->unshift($msg);
        } else {
          $send_error = $maybe_fatal->errstr;
        }
      } else {
        $send_error = $maybe_fatal
      } 
    };
  }

  confess $send_error if defined $send_error;

  # FIXME support for a max per-buffered-item retry limit

  $self->yield('pxz_ready');
}

# FIXME monitor support

1;

=pod

=head1 NAME

POEx::ZMQ::Socket - A POE-enabled ZeroMQ socket

=head1 SYNOPSIS

  # An example ZMQ_ROUTER socket ->
  use POE;
  use POEx::ZMQ;

  POE::Session->create(
    inline_states => +{
      _start => sub {
        # Set up a Context and save it for creating sockets later:
        $_[HEAP]->{ctx} = POEx::ZMQ->context;

        # Create a ZMQ_ROUTER socket associated with our Context:
        $_[HEAP]->{rtr} = POEx::ZMQ::Socket->new(
          context => $_[HEAP]->{ctx},
          type    => ZMQ_ROUTER,
        );

        # Set up the backend socket and start accepting/emitting events:
        $_[HEAP]->{rtr}->start;

        # Bind to a local TCP endpoint:
        $_[HEAP]->{rtr}->bind( 'tcp://127.0.0.1:1234' );
      },

      zmq_recv_multipart => sub {
        # ROUTER got message from REQ;
        # parts are available as a List::Objects::WithUtils::Array ->
        my $parts = $_[ARG0];

        # ROUTER receives [ IDENTITY, NULL, MSG .. ]:
        my ($id, undef, $content) = $parts->all;

        my $response;
        # ... do work ...
        # Send a response back:
        $_[KERNEL]->post( $_[SENDER], send_multipart =>
          $id, '', $response
        );
      },
    },
  );

  POE::Kernel->run;

=head1 DESCRIPTION

An asynchronous L<POE>-powered L<ZeroMQ|http://www.zeromq.org> socket.

These objects are event emitters powered by L<MooX::Role::POE::Emitter>. That
means they come with flexible event processing / dispatch / multiplexing
options. See the L<MooX::Role::Pluggable> and L<MooX::Role::POE::Emitter>
documentation for details.

=head2 ATTRIBUTES

=head3 type

B<Required>; the socket type, as a constant.

See L<zmq_socket(3)> for details on socket types.

See L<POEx::ZMQ::Constants> for a ZeroMQ constant exporter.

=head3 context

The L<POEx::ZMQ::FFI::Context> backend context object.

=head3 zsock

The L<POEx::ZMQ::FFI::Socket> backend socket object.

=head2 METHODS

=head3 start

Start the emitter and set up the associated socket.

B<< This method must be called >> to create the backend ZeroMQ socket and start
the emitter's L<POE::Session>.

Returns the object.

=head3 stop

Stop the emitter; a L<zmq_close(3)> will be issued for the socket and
L</zsock> will be cleared.

Buffered items are not removed; L</get_buffered_items> can be used to retrieve
them for feeding to a new socket object's L</send> method. See
L<POEx::ZMQ::Buffered>.

=head3 get_buffered_items

Returns (a shallow copy of) the L<List::Objects::WithUtils::Array> containing
messages currently buffered B<on the POE component> (due to a backend ZeroMQ
socket's blocking behavior; see L<zmq_socket(3)>).

This will not return messages queued on the ZeroMQ side.

Each item is a L<POEx::ZMQ::Buffered> object; look there for attribute
documentation. These can also be fed back to L</send> after retrieval from a
dead socket, for example:

  $old_socket->stop;  # Shut down this socket
  my $pending = $old_socket->get_buffered_items;
  $new_socket->send($_) for $pending->all;

=head3 get_context_opt

Retrieve context option values.

See L<POEx::ZMQ::FFI::Context/get_ctx_opt> & L<zmq_ctx_get(3)>

=head3 set_context_opt

Set context option values.

See L<POEx::ZMQ::FFI::Context/set_ctx_opt> & L<zmq_ctx_set(3)>

=head3 get_socket_opt

  my $last_endpt = $sock->get_sock_opt( ZMQ_LAST_ENDPOINT );

Get socket option values.

See L<POEx::ZMQ::FFI::Socket/get_sock_opt> & L<zmq_getsockopt(3)>.

=head3 set_socket_opt

  $sock->set_sock_opt( ZMQ_LINGER, 0 );

Set socket option values.

See L<POEx::ZMQ::FFI::Socket/set_sock_opt> & L<zmq_setsockopt(3)>.

=head3 bind

  $sock->bind( @endpoints );

Call a L<zmq_bind(3)> for one or more specified endpoints.

A L</bind_added> event is emitted for each added endpoint.

=head3 unbind

  $sock->unbind( @endpoints );

Call a L<zmq_unbind(3)> for one or more specified endpoints.

A L</bind_removed> event is emitted for each removed endpoint.

=head3 connect

  $sock->connect( @endpoints );

Call a L<zmq_bind(3)> for one or more specified endpoints.

A L</connect_added> event is emitted for each added endpoint.

=head3 disconnect

  $sock->disconnect( @endpoints );

Call a L<zmq_disconnect(3)> for one or more specified endpoints.

A L</disconnect_issued> event is emitted for each removed endpoint.

=head3 send

  $sock->send( $msg, $flags );

Send a single-part message (without blocking).

=for comment FIXME document queuing behavior etc

=head3 send_multipart

  $sock->send_multipart( [ @parts ], $flags );
  # For example, a ROUTER sending to $id ->
  $rtr->send_multipart( [ $id, '', $msg ], $flags );

Send a multi-part message.

=for comment FIXME document queuing behavior

=head2 ACCEPTED EVENTS

These L<POE> events take the same arguments as their object-oriented
counterparts documented in L</METHODS>:

=over

=item bind

=item unbind

=item connect

=item disconnect

=item send

=item send_multipart

=back

=head2 EMITTED EVENTS

Emitted events are prefixed with the value of the
L<MooX::Role::POE::Emitter/event_prefix> attribute; by default, C<zmq_>.

=head3 bind_added

Emitted when a L</bind> is issued for an endpoint; C<$_[ARG0]> is the bound
endpoint.

=head3 bind_removed

Emitted when a L</unbind> is issued for an endpoint; C<$_[ARG0]> is the
unbound endpoint.

=head3 connect_added

Emitted when a L</connect> is issued for an endpoint; C<$_[ARG0]> is the
target endpoint.

=head3 disconnect_issued

Emitted when a L</disconnect> is issued for an endpoint; C<$_[ARG0]> is the
disconnecting endpoint.

=head3 recv

  sub zmq_recv {
    my $msg = $_[ARG0];
    $_[KERNEL]->post( $_[SENDER], send => 'bar' ) if $msg eq 'foo';
  }

Emitted when a single-part message is received; C<$_[ARG0]> is the message
item.

=head3 recv_multipart

  # A ROUTER receiving from REQ, for example:
  sub zmq_recv_multipart {
    my $parts = $_[ARG0];
    my ($id, undef, $content) = @$parts;

    my $response = 'bar' if $content eq 'foo';

    $_[KERNEL]->post( $_[SENDER], send_multipart =>
      [ $id, '', $response ]
    );
  }

Emitted when a multipart message is received; C<$_[ARG0]> is a
L<List::Objects::WithUtils::Array> array-type object containing the message
parts.

=head1 CONSUMES

L<MooX::Role::POE::Emitter>, which in turn consumes L<MooX::Role::Pluggable>.

=head1 SEE ALSO

L<zmq(7)>

L<zmq_socket(3)>

L<POEx::ZMQ::FFI::Context> for details on the ZeroMQ context backend.

L<POEx::ZMQ::FFI::Socket> for details on the ZeroMQ socket backend.

L<ZMQ::FFI> for a loop-agnostic ZeroMQ implementation.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

Licensed under the same terms as Perl.

=cut
