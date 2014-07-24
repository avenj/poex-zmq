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

use Try::Tiny;


use Moo; use MooX::late;


with 'MooX::Role::POE::Emitter';
has '+event_prefix'    => ( default => sub { 'zmq_' } );
has '+register_prefix' => ( default => sub { 'ZMQ_' } );
has '+shutdown_signal' => ( default => sub { 'SHUTDOWN_ZMQ' } );
# FIXME default pluggable_type_prefixes?
#       or do we not really care?


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
  predicate => 1,
  isa       => Maybe[ InstanceOf['POE::Filter'] ],
  builder   => sub { undef },
);


has zsock => (
  lazy      => 1,
  is        => 'ro',
  isa       => ZMQSocket,
  clearer   => '_clear_zsock',
  builder   => sub {
    my ($self) = @_;
    $self->zcontext->create_socket( $self->type )
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
    
    # FIXME 'defined_states' attr with builder for use by consumers
    #       to add events?
    ( $self->has_object_states ? @{ $self->object_states } : () ),
  ]);

  $self->_start_emitter
}

sub stop {
  my ($self) = @_;
  $self->call( 'pxz_sock_unwatch' );
  $self->_clear_zsock;
  $self->_shutdown_emitter;
}

sub _pxz_emitter_started {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $self->call( 'pxz_sock_watch' );
}

sub _pxz_emitter_stopped {

}


sub get_context_opt { shift->zcontext->get_ctx_opt(@_) }
sub set_context_opt { shift->zcontext->set_ctx_opt(@_) }

sub get_socket_opt { shift->zsock->get_sock_opt(@_) }
sub set_socket_opt { shift->zsock->set_sock_opt(@_) }

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

  SENDTYPE: {
    if ($self->has_filter && $self->filter) {
      my $chunks = $self->filter->put([$msg]);
      $self->_zsock_buf->push(
        POEx::ZMQ::Buffered->new(
          item        => $_,
          item_type   => 'single',
          ( defined $flags ? (flags => $flags) : () ),
        )
      ) for @$chunks;
      last SENDTYPE
    }

    if (blessed $msg && $msg->isa('POEx::ZMQ::Buffered')) {
      $self->_zsock_buf->push($msg);
      last SENDTYPE
    }

    $self->_zsock_buf->push( 
      POEx::ZMQ::Buffered->new(
        item      => $msg,
        item_type => 'single',
        ( defined $flags ? (flags => $flags) : () ),
      )
    );
  } # SENDTYPE

  $self->call('pxz_nb_write');
}
sub _px_send { $_[OBJECT]->send(@_[ARG0 .. $#_]) }

sub send_multipart {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($parts, $flags) = @_[ARG0, ARG1];

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

  # FIXME filter support

  my $recv_err;
  RECV: while (1) {
    try {
      my $msg = $self->zsock->recv(ZMQ_DONTWAIT);
      my @parts;
      while ( $self->zsock->get_sock_opt(ZMQ_RCVMORE) ) {
        push @parts, $self->zsock->recv;
      }

      # FIXME document that multipart is never automagically filtered
      #   (to avoid fucking with identities, etc)
      #   higher-level types should handle that situation
      if (@parts) {
        $self->emit( recv_multipart => [ $msg, @parts ] );
      } else {
        $self->emit( 
          recv => (
            $self->has_filter && $self->filter ?
              @{ $self->filter->get([$msg]) }
              : $msg
          )
        );
      }
    } catch {
      my $maybe_fatal = $_;
      if (blessed $maybe_fatal) {
        my $errno = $maybe_fatal->errno;
        if ($errno == EAGAIN || $errno == EINTR) {
          $self->yield('pxz_ready');
        } else {
          $recv_err = $maybe_fatal->errstr;
        }
      } else {
        $recv_err = $maybe_fatal;
      }
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
        if ($errno == EAGAIN || $errno == EINTR) {
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

  $self->yield('pxz_ready');
}

# FIXME monitor support

1;

=pod

=head1 NAME

POEx::ZMQ::Socket - A POE-enabled ZeroMQ socket

=head1 SYNOPSIS

FIXME

=head1 DESCRIPTION

=head2 ATTRIBUTES

=head3 type

B<Required>.

The socket type, as a constant (see L<POEx::ZMQ::Constants>).

=head3 filter

A L<POE::Filter> used for sending and receiving messages.

This class will only apply the filter to single-part messages, to avoid
munging socket identities and similar; higher-level subclasses should make use
of the filter if defined.

=head3 zcontext

The L<POEx::ZMQ::FFI::Context> backend context object.

=head3 zsock

The L<POEx::ZMQ::FFI::Socket> backend socket object.

=head2 METHODS

=head3 start

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

=head3 set_context_opt

=head3 get_socket_opt

=head3 set_socket_opt

=head3 bind

=head3 unbind

=head3 connect

=head3 disconnect

=head3 send

=head3 send_multipart

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

=head3 bind_added

=head3 bind_removed

=head3 connect_added

=head3 disconnect_issued

=head3 recv

=head3 recv_multipart

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
