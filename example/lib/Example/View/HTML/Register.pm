package Example::View::HTML::Register;

use Moose;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'div', 'a', 'fieldset';

extends 'Example::View::HTML';

has 'registration' => (is=>'ro', required=>1);

sub theme($self) {
  return +{ 
    errors_for => +{ class=>'invalid-feedback' },
    input => +{ class=>'form-control', errors_classes=>'is-invalid' },
    password => +{ class=>'form-control', errors_classes=>'is-invalid' },
    model_errors => +{ class=>'alert alert-danger', role=>'alert' },
    attributes => {
      password => {
        password => { autocomplete=>'new-password' }
      }
    },
  };
}

sub render($self, $c) {
  $c->view('HTML::Layout', page_title=>'Homepage', sub($layout) {
    $self->registration->form( +{style=>'width:35em; margin:auto', theme=>$self->theme}, sub ($reg, $fb) {
      fieldset [
        $fb->legend,
        div +{ class=>'form-group' },
          $fb->model_errors(+{ show_message_on_field_errors=>'Please fix the listed errors.' }),
        div +{ class=>'form-group' }, [
          $reg->first_name(sub($_fb) {
            $_fb->label,
            $_fb->input,
            $_fb->errors_for,
          }),
        ],
        div +{ class=>'form-group' }, [
          $reg->last_name(sub($_fb) {
            $_fb->label,
            $_fb->input,
            $_fb->errors_for,
          }),
        ],
        div +{ class=>'form-group' }, [
          $reg->username(sub($_fb) {
            $_fb->label,
            $_fb->input,
            $_fb->errors_for,
          }),
        ],
        div +{ class=>'form-group' }, [
          $reg->password(sub($_fb) {
            $_fb->label,
            $_fb->password,
            $_fb->errors_for,
          }),
        ],
        div +{ class=>'form-group' }, [
          $reg->password_confirmation(sub($_fb) {
            $_fb->label,
            $_fb->password,
            $_fb->errors_for,
          }),
        ],
        $fb->submit('Register for Account', +{class=>'btn btn-lg btn-primary btn-block'}),
        div { style=>'text-align:center' }, a { href=>'/login' }, "Login to existing account."
      ],
    }),
  });
}

__PACKAGE__->meta->make_immutable();
