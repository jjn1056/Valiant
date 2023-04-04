package Example::View::HTML::Login;
 
use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(fieldset form_for input legend div a),
  -util => qw($sf content_for path ),
  -views => 'HTML::Layout';

has 'user' => (is=>'ro', required=>1);
has 'post_login_redirect' => (is=>'rw', predicate=>'has_post_login_redirect');


sub action_link :Renders ($self) {
  return $self->has_post_login_redirect ?
    path('*Login', +{post_login_redirect=>$self->post_login_redirect}) :
    path('*Login');
}

sub render($self, $c) {
  html_layout page_title => 'Sign In', sub($layout) {
    form_for $self->user, +{action=>$self->action_link, class=>'mx-auto', style=>'width:25em'}, sub ($fb, $u) {
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
      input {if=>$self->has_post_login_redirect, type=>'hidden', name=>'post_login_redirect', value=>$self->post_login_redirect},
      div +{ class=>'text-center' },
        a +{ href=>"/register" }, 'Register';    
    };
  };
}
 
1;
