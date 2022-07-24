package Example::Model::TodosQuery;

use Moose;
use CatalystX::RequestModel;
use Valiant::Validations;
use Example::Syntax;

extends 'Catalyst::Model';
content_type 'application/x-www-form-urlencoded';
content_in 'query';

has status => (is=>'ro', predicate=>'has_status', property=>1);   

validates status => (inclusion=>[qw/active completed/], allow_blank=>1, strict=>1);

sub BUILD($self, $args) {
  $self->validate;
}

sub is_all($self) { return $self->has_status ? 0:1 }

sub is_active($self) {
  return 0 unless $self->has_status;
  return 1 if $self->status eq 'active';
}

sub is_completed($self) {
  return 0 unless $self->has_status;
  return 1 if $self->status eq 'completed';
}


__PACKAGE__->meta->make_immutable();
