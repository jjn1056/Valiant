package Example::HTML::Components::Login;

use Moo;
use Example::HTML::Components 'Layout', 'FormFor';
use Valiant::HTML::TagBuilder ':html';
use Example::Syntax;

with 'Valiant::HTML::Component';

has 'person' => (is=>'ro', required=>1);

sub render($self) {
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
                  $fb->password('password', +{class=>'form-control' }),
                ],
                $fb->submit('Sign In', +{class=>'btn btn-lg btn-primary btn-block'}),
              ],
              div +{ class=>'text-center' },
                a +{ href=>"/register" }, 'Register',
            };
}

1;

__END__

Makes HTML like this:

<html lang="en">

  <head>
    <title>Sign In</title>
    <meta charset="utf-8">
    <meta content="width=device-width, initial-scale=1, shrink-to-fit=no" name="viewport">
    <link href="data:," rel="icon">
    <link crossorigin="anonymous" href="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css" 
      integrity="sha384-Vkoo8x4CGsO3+Hhxv8T/Q5PaXtkKtu6ug5TOeNV6gBiFeWPGFN9MuhOf23Q9Ifjh" rel="stylesheet">
  </head>

  <body>
    <form accept-charset="UTF-8" class="new_person" id="new_person" method="post" style="width:20em; margin:auto">
      <fieldset>
        <legend>Sign In</legend>
        <div class="form-group"></div>
        <div class="form-group"><label for="person_username">Username</label><input class="form-control" id="person_username" name="person.username" type="text" value=""></div>
        <div class="form-group"><label for="person_password">Password</label><input class="form-control" id="person_password" name="person.password" type="text" value=""></div><input class="btn btn-lg btn-primary btn-block" id="commit" name="commit" type="submit" value="Sign In">
      </fieldset>
      <div class="text-center"><a href="/register">Register</a></div>
    </form>
    <script crossorigin="anonymous" integrity="sha384-J6qa4849blE2+poT4WnyKhv5vZF5SrPo0iEjwBvKU7imGFAV0wwj1yYfoRSJoZ+n" src="https://code.jquery.com/jquery-3.4.1.slim.min.js"></script>
    <script crossorigin="anonymous" integrity="sha384-Q6E9RHvbIyZFJoft+2mJbHaEWldlvI9IOYy5n3zV9zzTtmI3UksdQRVvoxMfooAo" src="https://cdn.jsdelivr.net/npm/popper.js@1.16.0/dist/umd/popper.min.js"></script>
    <script crossorigin="anonymous" integrity="sha384-wfSDF2E50Y2D1uUdj0O3uMBJnjuUD4Ih7YwaYd1iqfktj0Uod8GCExl3Og8ifwB6" src="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/js/bootstrap.min.js"></script>
  </body>

</html>



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

