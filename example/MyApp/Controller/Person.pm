package MyApp::Controller::Person;

use MyApp::Controller;

sub root : Via(../root) At(...) ($self, $c) {}

  sub create_person : Via(root) At(person) ($self, $c) {
    return $c->redirect_to_action('../home') if $c->user_exists;
    return $c->html(200, 'person.tx') unless $c->req->method eq 'POST';

    my $person = $c->model(PersonForm => %{$c->req->body_parameters}{qw/username password/});

    return $c->html(200, 'person.tx', +{person=>$person}) unless $person->valid;

    $c->model('Schema::Person')->create({
      username => $person->username,
      password => $person->password});

    return $c->redirect_to_action('../session/login'); 
  }

__PACKAGE__->meta->make_immutable;
