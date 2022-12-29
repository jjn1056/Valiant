package Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub root :Chained(/) PathPart('') CaptureArgs(0) Name(Root) ($self, $c) {
  $c->action->next($c->user);
}

  sub not_found :Chained(*Root) PathPart('') Args ($self, $c, $user, @args) {
    return $c->detach_error(404, +{error=>"Requested URL not found: @{[ $c->req->uri ]}"});
  }

  sub static :GET Chained(*Root) PathPart('static') Args ($self, $c, $user, @args) {
    return $c->serve_file('static', @args) // $c->detach_error(404, +{error=>"Requested URL not found: @{[ $c->req->uri ]}"});
  }

  sub public :Chained(*Root) PathPart('') CaptureArgs() Name(Public) ($self, $c, $user) {
    $c->action->next($user);
  }
  
  sub auth :Chained(root) PathPart('') CaptureArgs() Name(Auth) ($self, $c, $user) {
    return $c->action->next($user) if $user->authenticated;
    return $c->redirect_to_action('#login', +{post_login_redirect=>$c->req->uri}) && $c->detach;
  }

sub end :Action Does(RenderErrors) Does(RenderView) { }  # The order of the Action Roles is important!!

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;
