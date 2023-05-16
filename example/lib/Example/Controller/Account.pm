package Example::Controller::Account;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :Via('../protected') At('account/...') ($self, $c, $user) {
  $c->action->next($user->account);
}

  sub prepare_edit :Via('root') At('...') ($self, $c, $account) { 
    $self->view_for('edit', account => $account);
    $c->action->next($account);
  }

    sub edit :GET Via('prepare_edit') At('edit') ($self, $c, $account) {
      return  $c->view->set_http_ok;
    }

    sub update :PATCH Via('prepare_edit') At('') BodyModel ($self, $c, $account, $r) {
      use Devel::Dwarn;
      Dwarn +{params => $r->nested_params};

      return $account->update_account($r) ?
        $c->view->set_http_ok : 
          $c->view->set_http_bad_request;
    }

__PACKAGE__->meta->make_immutable;