package POEx::ZMQ::FFI::Socket;

use Carp;
use strictures 1;

use Types::Standard  -types;
use POEx::ZMQ::Types -types;


sub OPTVAL_MAXLEN () { 256 }

sub T_INT { 0 }
sub T_BIN { 1 }
sub T_STR { 2 }


use Moo; use MooX::late;


has context => (
  required  => 1,
  is        => 'ro',
  isa       => InstanceOf['POEx::ZMQ::FFI::Context'],
);

has type    => (
  required  => 1,
  is        => 'ro',
  isa       => ZMQSocketType,
);

has soname  => (
  required  => 1,
  is        => 'ro',
  isa       => Str,
);


has _ffi => (
  is        => 'ro',
  isa       => InstanceOf['POEx::ZMQ::FFI::Callable'],
  builder   => sub {
    my $soname = shift->soname;
    POEx::ZMQ::FFI::Callable->new(
      # FIXME
    )
  },
);

has _socket_ptr => (
  lazy      => 1,
  is        => 'ro',
  writer    => '_set_socket_ptr',
  builder   => sub {
    # FIXME
  },
);


with 'POEx::ZMQ::FFI::Role::ErrorChecking';



sub get_sock_opt {
  my ($self, $opt, $type) = @_;
  my ($val, $ptr, $len);

  if ($type eq 'binary' || $type eq 'string') {
    $ptr = FFI::Raw::memptr( OPTVAL_MAXLEN );
    $len = pack 'L!', OPTVAL_MAXLEN;
  } else {
    $val = POEx::ZMQ::FFI->zpack($type, 0);
    $ptr = unpack 'L!', pack 'P', $val;
    $len = pack 'L!', length $val;
  }

  my $len_ptr = unpack 'L!', pack 'P', $len;
  $self->throw_if_error( zmq_getsockopt =>
    $self->_ffi->zmq_getsockopt(
      $self->_socket_ptr, $opt, $ptr, $len_ptr
    )
  );

  POEx::ZMQ::FFI->zunpack($type, $val, $ptr, $len)
}

sub set_sock_opt {
  my ($self, $opt, $val, $type) = @_;
  # FIXME state hash containing some common OPT => TYPE mappings?
  #  try to find $type for $opt if none specified
}


sub get_handle {
  require IO::Handle;
  my $fno = $self->get_sock_opt( ZMQ_FD, 'int' );
  IO::Handle->new_from_fd( $fno, 'r' )
}

sub get_identity {

}

sub set_identity {

}

sub subscribe {

}

sub unsubscribe {

}


sub connect {

}

sub disconnect {

}

sub bind {

}

sub unbind {

}

sub send {

}

sub send_multipart {

}

sub recv {

}

sub recv_multipart {

}

1;
