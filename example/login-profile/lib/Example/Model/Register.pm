package Example::Model::Register;

use Moo;
use Valiant::Validations;

has 'username' => (
  is => 'ro',
  validates => [presence=>1, length=>[3,24], format=>'alpha'],
);

has 'password' => (
  is => 'ro',
  validates => [presence=>1, length=>[6,24], confirmation=>1],
);

has 'first_name' => (is => 'ro');
has 'last_name' => (is => 'ro');
has 'address' => (is => 'ro');
has 'city' => (is => 'ro');
has 'state' => (is => 'ro');
has 'zip' => (is => 'ro');

validates first_name => (presence=>1, length=>[2,24]);
validates last_name => (presence=>1, length=>[2,48]);
validates address => (presence=>1, length=>[2,48]);
validates city => (presence=>1, length=>[2,32]);
validates state => (presence=>1, length=>[2,18]);
validates zip => (presence=>1, format=>'zip');

sub ACCEPT_CONTEXT {
  my ($class, $c) = @_;
  my $model = $class->new($c->req->body_parameters);
  if($c->req->method eq 'POST') {
    if($model->invalid) {
      use Devel::Dwarn;
      Dwarn +{ $model->errors->to_hash };
    } else {
      $c->model('Schema::Person')
        ->create({
          username => $model->username,
          password => $model->password,
          first_name => $model->first_name,
          last_name => $model->last_name,
          address => $model->address,
          city => $model->city,
          state => { name => $model->state },
          zip => $model->zip,
        });
    }
  }
  return $model;
}


1;
