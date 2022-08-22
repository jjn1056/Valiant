package Example::Model::TodosQuery;

use Moo;
use CatalystX::RequestModel;
use Valiant::Validations;
use Example::Syntax;

extends 'Catalyst::Model';
content_type 'application/x-www-form-urlencoded';
content_in 'query';

has status => (is=>'ro', required=>1, default=>'all', property=>1); 
has page => (is=>'ro', required=>1, default=>1, property=>1); 

validates status => (inclusion=>[qw/all active completed/], allow_blank=>1, strict=>1);
validates page => (numericality=>'positive_integer', allow_blank=>1, strict=>1);

sub BUILD($self, $args) { $self->validate }

around 'parse_content_body', sub ($orig, $self, $c, @args) {
  my %request_args = $self->$orig($c, @args);
  my %session_args = %{ $c->model('Session')->todo_query // +{} };

  foreach my $key(qw/page status/) {
    $request_args{$key} //= $session_args{$key} if exists($session_args{$key}) && defined($session_args{$key});
    $session_args{$key} = $request_args{$key} if exists($request_args{$key}) && defined($request_args{$key});
  }
  $c->model('Session')->todo_query(\%session_args);

  return %request_args;
};

sub status_all($self) {
  return $self->status eq 'all' ? 1:0;
}

sub status_active($self) {
  return $self->status eq 'active' ? 1:0;
}

sub status_completed($self) {
  return $self->status eq 'completed' ? 1:0;
}

sub status_is($self, $value) {
  return $self->status eq $value ? 1:0;
}

1;
