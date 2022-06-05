package Example::Controller::Account;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub root :Chained(/auth) PathPart('account') Args(0) Does(Verbs) Allow(GET,PATCH) ($self, $c) {
  my $account = $c->model('Schema::Person')->account_for($c->user);
  my $view = $c->view('Components::Account', account => $account);
  return $account, $view;
}

  sub GET :Action ($self, $c, $account, $view) { return $view->http_ok }

  sub PATCH :Action Does(RequestModel) RequestModel(AccountRequest) ($self, $c, $account, $view, $request) {
    $account->update_account($request);
    return $account->valid ? 
      $view->http_ok : 
        $view->http_bad_request;
  }

__PACKAGE__->meta->make_immutable;

