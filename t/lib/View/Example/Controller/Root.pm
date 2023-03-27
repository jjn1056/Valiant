package View::Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub root :Chained('/') PathPart('') CaptureArgs(0) {
  my ($self, $c) = @_;
  $c->stash(stash_var=>'one');
  $c->view(Hello =>
    name => 'John',
  );
} 

  sub test :Chained('root') Args(0) {
    my ($self, $c) = @_;
    $c->res->content_type('text/html');
    $c->res->body($c->view->get_rendered);
  }

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;
