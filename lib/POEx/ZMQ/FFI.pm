package POEx::ZMQ::FFI;

use v5.10;
use Carp;
use strictures 1;

use FFI::Raw;

use List::Objects::WithUtils;

use Try::Tiny;


sub find_soname {
  my ($class) = @_;

  state $search = array( qw/
    libzmq.so libzmq.so.3
    libzmq.dylib libzmq.3.dylib
  / );

  my $soname;
  SEARCH: for my $maybe ($search->all) {
    try {
      FFI::Raw->new(
        $maybe, zmq_version =>
          FFI::Raw::void,
          FFI::Raw::ptr,
          FFI::Raw::ptr,
          FFI::Raw::ptr,
      );
      $soname = $maybe;
    };
    last SEARCH if defined $soname
  }

  croak "Failed to locate a suitable libzmq in your linker's search path"
    unless defined $soname;

  my $vers = $class->get_version($soname);
  unless ($vers->major >= 3) {
    my $vstr = join '.', $vers->major, $vers->minor, $vers->patch;
    croak "This library requires ZeroMQ 3+ but you only have $vstr"
  }
  
  $soname
}

sub get_version {
  my ($class, $soname) = @_;
  $soname //= $class->find_soname;

  my $zmq_vers = FFI::Raw->new(
    $soname, zmq_version =>
      FFI::Raw::void,
      FFI::Raw::ptr,  # -> major
      FFI::Raw::ptr,  # -> minor 
      FFI::Raw::ptr,  # -> patch
  );
  my ($maj, $min, $pat) = map {; pack 'i!', $_ } (0, 0, 0);
  $zmq_vers->(
    map {; unpack 'L!', pack 'P', $_ } ($maj, $min, $pat)
  );
  ($maj, $min, $pat) = map {; unpack 'i!', $_ } ($maj, $min, $pat);
  hash(
    major => $maj, minor => $min, patch => $pat
  )->inflate
}


1;

=pod

=head1 NAME

POEx::ZMQ::FFI - FFI backend for the POEx::ZMQ ZeroMQ component

=head1 SYNOPSIS

FIXME

=head1 DESCRIPTION

FIXME

=head2 CLASS METHODS

=head3 find_soname

FIXME

=head3 get_version

FIXME

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

Significant portions of this code are derived from L<ZMQ::FFI> by Dylan Cali
(CPAN: CALID).

=cut
