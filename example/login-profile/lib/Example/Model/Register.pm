package Example::Model::Register;

use Moo;

sub ACCEPT_CONTEXT {
  my ($class, $c) = @_;
  if($c->req->method eq 'POST') {
    my %params = %{$c->req->body_data}{qw/
      username
      password
      password_confirmation
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

    Dwarn +{ $model->errors->to_hash };

    return $model;
  } else {
    return $c->model('Schema::Person')->new_result(+{});
  }
}

1;
