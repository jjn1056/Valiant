package MyApp::Controller::Root;

use MyApp::Controller;

sub root : At(/...) ($self, $c) {}

  sub not_found : Via(root) At({*}) ($self, $c, @path) {
    $c->html(404, 'not_found.tx', {message=>'ffff'});
  }
  sub logged_in : Via(root) At(...) ($self, $c) {
    $c->detach('session/login') unless $c->user_exists;
  }
  
    sub home : Via(logged_in) At() ($self, $c) {
      $c->html(200, 'home.tx');
    }

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;
