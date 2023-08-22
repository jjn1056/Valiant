package Example::Controller::Account;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :At('$path_end/...') Via('../protected')  ($self, $c, $user) {
  $c->action->next(my $account = $user->account);
}

  sub prepare_edit :At('...') Via('root') ($self, $c, $account) { 
    $self->view_for('edit', account => $account);
    $c->action->next($account);
  }

    # GET /account
    sub edit :Get('edit') Via('prepare_edit') ($self, $c, $account) { return }

    # PATCH /account
    sub update :Patch('') Via('prepare_edit') BodyModel ($self, $c, $account, $bm) {
      return $account->set_from_request($bm);
    }

    # Used by the form_for helper in the view. Since this controller doesn't 
    # define a 'find' action we need to discard the $model_path argument.
    sub update_account_uri($self, $model_path, @args) {
      return $self->update_uri(@args);
    }

__PACKAGE__->meta->make_immutable;
