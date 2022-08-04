package Example::Model::TodosQuery;

use Moo;
use CatalystX::RequestModel;
use Valiant::Validations;
use Example::Syntax;

extends 'Catalyst::Model';
content_type 'application/x-www-form-urlencoded';
content_in 'query';

has status => (is=>'ro', predicate=>'has_status', property=>1); 
has page => (is=>'ro', required=>1, default=>1, property=>1); 

validates status => (inclusion=>[qw/all active completed/], allow_blank=>1, strict=>1);
validates page => (numericality=>'positive_integer', allow_blank=>1, strict=>1);

sub BUILD($self, $args) { $self->validate }

around 'parse_content_body', sub ($orig, $self, $c, @args) {
  my %request_args = $self->$orig($c, @args);
  my %session_args = %{ $c->session->{todo_query_args} ||+{} };
  my %args = (%session_args, %request_args);
  $c->session->{todo_query_args} = \%args;

  return %args;
};

sub status_all($self) {
  return 1 unless $self->has_status;
  return 1 if $self->status eq 'all';
  return 0;
}

sub status_active($self) {
  return 0 unless $self->has_status;
  return 1 if $self->status eq 'active';
}

sub status_completed($self) {
  return 0 unless $self->has_status;
  return 1 if $self->status eq 'completed';
}

1;
