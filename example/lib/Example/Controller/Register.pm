package Example::Controller::Register;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

##  This data is scoped to the controller for which it makes sense, as opposed to
## how the stash is scoped to the entire request.  Plus you reduce the risk of typos
## in calling the stash which breaks stuff in hard to figure out ways.  Basically
## we have a strongly typed controller with a clear data access API.

has registration => (
  is => 'ro',
  lazy => 1,
  required => 1,
  default => sub($self) { $self->ctx->users->registration },
);

sub root :Chained(/root) PathPart(register) Args(0) Does(Verbs) View(HTML::Register)  ($self, $c) {
  return $c->redirect_to_action('#home') && $c->detach if $c->user->registered;
}

  sub GET :Action ($self, $c) { return $c->res->code(200) }

  sub POST :Action RequestModel(RegistrationRequest) ($self, $c, $request) {    
    $self->registration->register($request);  ## Avoid DBIC specific API
    return $self->registration->valid ?
      $c->redirect_to_action('#login') :
        $c->res->code(400);
  }

__PACKAGE__->meta->make_immutable; 

__END__

package Example::Controller::Register;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

has registration => (is=>'ro', lazy=>1, default=>sub($self) { $self->ctx->users->registration } );
has view => (is=>'ro', lazy=>1, default=>sub($self) { $self->ctx->view('HTML::Register', registration => $self->registration } );

sub root :Chained(/root) PathPart(register) Args(0) Does(Verbs) ($self, $c) {
  return $c->redirect_to_action('#home') && $c->detach if $c->user->registered;
}

  sub GET :Action ($self, $c) { return $self->view->set_ok }

  sub POST :Action RequestModel(RegistrationRequest) ($self, $c, $request) {    
    $self->registration->register($request);
    return $self->registration->valid ?
      $c->redirect_to_action('#login') :
        $self->view->set_bad_request;
  }

__PACKAGE__->meta->make_immutable; 

package Example::View::HTML::Register;

use Moose;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'div', 'fieldset';
use Valiant::HTML::Form 'form_for';

extends 'Example::View::HTML';

has 'registration' => (is=>'ro', required=>1);

sub render($self, $c) {
  $c->view('HTML::Layout' => page_title=>'Homepage', sub($layout) {
    form_for $self->registration, +{method=>'POST', style=>'width:35em; margin:auto', csrf_token=>$c->csrf_token }, sub ($fb) {
      fieldset [
        $fb->legend,
        div +{ class=>'form-group' },
          $fb->model_errors(+{class=>'alert alert-danger', role=>'alert'}),
        div +{ class=>'form-group' }, [
          $fb->label('first_name'),
          $fb->input('first_name', +{ class=>'form-control', errors_classes=>'is-invalid' }),
          $fb->errors_for('first_name', +{ class=>'invalid-feedback' }),
        ],
        div +{ class=>'form-group' }, [
          $fb->label('last_name'),
          $fb->input('last_name', +{ class=>'form-control', errors_classes=>'is-invalid' }),
          $fb->errors_for('last_name', +{ class=>'invalid-feedback' }),
        ],
        div +{ class=>'form-group' }, [
          $fb->label('username'),
          $fb->input('username', +{ class=>'form-control', errors_classes=>'is-invalid' }),
          $fb->errors_for('username', +{ class=>'invalid-feedback' }),
        ],
        div +{ class=>'form-group' }, [
          $fb->label('password'),
          $fb->password('password', +{ autocomplete=>'new-password', class=>'form-control', errors_classes=>'is-invalid' }),
          $fb->errors_for('password', +{ class=>'invalid-feedback' }),
        ],
        div +{ class=>'form-group' }, [
          $fb->label('password_confirmation'),
           $fb->password('password_confirmation', +{ class=>'form-control', errors_classes=>'is-invalid' }),
          $fb->errors_for('password_confirmation', +{ class=>'invalid-feedback' }),
        ],
        $fb->submit('Register for Account', +{class=>'btn btn-lg btn-primary btn-block'}),
      ],
    },
  });
}

__PACKAGE__->meta->make_immutable();
