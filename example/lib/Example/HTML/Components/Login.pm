package Example::HTML::Components::Login;

use Moo;
use Example::HTML::Components 'Layout', 'FormFor';
use Valiant::HTML::TagBuilder ':html';
use Example::Syntax;

with 'Valiant::HTML::Component';

has 'ctx' => (is=>'ro', required=>1);
has 'user' => (is=>'ro', required=>1, lazy=>1, default=>sub($self) { $self->ctx->controller->user } );

sub render($self) {
  return  Layout 'Sign In',
            FormFor $self->user, +{method=>'POST', style=>'width:20em; margin:auto'}, sub ($fb) {
              fieldset [
                legend 'Sign In',
                div +{ class=>'form-group' },
                  $fb->model_errors(+{class=>'alert alert-danger', role=>'alert'}),
                div +{ class=>'form-group' }, [
                  $fb->label('username'),
                  $fb->input('username', +{class=>'form-control' }),
                ],
                div +{ class=>'form-group' }, [
                  $fb->label('password'),
                  $fb->password('password', +{class=>'form-control' }),
                ],
                $fb->submit('Sign In', +{class=>'btn btn-lg btn-primary btn-block'}),
              ],
              div +{ class=>'text-center' },
                a +{ href=>"/register" }, 'Register',
            };
}

1;