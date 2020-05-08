package Example::Model::Authenticate;

use Moo;
use Valiant::Validations;

has 'username' => (is => 'ro');
has 'password' => (is => 'ro');

validates username => (presence=>1, length=>[3,24], format=>'alpha_numeric');
validates password => (presence=>1, length=>[6,24]);

sub ACCEPT_CONTEXT {
  my ($class, $c) = @_;
  if($c->req->method eq 'POST') {
    my $model = $class->new($c->req->body_parameters);
    if($model->valid) {
      $model->errors->add(undef, "Incorrect Credentials") 
        unless $c->authenticate(+{
          username=>$model->username,
          password=>$model->password
        });
    }
  }
  return $class->new;
}

sub user_authenticated {
  my $self = shift;
  return $self->validated && $self->valid;
}

1;
