package Example::HTML::Components::Login;

use Moo;
use Example::HTML::Components 'Layout', 'FormFor';
use Valiant::HTML::TagBuilder ':html';
use Example::Syntax;

with 'Valiant::HTML::Component';

has 'person' => (is=>'ro', required=>1);

sub render {
  my ($self) = @_;
  return  Layout 'Sign In',
            FormFor $self->person, +{method=>'POST', style=>'width:20em; margin:auto'}, sub ($fb) {
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
                  $fb->input('password', +{class=>'form-control' }),
                ],
                $fb->submit('Sign In', +{class=>'btn btn-lg btn-primary btn-block'}),
              ],
              div +{ class=>'text-center' },
                a +{ href=>"/register" }, 'Register',
            };
}

1;

__END__

sub render {
  my ($self) = @_;
  return  Layout 'Sign In', [
            FormFor $self->person, +{ method=>'POST', style=>'width:20em; margin:auto' }, sub($fb) {
              fieldset [
                legend 'Sign In',
                div +{ class=>'form-group' },
                  ModelErrors +{class=>'alert alert-danger', role=>'alert'},
                div +{ class=>'form-group' }, [
                  Label 'username',
                  Input 'username', +{class=>'form-control' },
                ],
                div +{ class=>'form-group' }, [
                  Label 'password',
                  Input 'password', +{class=>'form-control' },
                ],
                Submit 'Sign In', +{class=>'btn btn-lg btn-primary btn-block'},
              ],
              div +{ class=>'text-center' },
                a +{ href=>"/register" }, 'Register',
            })
          ];
}

