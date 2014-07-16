package POEx::ZMQ::FFI::Context;

use Carp;
use strictures 1;

use FFI::Raw;

use POEx::ZMQ::Constants 'ZMQ_IO_THREADS', 'ZMQ_MAX_SOCKETS';

use POEx::ZMQ::FFI::Callable;

use Types::Standard -types;


use Moo; use MooX::late;


has soname => (
  required  => 1,
  is        => 'ro',  
);

has threads => (
  lazy      => 1,
  is        => 'ro',
  isa       => Int,
  predicate => 1,
  builder   => sub { 1 },
);

has max_sockets => (
  lazy      => 1,
  is        => 'ro',
  isa       => Int,
  predicate => 1,
  builder   => sub { 1024 },
);


has _ffi => ( 
  lazy      => 1,
  is        => 'ro',
  isa       => InstanceOf['POEx::ZMQ::FFI::Callable'],
  builder   => sub {
    my $soname = shift->soname;
    POEx::ZMQ::FFI::Callable->new(
      zmq_ctx_new => FFI::Raw->new(
        $soname, zmq_ctx_new => 
          FFI::Raw::ptr,   # <- ctx ptr
      ),

      zmq_ctx_set => FFI::Raw->new(
        $soname, zmq_ctx_set =>
          FFI::Raw::int,   # <- rc
          FFI::Raw::ptr,   # -> ctx ptr
          FFI::Raw::int,   # -> opt (constant)
          FFI::Raw::int,   # -> opt value
      ),

      zmq_ctx_get => FFI::Raw->new(
        $soname, zmq_ctx_get =>
          FFI::Raw::int,  # <- opt value
          FFI::Raw::ptr,  # -> ctx ptr
          FFI::Raw::int,  # -> opt (constant)
      ),

      zmq_ctx_destroy => FFI::Raw->new(
        $soname, zmq_ctx_destroy =>
          FFI::Raw::int,  # <- rc
          FFI::Raw::ptr,  # -> ctx ptr
      ),
    )
  },
);

has _ctx_ptr => (
  lazy      => 1,
  is        => 'ro',
  writer    => '_set_ctx_ptr',
  builder   => sub { -1 },
);


with 'POEx::ZMQ::FFI::Role::ErrorChecking';


sub BUILD {
  my ($self) = @_;
  
  my $ctx = $self->_ffi->zmq_ctx_new // $self->throw_zmq_error('zmq_ctx_new');
  $self->_set_ctx_ptr($ctx);

  $self->set_ctx_opt(ZMQ_IO_THREADS, $self->threads) if $self->has_threads;
  $self->set_ctx_opt(ZMQ_MAX_SOCKETS, $self->max_sockets)
    if $self->has_max_sockets;
}

sub DEMOLISH {
  my ($self) = @_;
  $self->_destroy_ctx unless $self->_ctx_ptr == -1;
}


sub _destroy_ctx {
  my ($self) = @_;
  $self->throw_if_error( zmq_ctx_destroy =>
    $self->_ffi->zmq_ctx_destroy( $self->_ctx_ptr )
  );
  $self->_set_ctx_ptr(-1);
}


sub create_socket {
  my ($self, $type) = @_;
  ZMQ::FFI::Socket->new(
    context     => $self,
    type        => $type,
    soname      => $self->soname,
    err_handler => $self->err_handler, # FIXME ensure Socket consumes ErrorChecking
  )
}

sub get_ctx_opt {
  my ($self, $opt) = @_;
  my $val;
  $self->throw_if_error( zmq_ctx_get =>
    ( $val = $self->_ffi->zmq_ctx_get( $self->_ctx_ptr, $opt ) )
  );
  $val  
}

sub set_ctx_opt {
  my ($self, $opt, $val) = @_;
  $self->throw_if_error( zmq_ctx_set =>
    $self->_ffi->zmq_ctx_set( $self->_ctx_ptr, $opt, $val )
  );
}


1;
