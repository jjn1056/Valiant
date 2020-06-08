use strict;
use warnings;

package Example::Schema::Result;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components(qw/
  Helper::Row::RelationshipDWIM
  Helper::Row::SelfResultSet
  TimeStamp
  InflateColumn::DateTime/);

sub default_result_namespace { 'Liminal::Schema::Result' }

sub debug {
  my ($self) = @_;
  $self->result_source->schema->debug;
  return $self;
}

1;
