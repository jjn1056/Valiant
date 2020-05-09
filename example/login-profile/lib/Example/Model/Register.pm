package Example::Model::Register;

use Moo;

sub ACCEPT_CONTEXT {
  my ($class, $c) = @_;
  my $model = $c->model('Schema::Person')->new_result(+{});
  $model->state($c->model('Schema::State')->new_result(+{}));

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

    foreach my $key(keys %params) {
      if($model->has_column($key)) {
        $model->set_column($key => $params{$key});
      } elsif($model->has_relationship($key)) {
        my $new = $model->find_or_new_related($key, $params{$key});
        $model->$key($new);
      } elsif($model->can($key)) {
        $model->$key($params{$key});
      } else {
        die "Not sure what to do with '$key'";
      }
    }

    $model->insert if $model->valid;

    use Devel::Dwarn; 
    Dwarn +{ $model->errors->to_hash(1) };
    Dwarn +{ $model->state->errors->to_hash(1) };

  }

  return $model;
}

1;
