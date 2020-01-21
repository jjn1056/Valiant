package MyApp::Controller::Profile;

use MyApp::Controller;

sub root : Via(../logged_in) At(profile/...) ($self, $c) {}

  sub profile : Via(root) At() ($self, $c) {
    $c->html(200, 'profile.tx');
  }

__PACKAGE__->meta->make_immutable;
