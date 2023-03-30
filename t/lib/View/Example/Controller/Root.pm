package View::Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub root :Chained('/') PathPart('') CaptureArgs(0) {
  my ($self, $c) = @_;
  $c->view(Hello =>
    name => 'John',
  );
} 

  sub test :Chained('root') Args(0) {
    my ($self, $c) = @_;
    $c->forward($c->view);
  }

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;
