use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

class Example::Controller::Account :isa(Example::Controller) {

  sub root :At('$path_end/...') Via('../protected')  ($self, $c, $user) {
    $c->action->next($user->account);
  }

    sub prepare_edit :At('...') Via('root') ($self, $c, $account) { 
      $self->view_for('edit', account => $account);
      $c->action->next($account);
    }

      sub edit :Get('edit') Via('prepare_edit') ($self, $c, $account) {
        return  $c->view->set_http_ok;
      }

      sub update :Patch('') Via('prepare_edit') BodyModel ($self, $c, $account, $bm) {
        return $account->update_account($bm) ?
          $c->view->set_http_ok : 
            $c->view->set_http_bad_request;
      }
}

__PACKAGE__->meta->make_immutable;
