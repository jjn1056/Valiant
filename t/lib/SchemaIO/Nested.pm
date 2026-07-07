package SchemaIO::Nested;

use base 'DBIO::Schema';

use strict;
use warnings;

our $VERSION = 1;

__PACKAGE__->load_namespaces(
  default_resultset_class => "+SchemaIO::DefaultRS");

#use DBIO::Storage::Debug::PrettyPrint;
#my $pp = DBIO::Storage::Debug::PrettyPrint->new({ profile => 'console' });

sub debug {
  my ($self) = @_;
  #  $self->storage->debugobj($pp);
  $self->storage->debug(1);
  return $self;
}

sub debug_off {
  my ($self) = @_;
  $self->storage->debugobj(undef);
  $self->storage->debug(0);
  return $self;
}


1;
