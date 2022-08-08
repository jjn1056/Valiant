package Example::View::HTML::Register;

use Moose;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'div', 'a', 'fieldset';

extends 'Example::View::HTML';

has 'registration' => (is=>'ro', required=>1);

sub render($self, $c) {
  $c->view('HTML::Layout', page_title=>'Homepage', sub($layout) {
    $self->registration->form( +{style=>'width:35em; margin:auto', theme=>$self->theme}, sub ($reg, $fb) {
      fieldset [
        $fb->legend,

        div +{ class=>'form-group' }, $fb->model_errors,
        div +{ class=>'form-group' }, $reg->first_name,
        div +{ class=>'form-group' }, $reg->last_name,
        div +{ class=>'form-group' }, $reg->username,
        div +{ class=>'form-group' }, $reg->password,
        div +{ class=>'form-group' }, $reg->password_confirmation,

        $fb->submit('Register for Account', +{class=>'btn btn-lg btn-primary btn-block'}),
      ],
      div { style=>'text-align:center' }, a { href=>'/login' }, "Login to existing account."
    }),
  });
}

__PACKAGE__->meta->make_immutable();
