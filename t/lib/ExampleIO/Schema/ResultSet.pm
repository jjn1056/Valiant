package ExampleIO::Schema::ResultSet;

use strict;
use warnings;
use base 'DBIO::ResultSet';

__PACKAGE__->load_components(qw/
  Valiant::ResultSet
/);

sub to_array {
  my ($self) = @_;
  return $self->search(
    {},
    {result_class => 'DBIO::ResultClass::HashRefInflator'}
  )->all;
}

sub debug {
  my ($self) = @_;
  $self->result_source->schema->debug;
  return $self;
}

1;
