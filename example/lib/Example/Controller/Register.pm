package Example::Controller::Register;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub root :Chained(/root) PathPart(register) Args(0) Does(Verbs)  ($self, $c) {
  return $c->redirect_to_action('#home') if $c->user;
  my $person =  $c->model('Schema::Person')->new_result(+{});
  my $view = $c->view('Components::Register', person=>$person);
  return $person, $view;
}

  sub GET :Action ($self, $c, $person, $view) {
    return $view->http_ok;
  }

  sub POST :Action ($self, $c, $person, $view) {
    my %params = $c->structured_body(
      ['person'], 
      'username', 'first_name', 'last_name', 
      'password', 'password_confirmation'
    )->to_hash;

    $person->set_columns_recursively(\%params)->insert;

    return $person->valid ?
      $c->redirect_to_action('#login') :
        $view->http_bad_request;
  }

__PACKAGE__->meta->make_immutable;
