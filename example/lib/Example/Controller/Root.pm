package Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub root :Chained(/) PathPart('') CaptureArgs(0) ($self, $c) { }

  sub not_found :Chained(root) PathPart('') Args ($self, $c, @args) {
    return $c->detach_error(404, +{error=>"Requested URL not found: @{[ $c->req->uri ]}"});
  }

  sub static :Chained(root) PathPart('static') Args {
    my ($self, $c, @args) = @_;
    return $c->serve_file('static', @args) || $c->detach_error(404);
  }

  sub public :Chained(root) PathPart('') CaptureArgs() ($self, $c) {
    return $c->next_action($c->user);
  }
  
  sub auth :Chained(root) PathPart('') CaptureArgs() Does(Authenticated) ($self, $c) {
    return $c->next_action($c->user);
  }

sub end :Action Does(RenderView) Does(RenderErrors) {}

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;
