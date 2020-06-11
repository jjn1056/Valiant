package Example::Model::Profile;

use Moo;
use Devel::Dwarn;

sub find_or_new_model_recursively {
  my ($class, $model, %params) = @_;
  foreach my $param (keys %params) {
    # Spot to normalize serialized params (like for dates, etc).
    if($model->has_column($param)) {
      $model->set_column($param => $params{$param});
    } elsif($model->has_relationship($param)) {
      my $rel_data = $model->relationship_info($param);
      my $rel_type = $rel_data->{attrs}{accessor};
      if($rel_type eq 'multi') {
        # TODO allow array here as well for the picky
        my @param_rows = ();
        if(ref($params{$param}) eq 'HASH') {
          @param_rows = map { $params{$param}{$_} } sort { $a <=> $b} keys %{$params{$param} || +{}};
        } elsif(ref($params{$param}) eq 'ARRAY') { # It will come this way with JSON I think
          @param_rows = @{$params{$param} || +[]};
        } else {
          die "We expect $param to be some sort of reference but its not!";
        }
        my @related_models = ();

        # TODO this could be batched so we can get it all in one select
        # rather than separate ones.
        foreach my $param_row (@param_rows) {

          my $related_model = eval {
            my $new_related = $model->new_related($param, +{});
            my @primary_columns = $new_related->result_source->primary_columns;

            my %found_primary_columns = map {
              exists($param_row->{$_}) ? ($_ => $param_row->{$_}) : ();
            } @primary_columns;

            if(%found_primary_columns) {
              # TODO I don't think this is looking in the resultset cache and as a result is
              # running additional SQL queries that already have been run.
              my $found_related = $model->find_related($param, \%found_primary_columns, +{key=>'primary'});
              die "result not found" unless $found_related;
              $found_related;
            } else {
              $new_related;
            }
          } || die $@; # TODO do something useful here...
          
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
    } elsif($param eq '_destroy') {
      if($params{$param}) {
        $model->mark_for_deletion;
      }
    } else {
      die "Not sure what to do with '$param'";
    }
  }
}

sub mutate_model {
  my ($class, $model) = @_;
  if($model->is_marked_for_deletion) {
    $model->delete_if_in_storage;
  } else {
    $model->update_or_insert;
  }
}

sub mutate_model_recursively {
  my ($class, $model) = @_;
  $class->mutate_model($model);
  foreach my $relationship ($model->relationships) {
    my $rel_data = $model->relationship_info($relationship);
    my $rev_data = $model->result_source->reverse_relationship_info($relationship);
    my $rel_type = $rel_data->{attrs}{accessor};
    if($rel_type eq 'multi') {
      my @related_results = @{ $model->{__valiant_related_resultset}{$relationship} ||[] };
      my ($reverse_related) = keys %$rev_data;
      my @undeleted = ();
      foreach my $related_result (@related_results) {
        push @undeleted, $related_result unless $related_result->is_marked_for_deletion;
        next unless $related_result->is_changed || $related_result->is_marked_for_deletion;
        $related_result->set_from_related($reverse_related, $model);
        $class->mutate_model_recursively($related_result);
      }
      $model->related_resultset($relationship)->set_cache(\@undeleted);
    } else {
      next if $model->$relationship->in_storage;
      die "you did not write the code for relation type $rel_type for relation $relationship and model @{[ ref $model]}";
    }      
  }
}

sub build_related {
  my ($class, $model, $related) = @_;
  my $related_obj = $model->new_related($related, +{});
  my @current_cache = @{ $model->related_resultset($related)->get_cache ||[] };
  $model->related_resultset($related)->set_cache([@current_cache, $related_obj]);
  return $related_obj;
}

sub build {
  my ($class, $resultset, %attrs) = @_;
  return $resultset->new_result(\%attrs);
}

sub set_model_from_params_if_valid {
  my ($class, $model, %params) = @_;
  eval {
    $model->result_source->schema->txn_do(sub {
      $class->find_or_new_model_recursively($model, %params);
      $class->mutate_model_recursively($model) if $model->valid;
    }); 1;
  } || do {
    #$c->log->error("Error trying to update the form: $@")
    warn $@;
    $model->errors->add(undef, 'There was a database error trying to save your form.');
  };
}

sub ACCEPT_CONTEXT {
  my ($class, $c) = @_;
  my $model = $c->model('Schema::Person')
    ->find({id=>$c->user->id},{prefetch=>'credit_cards'});

  if(
    ($c->req->method eq 'POST')
      and
    (my %posted = %{$c->req->body_data->{$model->model_name->param_key} ||+{}})
  ) {
    my %params = %posted{qw/
      username
      first_name
      last_name
      address
      city
      state_id
      zip
      credit_cards
    /};

    Dwarn \%params;

    $class->set_model_from_params_if_valid($model, %params);

    Dwarn +{ $model->errors->to_hash(1) } if $model->errors->size;
  }

  return $model;
}

1;
