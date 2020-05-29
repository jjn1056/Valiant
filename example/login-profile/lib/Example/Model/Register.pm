package Example::Model::Register;

use Moo;

sub find_or_new_model_recursively {
  my ($class, $model, %params) = @_;
  foreach my $param (keys %params) {
    if($model->has_column($param)) {
      $model->set_column($param => $params{$param});
    } elsif($model->has_relationship($param)) {
      my $rel_data = $model->relationship_info($param);
      my $rel_type = $rel_data->{attrs}{accessor};
      if($rel_type eq 'multi') {
        my @param_rows = @{$params{$param} || die "missing $param key in params"};
        my @related_models = ();
        foreach my $param_row (@param_rows) {
          my $related_model = $model->find_or_new_related($param, $param_row);  # +{key=>'primary'}
          $class->find_or_new_model_recursively($related_model, %$param_row);
          push @related_models, $related_model;
        }
        $model->related_resultset($param)->set_cache(\@related_models);
        $model->{__valiant_related_resultset}{$param} = \@related_models; # we have a private copy
      } else {
        die "you did not write the code for relation type $rel_type for relation $param and model @{[ ref $model]}";
      }    
    } elsif($model->can($param)) {
      $model->$param($params{$param});
    } else {
      die "Not sure what to do with '$param'";
    }
  }
}

sub update_or_insert_model_recursively {
  my ($class, $model) = @_;
  $model->update_or_insert;
  foreach my $relationship ($model->relationships) {
    my $rel_data = $model->relationship_info($relationship);
    my $rev_data = $model->result_source->reverse_relationship_info($relationship);
    my $rel_type = $rel_data->{attrs}{accessor};
    if($rel_type eq 'multi') {
      my @related_results = @{ $model->{__valiant_related_resultset}{$relationship} ||[] };
      my ($reverse_related) = keys %$rev_data;
      foreach my $related_result (@related_results) {
        next if $related_result->in_storage;
        $related_result->set_from_related($reverse_related, $model);
        $class->update_or_insert_model_recursively($related_result);
      }
    } else {
      next if $model->$relationship->in_storage;
      die "you did not write the code for relation type $rel_type for relation $relationship and model @{[ ref $model]}";
    }      
  }
}

sub ACCEPT_CONTEXT {
  my ($class, $c) = @_;

  my $model = $c->model('Schema::Person')->new_result(+{});
  my $cc = $model->new_related('credit_cards', +{});
  $model->related_resultset('credit_cards')->set_cache([$cc]);
  
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

    $class->find_or_new_model_recursively($model, %params);
    $class->update_or_insert_model_recursively($model) if $model->valid;

    Dwarn +{ $model->errors->to_hash(1) };
    #Dwarn +{ $model->credit_cards->first->errors->to_hash(1) };
  }

  return $model;
}

1;

__END__

    # TODO this should be reversed (iterate over the model keys)
    foreach my $key(keys %params) {
      if($model->has_column($key)) {
        $model->set_column($key => $params{$key});
      } elsif($model->has_relationship($key)) {
        if(ref $params{$key} eq "ARRAY") {
          foreach my $record (@{$params{$key}}) {
            ## TODO this will need some sort of proxy or change
            #to store new resultsets...
            my $new = $model->find_or_new_related($key, $record);
            warn "new $new";
            use Devel::Dwarn;
            Dwarn { $new->get_columns };
            $model->related_resultset($key)->set_cache([$new]);
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

