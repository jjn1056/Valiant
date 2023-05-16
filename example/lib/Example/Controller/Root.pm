package Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :At('/...') ($self, $c) {
  $c->req->on_best_media_type(
    'no_match' => sub {  $c->detach_error(415) },
    'text/html' => sub { $c->controller->view_prefix_namespace('HTML') },
    'application/json' => sub { $c->controller->view_prefix_namespace('JSON') });
  $c->action->next($c->user);
}

  sub not_found :Via('root') At('/{*}')  ($self, $c, $user, @args) {
    return $c->detach_error(404, +{error=>"Requested URL not found: @{[ $c->req->uri ]}"});
  }

  sub public :Via('root') At('/...') ($self, $c, $user) {
    $c->action->next($user);
  }

    sub static :GET Via('public') At('static/{*}') ($self, $c, $user, @args) {
      return $c->serve_file('static', @args) // $c->detach_error(404, +{error=>"Requested URL not found."});
    }
  
  sub protected :Via('root') At('/...') ($self, $c, $user) {
    return $user->authenticated ?
      $c->action->next($user) : 
        $c->redirect_to_action('/session/build') && $c->detach; 
  }

sub end :Action Does('RenderErrors') Does('RenderView') { }  # The order of the Action Roles is important!!

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;
