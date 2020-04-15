package Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub root :Chained(/) PathPart('') CaptureArgs(0) {} 

  sub not_found :Chained(root) PathPart('') Args { }

  sub authenticate :Chained(root) PathPart('') CaptureArgs() {
    my ($self, $c) = @_;
    $c->forward('/session/authenticate');
  }

    sub home :Chained(authenticate) PathPart('') Args(0) {
      my ($self, $c) = @_;
      #$c->model('Schema')->schema->diff($c->path_to('sql/schemas'));
    }

    sub profile :Chained(authenticate) PathPart(profile) Args(0) {
      my ($self, $c) = @_;
    }

sub end : ActionClass('RenderView') {}

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;

