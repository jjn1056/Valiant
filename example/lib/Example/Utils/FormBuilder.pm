package Example::Utils::FormBuilder;

use Moo;
extends 'Valiant::HTML::FormBuilder';

sub default_theme($self) {
  return +{ 
    errors_for => +{ class=>'invalid-feedback' },
    input => +{ class=>'form-control', errors_classes=>'is-invalid' },
    password => +{ class=>'form-control', errors_classes=>'is-invalid' },
    submit => +{ class=>'btn btn-lg btn-primary btn-block' },
    model_errors => +{ class=>'alert alert-danger', role=>'alert', show_message_on_field_errors=>'Please fix the listed errors.' },
    attributes => {
      password => {
        password => { autocomplete=>'new-password' }
      }
    },
  };
}

1;
