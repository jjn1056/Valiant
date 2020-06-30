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
      if($rel_type eq 'multi' || $rel_type eq 'single') {
        # TODO allow array here as well for the picky
        my @param_rows = ();
        if(ref($params{$param}) eq 'HASH') {
          @param_rows = map { $params{$param}{$_} } sort { $a <=> $b} keys %{$params{$param} || +{}};
        } elsif(ref($params{$param}) eq 'ARRAY') { # It will come this way with JSON I think
          @param_rows = @{$params{$param} || +[]};
        } else {
          # I think if we are here its because the nests set is
          # empty and we can ignore it for now but... not 100% sure :)
          next;
          die "We expect $param to be some sort of reference but its not!";
        }
        my @related_models = ();

        # TODO this could be batched so we can get it all in one select
        # rather than separate ones.
        foreach my $param_row (@param_rows) {

          #Todo need to recurse for deeply nested relationships

          my $related_model = eval {
            my $new_related = $model->new_related($param, +{});
            my @primary_columns = $new_related->result_source->primary_columns;

            my %found_primary_columns = map {
              exists($param_row->{$_}) ? ($_ => $param_row->{$_}) : ();
            } @primary_columns;

            if(scalar(%found_primary_columns) == scalar(@primary_columns)) {
              # TODO I don't think this is looking in the resultset cache and as a result is
              # running additional SQL queries that already have been run.
              my $found_related = $model->find_related($param, \%found_primary_columns, +{key=>'primary'});
              die "Result not found for relation $param on @{[ $model->model_name->human ]}" unless $found_related;
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
        die "you did not write the code for relation type $rel_type for relation $param and model @{[ $model->model_name->human ]}";
      }    
    } elsif($param eq 'roles') {
      warn "ROLE " x10;
      my @param_rows = map { $params{$param}{$_} } sort { $a <=> $b} keys %{$params{$param} || +{}};

    } elsif($model->can($param)) {
      # Right now this is only used by confirmation stuff
      $model->$param($params{$param});
    } elsif($param eq '_destroy') {
      if($params{$param}) {
        $model->mark_for_deletion if $model->in_storage;
      }
    } elsif($param eq '_checked') {
      # I don't think there's anything to do right now
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
    next unless scalar($model->related_resultset($relationship)->all); #TODO maybe expensive, is there a cheaper option?
    my $rel_data = $model->relationship_info($relationship);
    my $rev_data = $model->result_source->reverse_relationship_info($relationship);
    my $rel_type = $rel_data->{attrs}{accessor};
    if($rel_type eq 'multi' || $rel_type eq 'single') {
      my @related_results = @{ $model->{__valiant_related_resultset}{$relationship} ||[] };
      my ($reverse_related) = keys %$rev_data;
      my @undeleted = ();
      foreach my $related_result (@related_results) {
        push @undeleted, $related_result unless $related_result->is_marked_for_deletion;
        next unless $related_result->is_changed || $related_result->is_marked_for_deletion;
        $related_result->set_from_related($reverse_related, $model) if $reverse_related; # Don't have this for might_have
        $class->mutate_model_recursively($related_result);
      }
      $model->related_resultset($relationship)->set_cache(\@undeleted);
    } else {
      next if $model->$relationship->in_storage;
      die "you did not write the code for relation type $rel_type for relation $relationship and model @{[ ref $model]}";
    }      
  }
}



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
  my $model = $c->model('Schema::Person')
    ->find(
      { id => $c->user->id },
      { prefetch => ['credit_cards', {'person_roles', 'role'}, 'profile' ] }
    );

  $model->build_related_if_empty($_) for qw(profile);
  #$model->build_related_if_empty('person_roles'); # +{role_id=>2} User by default 



  if(
    ($c->req->method eq 'POST')
      and
    (my %posted = %{$c->req->body_data->{$model->model_name->param_key} ||+{}})
  ) {

    my %params = %posted{qw/
      username
      first_name
      last_name
      profile
    /};

    $class->persist_model_from_params_if_valid($model, \%params, +{context=>'profile'});

    Dwarn \%params;
    Dwarn +{ $model->errors->to_hash(1) } if $model->invalid;
    Dwarn +{ $model->profile->errors->to_hash(1) } if $model->invalid;

  }

  return $model;
}

1;
