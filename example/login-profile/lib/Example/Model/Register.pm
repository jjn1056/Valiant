package Example::Model::Register;

use Moo;

sub ACCEPT_CONTEXT {
  my ($class, $c) = @_;
  my $model = $c->model('Schema::Person')->new_result(+{});
  # my $cc = $c->model('Schema::CreditCard')->new_result(+{});
  
  #  $model->credit_card_rs($cc, $cc, $cc);
  #$model->add_to_credit_card_rs($cc);

  #warn $model->credit_card_rs->first->card_number;

  #$model->state($c->model('Schema::State')->new_result(+{}));

  if($c->req->method eq 'POST') {
    my %params = %{$c->req->body_data->{person}}{qw/
      username
      password
      password_confirmation
      first_name
      last_name
      address
      city
      state_id
      zip
      credit_cards
    /};

    use Devel::Dwarn;
    Dwarn \%params;

    foreach my $key(keys %params) {
      if($model->has_column($key)) {
        $model->set_column($key => $params{$key});
      } elsif($model->has_relationship($key)) {
        if(ref $params{$key} eq "ARRAY") {
          warn "array " x 100;
          foreach my $record (@{$params{$key}}) {
          ## TODO this will need some sort of proxy or change
          #to store new resultsets...
          my $new = $model->find_or_new_related($key, $record);
            $model->$key($new);

          }
        } else {
          my $new = $model->find_or_new_related($key, $params{$key});
          $model->$key($new);
        }
      } elsif($model->can($key)) {
        $model->$key($params{$key});
      } else {
        die "Not sure what to do with '$key'";
      }
    }

    $model->insert if $model->valid;

    use Devel::Dwarn; 
    Dwarn +{ $model->errors->to_hash(1) };

  }

  return $model;
}

1;
