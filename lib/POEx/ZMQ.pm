package POEx::ZMQ;

use Carp;
use strictures 1;

use POEx::ZMQ::FFI::Context;

use POEx::ZMQ::Constants ();
use POEx::ZMQ::Socket ();

=for Pod::Coverage import

=cut

sub import {
  my $pkg = caller;
  POEx::ZMQ::Constants->import::into($pkg, '-all');
}

sub context { shift; POEx::ZMQ::FFI::Context->new(@_) }

1;


=pod

=head1 NAME

POEx::ZMQ - Asynchronous ZeroMQ sockets for POE

=head1 SYNOPSIS

FIXME

=head1 DESCRIPTION

A L<POE> component providing L<http://www.zeromq.org|ZeroMQ> (version 3+)
integration.

=head2 METHODS

=head3 context

Returns a new L<POEx::ZMQ::FFI::Context>; C<@_> is passed through.

The context object should be shared between sockets belonging to the same
process; a forked child process should create a new context with its own set
of sockets.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
