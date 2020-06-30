package Example::Model::Register;

use Moo;

sub persist_model_from_params_if_valid {
  my ($class, $model, $params, $opts) = @_;
  eval {
    $model->result_source->schema->txn_do(sub {
      $model->set_from_params_recursively(%$params);
      $model->mutate_recursively($model) if $model->valid(%{$opts||+{}});
    }); 1;
  } || do {
    warn $@;
    $model->errors->add(undef, 'There was a database error trying to save your form.');
  };
}

sub ACCEPT_CONTEXT {
  my ($class, $c) = @_;

  # Get a clean, empty model (Because this is a new entry).
  my $model = $c->model('Schema::Person')->build;

  if($c->req->method eq 'POST') {

    # If a post, get whitelisted params and try to process the models
    my %params = %{$c->req->body_data->{$model->model_name->param_key}}{qw/
      username
      password
      password_confirmation
      first_name
      last_name
    /};

    $class->persist_model_from_params_if_valid($model, \%params, +{context=>'registration'});

    use Devel::Dwarn;
    Dwarn \%params;
    Dwarn +{ $model->errors->to_hash(1) } if $model->errors->size;
  }

  return $model;
}

1;
