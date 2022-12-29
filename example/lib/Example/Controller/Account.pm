package Example::Controller::Account;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub account :Chained(*Auth) CaptureArgs(0)  ($self, $c, $user) {
  $c->view('HTML::Account', account => my $account = $user->account);
  $c->action->next($account);
}

  sub view :GET Chained(account) PathPart('') Args(0) ($self, $c, $account) {
    return  $c->view->set_http_ok;
  }

  sub edit :PATCH Chained(account) PathPart('') Args(0) RequestModel(AccountRequest) ($self, $c, $account, $r) {
    return $account->update_account($r)->valid ?
      $c->view->set_http_ok : 
        $c->view->set_http_bad_request;
  }

__PACKAGE__->meta->make_immutable;
