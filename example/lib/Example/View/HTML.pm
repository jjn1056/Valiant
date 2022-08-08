package Example::View::HTML;

use Moose;
use Valiant::HTML::SafeString 'concat';
use Example::Syntax;

extends 'Catalyst::View::BasePerRequest';

sub flatten_rendered($self, @rendered) {
  return concat grep { defined($_) } @rendered;
}

sub theme($self) {
  return +{ 
    errors_for => +{ class=>'invalid-feedback' },
    input => +{ class=>'form-control', errors_classes=>'is-invalid' },
    password => +{ class=>'form-control', errors_classes=>'is-invalid' },
    model_errors => +{ class=>'alert alert-danger', role=>'alert', show_message_on_field_errors=>'Please fix the listed errors.' },
    attributes => {
      password => {
        password => { autocomplete=>'new-password' }
      }
    },
  };
}

__PACKAGE__->config(
  content_type=>'text/html',
);
