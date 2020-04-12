package Example::Model::Authenticate;

use Moo;
use Valiant::Validations;

has 'username' => (is => 'ro');
has 'password' => (is => 'ro');

validates username => (presence=>1, length=>[3,24], format=>'alpha');
validates password => (presence=>1, length=>[6,24]);

sub ACCEPT_CONTEXT {
  my ($class, $c) = @_;
  my %args = %{$c->req->body_parameters}{qw/username password/};
  my $model = $class->new(%args);
  if($c->req->method eq 'POST') {
    if($model->valid) {
      $model->errors->add(undef, "Incorrect Credentials") 
        unless $c->authenticate(+{
          username=>$model->username,
          password=>$model->password
        });
    }
  }
  return $model;
}

sub user_authenticated {
  my $self = shift;
  return $self->validated && $self->valid;
}

1;
