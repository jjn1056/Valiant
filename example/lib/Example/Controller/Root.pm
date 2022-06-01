package Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub root :Chained(/) PathPart('') CaptureArgs(0) { } 

  sub not_found :Chained(root) PathPart('') Args ($self, $c, @args) { return $c->detach_error(404) }

  sub public :Chained(root) PathPart('public') Args {
    my ($self, $c, @args) = @_;
    return $c->serve_file('public', @args) || $c->detach_error(404);
  }
  
  sub auth: Chained(root) PathPart('') CaptureArgs() ($self, $c) {
    return if $c->user;
    return $c->redirect_to_action('#login') && $c->detach;
  }
  
    sub home :Chained(auth) PathPart('') Args(0) Name(home) ($self, $c) {
      return $c->view('Components::Home')->http_ok;
    }

sub end :Action Does(RenderErrors) {}

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;
