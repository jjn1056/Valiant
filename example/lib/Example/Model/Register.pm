package Example::Model::Register;

use Moo;
use Devel::Dwarn;

sub find_or_new_model_recursively {
  my ($class, $model, %params) = @_;
  foreach my $param (keys %params) {
    if($model->has_column($param)) {
      $model->set_column($param => $params{$param});
    } elsif($model->has_relationship($param)) {
      my $rel_data = $model->relationship_info($param);
      my $rel_type = $rel_data->{attrs}{accessor};
      if($rel_type eq 'multi') {
        # TODO allow array here as well for the picky
        my @param_rows = map { $params{$param}{$_} } sort { $a <=> $b} keys %{$params{$param} || die "missing $param key in params"};
        my @related_models = ();
        foreach my $param_row (@param_rows) {

          my $related_model = eval {
            my $new_related = $model->new_related($param, +{});
            my @primary_columns = $new_related->result_source->primary_columns;

            my %found_primary_columns = map {
              exists($param_row->{$_}) ? ($param_row->{$_}) : ();
            } @primary_columns;

            if(%found_primary_columns) {
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

sub ACCEPT_CONTEXT {
  my ($class, $c) = @_;
  my $model = $class->build($c->model('Schema::Person'));

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

    Dwarn \%params;

    $class->find_or_new_model_recursively($model, %params);
    $class->update_or_insert_model_recursively($model) if $model->valid;

    Dwarn +{ $model->errors->to_hash(1) };
    #Dwarn +{ $model->credit_cards->first->errors->to_hash(1) };

  } else {
    $class->build_related($model, 'credit_cards');
  }

  return $model;
}

1;
