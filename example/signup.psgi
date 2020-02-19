#!/usr/local/env plackup

use Template;
use Plack::Request;
use SignUp;

my $tt = Template->new({
    INTERPOLATE => 1,
    EVAL_PERL    => 1,
}) || die $Template::ERROR, "\n";

sub post {
  my $req = shift;
  my %params = %{$req->body_parameters}{qw/
    username 
    password 
    password_confirmation
  /};

  (my $signup = SignUp->new(%params))
    ->validate;

  return $signup;
}


my $app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $signup = $req->method eq 'POST' ? post($req) : SignUp->new;

    $tt->process(\*DATA, +{model => $signup}, \my $body)
      || die $tt->error(), "\n";

    return [ 200,
      ['Content-Type'=>'text/html'],
      [$body],
    ];
};

__DATA__
<!doctype html>
<html lang="en">
  <head>
    <title>[% $title %]</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">

    <!-- Bootstrap CSS -->
    <link rel="stylesheet"
        href="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css"
        integrity="sha384-Vkoo8x4CGsO3+Hhxv8T/Q5PaXtkKtu6ug5TOeNV6gBiFeWPGFN9MuhOf23Q9Ifjh"
        crossorigin="anonymous">
    <style>
      html,
      body {
        height: 100%;
      }

      body {
        display: -ms-flexbox;
        display: -webkit-box;
        display: flex;
        -ms-flex-align: center;
        -ms-flex-pack: center;
        -webkit-box-align: center;
        align-items: center;
        -webkit-box-pack: center;
        justify-content: center;
        padding-top: 40px;
        padding-bottom: 40px;
        background-color: #f5f5f5;
      }

      .form-signin {
        width: 100%;
        max-width: 330px;
        padding: 15px;
        margin: 0 auto;
      }
      .form-signin .form-control {
        position: relative;
        box-sizing: border-box;
        height: auto;
        padding: 10px;
        font-size: 16px;
      }
      .form-signin .form-control:focus {
        z-index: 2;
      }
      .form-signin input[type="text"] {
        margin-bottom: 10px;
        border-bottom-right-radius: 0;
        border-bottom-left-radius: 0;
      }
      .form-signin #password {
        margin-bottom: -1px;
        border-top-left-radius: 0;
        border-top-right-radius: 0;
      }
      .form-signin #password_confirmation {
        margin-bottom: 10px;
        border-top-left-radius: 0;
        border-top-right-radius: 0;
      }

    </style>
  </head>
  <body>
    <form method="post" class="form-signin">
      <h1 class="h3 mb-3 font-weight-normal">[% model.human %]</h1>
      <label for="user" class="sr-only">User Name</label>
      <input type="text" id="user" class="form-control" placeholder="User Name" name='username' required autofocus>
      <label for="password" class="sr-only">Password</label>
      <input type="password" id="password" class="form-control" name='password' placeholder="Password" required>
      <input
          type="password"
          id="password_confirmation" 
          class="form-control [% model.errors.size ? 'is-invalid':'' %]" 
          name='password_confirmation' 
          placeholder="[% model.human_attribute_name('password_confirmation') %]"
          required />
      [% IF model.errors.size %]
        <div class="invalid-feedback">
          [% model.errors.full_messages_for('password_confirmation').first %]
        </div>
      [% END %]

      <button class="btn btn-lg btn-primary btn-block" type="submit">Register</button>
      <p class="mt-5 mb-3 text-muted">&copy; 2020</p>
    </form>
  <!-- Optional JavaScript -->
    <!-- jQuery first, then Popper.js, then Bootstrap JS -->
    <script src="https://code.jquery.com/jquery-3.4.1.slim.min.js"
        integrity="sha384-J6qa4849blE2+poT4WnyKhv5vZF5SrPo0iEjwBvKU7imGFAV0wwj1yYfoRSJoZ+n"
        crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/popper.js@1.16.0/dist/umd/popper.min.js"
        integrity="sha384-Q6E9RHvbIyZFJoft+2mJbHaEWldlvI9IOYy5n3zV9zzTtmI3UksdQRVvoxMfooAo"
        crossorigin="anonymous"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/js/bootstrap.min.js"
        integrity="sha384-wfSDF2E50Y2D1uUdj0O3uMBJnjuUD4Ih7YwaYd1iqfktj0Uod8GCExl3Og8ifwB6"
        crossorigin="anonymous"></script>
  </body>
</html>
