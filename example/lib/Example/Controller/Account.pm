package Example::Controller::Account;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :Chained(*Secured) PathPart('account') CaptureArgs(0)  ($self, $c, $user) {
  my $account = $user->account;
  $c->action->next($account);
}

  sub setup :Chained(root) PathPart('') CaptureArgs(0) ($self, $c, $account) { 
    $c->view('HTML::Account', account => $account);
    $c->action->next($account);
  }

  sub view :GET Chained(root) PathPart('') Args(0) ($self, $c, $account) {
    return  $c->view->set_http_ok;
  }

  sub edit :PATCH Chained(root) PathPart('') Args(0) RequestModel(AccountRequest) ($self, $c, $account, $r) {
    return $account->update_account($r)->valid ?
      $c->view->set_http_ok : 
        $c->view->set_http_bad_request;
  }

__PACKAGE__->meta->make_immutable;
