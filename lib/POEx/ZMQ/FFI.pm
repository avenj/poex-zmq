package POEx::ZMQ::FFI;

use v5.10;
use Carp;
use strictures 1;

use FFI::Raw;

use List::Objects::WithUtils;

use Math::Int64 qw/
  int64_to_native uint64_to_native
  native_to_int64 native_to_uint64
/;

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
    major  => $maj,
    minor  => $min,
    patch  => $pat,
    string => join('.', $maj, $min, $pat)
  )->inflate
}


sub _begins { ! index($_[0], $_[1]) }

sub zpack {
  my ($class, $type, $val) = @_;

  # See zmq_getsockopt(3) for more on types ->
  PTYPE: {
    if ($type eq 'int') {
      return pack 'i!', $val
    }

    if ( _begins($type => 'int64') ) {
      return int64_to_native($val)
    }

    if ( _begins($type => 'uint64') ) {
      return uint64_to_native($val)
    }

    confess "Unknown type: $type"
  } # PTYPE
}

sub zunpack {
  my ($class, $type, $val, $ptr, $len) = @_;
  UTYPE: {
    if ($type eq 'int') {
      return unpack 'i!', $val
    }

    if ($type eq 'binary') {
      $len = unpack 'L!', $len;
      return if $len == 0;
      return $ptr->tostr($len)
    }

    if ($type eq 'string') {
      return $ptr->tostr
    }

    if ( _begins($type => 'int64') ) {
      return native_to_int64($val)
    }

    if ( _begins($type => 'uint64') ) {
      return native_to_uint64($val)
    }

    confess "Unknown type: $type"
  } # UTYPE
}


1;

=pod

=head1 NAME

POEx::ZMQ::FFI - Minimalist ZMQ FFI wrapper for POEx::ZMQ

=head1 SYNOPSIS

  # Used internally by POEx::ZMQ.

=head1 DESCRIPTION

This is a minimalist L<FFI::Raw> interface to L<http://www.zeromq.org|ZeroMQ>
version 3+, derived from Dylan Cali's L<ZMQ::FFI> (where you probably want to look if
you're not using L<POEx::ZMQ>.)

=head2 CLASS METHODS

=head3 find_soname

  my $soname = POEx::ZMQ::FFI->find_soname;

Attempts to find an appropriate C<libzmq> dynamic library; croaks on failure.

=head3 get_version

  my $vstruct = POEx::ZMQ::FFI->get_version;
  my $version = $vstruct->string;   # 3.2.1
  my $major = $vstruct->major;      # 3
  my $minor = $vstruct->minor;      # 2
  my $patch = $vstruct->patch;      # 1

Returns a struct-like object containing the L<zmq_version(3)> version
information.

The dynamic library name can be supplied:

  my $vstruct = POEx::ZMQ::FFI->get_version($soname);

... otherwise the library found by L</find_soname> is used.

=head3 zpack

FIXME

=head3 zunpack

FIXME

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

Significant portions of this code are derived from L<ZMQ::FFI> by Dylan Cali
(CPAN: CALID).

Licensed under the same terms as Perl.

=cut
