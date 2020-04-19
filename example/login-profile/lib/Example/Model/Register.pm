package Example::Model::Register;

use Moo;
use Valiant::Validations;

has 'username' => (
  is => 'ro',
  validates => [presence=>1, length=>[3,24], format=>'alpha_numeric'],
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
  if($c->req->method eq 'POST') {
    my %params = %{$c->req->body_data}{qw/
      username
      password
      first_name
      last_name
      address
      city
      state
      zip
    /};

    use Devel::Dwarn;
    Dwarn \%params;
    
    my $model = $c->model('Schema::Person')->create(\%params);
    $model->validate;
    return $model;
  } else {
    return $c->model('Schema::Person')->new_result(+{});
  }
}

1;
