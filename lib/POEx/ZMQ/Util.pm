package POEx::ZMQ::Util;

use strictures 1;


use ZMQ::FFI;


use parent 'Exporter::Tiny';

our @EXPORT = our @EXPORT_OK = qw/
  zmq_context
/;

sub zmq_context {
  # FIXME manage singletons based on opts?
  ZMQ::FFI->new(@_)
}


1;
