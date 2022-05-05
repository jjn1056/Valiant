package Example::HTML::Components::Register;

use Moo;
use Example::HTML::Components 'Layout', 'FormFor';
use Valiant::HTML::TagBuilder ':html';
use Example::Syntax;

with 'Valiant::HTML::Component';

has 'person' => (is=>'ro', required=>1);

sub render($self) {
  return  Layout 'Register',
            FormFor $self->person, +{method=>'POST', style=>'width:35em; margin:auto'}, sub ($fb) {
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
            };
}

1;



