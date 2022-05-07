package Example::Controller::Register;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub root :Chained(/root) PathPart(register) Args(0) Does(Verbs)  ($self, $c) {
  $c->redirect_to_action('#home') if $c->user;
}

  sub GET :Action ($self, $c) {
    my $person = $c->model('Schema::Person')
      ->new_result(+{})
      ->csrf_token($c->csrf_token);
    return $c->view('Components::Register', person=>$person)->http_ok;
  }

  sub POST :Action ($self, $c) {
    return $c->detach_error(400) unless $c->check_csrf_token;
    my %params = $c->structured_body(
      ['person'], 
      'username', 'first_name', 'last_name', 
      'password', 'password_confirmation'
    )->to_hash;

    my $person = $c->model('Schema::Person')
      ->create(\%params)
      ->csrf_token($c->csrf_token);

    return $c->redirect_to_action('#login') if $person->valid;
    return $c->view('Components::Register', person=>$person)->http_bad_request;
  }

__PACKAGE__->meta->make_immutable;

