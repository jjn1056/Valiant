package MyApp;

use Moose;
use Catalyst qw(
  Session
  Session::State::Cookie
  Session::Store::Cookie
  Authentication
  RedirectTo
);

sub html {
  my ($c, $code, $template, $args) = @_;
  my $output = eval {
    $c->view('HTML')->render($c, $template, $args);
  } || do {
    return $c->view('HTML')->_rendering_error($c, $@);
  };
  $c->response->content_type('text/html');
  $c->response->body($output);
  $c->response->code($code);
}

__PACKAGE__->config(
  'Plugin::Session' => { storage_secret_key => 'abc123' },
  'Plugin::Authentication' => {
    default_realm => 'members',
    members => {
      credential => {
        class => 'Password',
        password_field => 'password',
        password_type => 'clear'
      },
      store => {
        class => 'Minimal',
        users => {
          john => { password=>'green59' },
          mark => { password=>'now' },
        }
      },
    },
  }
);

__PACKAGE__->setup();

