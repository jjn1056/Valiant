package Example::View::HTML::Login;
 
use Moose;
use Example::Syntax;
use Valiant::HTML::TagBuilder qw(fieldset legend div a);

extends 'Example::View::HTML';
  
has 'user' => (is=>'ro', required=>1);

__PACKAGE__->views(
  layout => 'HTML::Layout',
  form => 'HTML::Form',
);

sub render($self, $c) {
  $self->layout(page_title => 'Sign In', sub($layout) {
    $self->form($self->user, +{class=>'mx-auto', style=>'width:25em'}, sub ($fb) {
      fieldset [
        legend 'Sign In',
        div +{ class=>'form-group' },
          $fb->model_errors(),
        div +{ class=>'form-group' }, [
          $fb->label('username'),
          $fb->input('username'),
        ],
        div +{ class=>'form-group' }, [
          $fb->label('password'),
          $fb->password('password'),
        ],
        $fb->submit('Sign In'),
      ],
      div +{ class=>'text-center' },
        a +{ href=>"/register" }, 'Register';    
    });
  });
}
 
__PACKAGE__->meta->make_immutable();
