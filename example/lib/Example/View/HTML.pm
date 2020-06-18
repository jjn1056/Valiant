package Example::View::HTML;

use Moose;
use Mojo::ByteStream qw(b);
use Scalar::Util 'blessed';
extends 'Catalyst::View::MojoTemplate';

__PACKAGE__->config(
  helpers => {
    tag         => \&tag,
    input       => \&input,
    date_input  => \&date_input,
    password    => \&password,
    hidden      => \&hidden,
    submit      => \&submit,
    label       => \&label,
    form_for    => \&form_for,
    select_from_resultset => \&select_from_resultset,
    select_from_related => \&select_from_related,
    fields_for_related    => \&fields_for_related,
    model_errors => \&model_errors,
    model_errors_for => \&model_errors_for,
    checkbox_from_related => \&checkbox_from_related,
    current_namespace_id => sub { join '_', @{$_[1]->stash->{'valiant.view.form.namespace'}||[]} },
    namespace_id_for => \&namespace_id_for,
  },
);

sub namespace_id_for {
  return join '_', (@{$_[1]->stash->{'valiant.view.form.namespace'}||[]}, @_[2...$#_])
}

sub _parse_proto {
  my @proto = @_;
  my $content = (ref($proto[-1])||'') eq 'CODE' ? pop @proto : sub { undef };
  my %attrs = @proto;
  return ($content, %attrs);
}

sub _stringify_attrs {
  my %attrs = @_;
  my $attrs =  join ' ', map { "$_='$attrs{$_}'"} keys %attrs;
  return $attrs;
}

sub model_errors {
   my ($self, $c, %attrs) = @_;
   if(my @errors = $c->stash->{'valiant.view.form.model'}->errors->model_errors_array(1)) {
     my $max_errors = $attrs{max_errors} ? delete($attrs{max_errors}) : scalar(@errors);
     my $errors = join ', ', @errors[0..($max_errors-1)];
     my $attrs =  join ' ', map { "$_='$attrs{$_}'"} keys %attrs;
     return b("<div $attrs/>$errors</div>");
   } else {
     return '';
   }
}

sub model_errors_for {
   my ($self, $c, $attribute, %attrs) = @_;
   my $model = $c->stash->{'valiant.view.form.model'};

   if(my @errors = $model->errors->full_messages_for($attribute)) {
     my $max_errors = $attrs{max_errors} ? delete($attrs{max_errors}) : scalar(@errors);
     my $errors = join ', ', @errors[0..($max_errors-1)];
     my $attrs =  join ' ', map { "$_='$attrs{$_}'"} keys %attrs;
     return b("<div $attrs/>$errors</div>");
   } else {
     return '';
   }
}

sub tag {
  my ($self, $name, $attrs, $content) = @_;
  my $attrs_string = _stringify_attrs(%{$attrs||+{}});
  return $content ? b("<$name $attrs_string>$content</$name>")
    : b("<$name $attrs_string />");
}

sub label {
  my ($self, $c, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  my $model = $c->stash->{'valiant.view.form.model'};
  my $text = $content ? $content->() : $model->human_attribute_name($attrs{for});
  return $self->tag('label', \%attrs, $text);
}

sub form_for {
  my ($self, $c, $model, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);

  $attrs{id} ||= $model->model_name->param_key;
  $attrs{method} ||= 'POST';

  my $attrs = _stringify_attrs(%attrs);

  local $c->stash->{'valiant.view.form.model'} = $model;
  local $c->stash->{'valiant.view.form.namespace'}[0] = $attrs{id};

  return my $rendered = b("<form $attrs>@{[$content->()]}</form>");
}

sub input {
  my ($self, $c, $name, %attrs) = @_;
  my $model = $c->stash->{'valiant.view.form.model'};
  my @namespace = @{$c->stash->{'valiant.view.form.namespace'}||[]};
  my @errors = $model->errors->full_messages_for($name);

  # Experimental introspection.  This is probably expensive and needs some sort
  # of caching strategy (for non dynamic bits).  Also not sure this is the right
  # API for this (do we want to isolate the HTML generation logic in its own code...?
  #
  # I think if we have some sort of meta description framework for Moo so that a
  # Validator can mark attributes as 'for input html' we can write some code that
  # gathers those via introspection and run the _cb_value method.  Once that actually
  # works its nor a big step to have some sort of RPC for doing AJAXy field by field
  # validation.
  #
  # Really this is ugly proof of concept.  Sometimes you need to be ugly to get the
  # functionality you want to see then you can refactor :)
  # One thing that might be fun with the valiation introspection API is to have a simple
  # RPC endpoint for doing individual field validations, so you can do faster validation
  # as a user to doing the form.
  unless($ENV{VALIANT_FORM_NO_INTROSPECTION} || delete($attrs{no_instrospection})) {
    $attrs{required} ||= 1 if $model->has_validator_for_attribute(presence=>$name);
    if($model->can('has_column') && $model->has_column($name)) {
      my $info = $model->result_source->column_info($name);
      $attrs{type} ||= 'date' if $info->{data_type} eq 'date';
    }
    if(my ($date_validator) = $model->has_validator_for_attribute(date=>$name)) {
      $attrs{min} ||= $date_validator->to_pattern($date_validator->_cb_value($model, $date_validator->min)) if $date_validator->has_min;
      $attrs{max} ||= $date_validator->to_pattern($date_validator->_cb_value($model, $date_validator->max)) if $date_validator->has_max;
    }
  }
  # End.  Lots to do here possibly.  Would be cool maybe if some sort of meta desc thing
  # Could be used for OpenAPI and GraphQL as well.

  $attrs{type} ||= 'text';
  $attrs{id} ||= join '_', (@namespace, $name);
  $attrs{name} ||= join '.', (@namespace, $name);
  $attrs{value} = ($model->read_attribute_for_validation($name) || '') unless defined($attrs{value});
  $attrs{placeholder} = $model->human_attribute_name($name) if( ($attrs{placeholder}||'') eq '1');
  $attrs{class} .= ' is-invalid' if @errors;

  my @content;

  if(my $label = delete $attrs{label}) {
    my %label_params = %$label if ref($label);
    push @content, $self->label($c, for=>$attrs{id}, %label_params, sub {  $model->human_attribute_name($name) });
  }

  push @content, $self->tag('input', \%attrs);
  push @content, $self->tag('div', +{class=>'invalid-feedback'}, $errors[0]) if @errors;

  return b(@content);
}

sub password {
  my ($self, $c, $name, %attrs) = @_;
  return $self->input($c, $name, type=>'password', %attrs);
}

sub hidden {
  my ($self, $c, $name, %attrs) = @_;
  return $self->input($c, $name, type=>'hidden', %attrs);
}

sub date_input {
  my ($self, $c, $name, %attrs) = @_;
  my $model = $c->stash->{'valiant.view.form.model'};

  # Don't attempt to inflate if there's found errors
  unless($model->errors->messages_for($name)) {
    if(my $strftime = delete $attrs{datetime_strftime}) {
      my $value = $model->$name || '';
      ## TODO need to make sure $value is a blessed DateTime...
      $attrs{value} = $value->strftime($strftime) if $value;
    }
  }

  return $self->input($c, $name, type=>'text', %attrs);
}

sub submit {
  my ($self, $c, $name, %attrs) = @_;
  return $self->input($c, $name, type=>'submit', %attrs);
}

sub select_from_related {
  my ($self, $c, $relationship, %attrs) = @_;
  my $model = $c->stash->{'valiant.view.form.model'};
  my @namespace = @{$c->stash->{'valiant.view.form.namespace'}||[]};
  my $rel_data = $model->relationship_info($relationship);

  # TODO all this DBIC meta needs to be encapsulated in the DBIC Result component
  my ($attribute) = keys %{$rel_data->{attrs}{fk_columns}}; # Doesn't do multifield FK.  Send me a broken test case and I'll fix it
  my $current_value = $model->read_attribute_for_validation($attribute)||'';
  
  $attrs{id} ||= join '_', (@namespace, $attribute);
  $attrs{name} ||= join '.', (@namespace, $attribute);

  my $search_cond = delete ($attrs{search_cond}) || +{};
  my $search_attrs = delete ($attrs{search_attrs}) || +{};
  my $search_method = delete ($attrs{search_method}) || '';
  my $options_resultset = $search_method ?
    $model->related_resultset($relationship)->result_source->resultset->$search_method :
    $model->related_resultset($relationship)->result_source->resultset->search($search_cond, $search_attrs);

  my ($options, $label_text);
  my $options_label = delete($attrs{options_label_field}) || 'label';
  my $options_value = delete($attrs{options_value_field}) || 'id';
  my @option_rows = $options_resultset->all;
  foreach my $row (@option_rows) {
    $label_text ||= $row->model_name->human;
    my $selected = $row->$options_value eq $current_value ? 'selected':'';
    $options .= "<option value='@{[ $row->$options_value ]}' $selected >@{[ $row->$options_label ]}</option>"
  }

  my $content;
  if(my $label_attrs = delete $attrs{label}) {
    my %label_params = %$label_attrs if ref($label_attrs);
    $content .= $self->label($c, for=>$attrs{id}, %label_params, sub {  $label_text });
  }

  my @errors = $model->errors->full_messages_for($attribute);
  $content .= $self->tag('select', \%attrs, $options);
  $content .= $self->tag('div', +{class=>'invalid-feedback'}, $errors[0]) if @errors;

  return b($content);
}

# %= checkbox_from_related $related_attribute_str, \@array|$object, \%mapping, %html_attrs;
# %= checkbox_from_related \&callback, %html_attrs;

sub checkbox_from_related {
  my ($self, $c, $related, $all_proto, @proto) = @_;
  my ($inner, %attrs) = _parse_proto(@proto);
  my $model = $c->stash->{'valiant.view.form.model'};
  my @namespace = @{$c->stash->{'valiant.view.form.namespace'}||[]};

  die "No relation '$related' for model" unless $model->has_relationship($related);
  my $related_model = $model->related_resultset($related);
  my $all_model = $related_model
    ->related_resultset($all_proto)
    ->result_source
    ->resultset;

  # This currently only works with single field relationships.  Give me a broken
  # test case and I'll fix it (jjnapiork).
  my $rel_data = $related_model->new_result(+{})->relationship_info($all_proto);
  my @primary_columns = $related_model->new_result(+{})->result_source->primary_columns;
  my ($related_key) = keys %{$rel_data->{attrs}{fk_columns} || die "No related fk_columns for $related"};

  my ($idx, $content) = (0, '');
  foreach my $all_result ($all_model->all) {
    my %local_attrs = %attrs;
    my %checkbox_attrs = %{ delete($local_attrs{checkbox_attrs})||+{} };

    my ($found) = grep {
      ($_->$related_key||'') eq $all_result->id
    } grep {
      not $_->is_marked_for_deletion
    } $related_model->all; 

    my $found_and_stored = $found && ($found->in_storage || $found->is_marked_for_deletion) ? 1:0;

    local $c->stash->{'valiant.view.form.model'} = $all_result;
    local $c->stash->{'valiant.view.form.namespace'} = [@namespace, $related, $idx++];

    my $label_html = '';
    if(my $label_attrs = delete $local_attrs{label}) {
      my %label_params = %$label_attrs if ref($label_attrs);
      $label_params{for} = $self->namespace_id_for($c, (!$found ? $related_key : '_checked'));
      $label_html .= $self->label($c,  %label_params, sub { $all_result->label });
    }

    $checkbox_attrs{checked} = 1 if $found;
    $checkbox_attrs{value} = $all_result->id;
    $checkbox_attrs{onclick} = 
      qq[document.getElementById("] .
      $self->namespace_id_for($c, '_destroy') .
      qq[").value = this.checked ? 0:1] if $found;

    my $checkbox_html .= $self->input($c, (!$found_and_stored ? $related_key : '_checked'), type=>'checkbox', %checkbox_attrs, %local_attrs);

    if($found_and_stored) {
      foreach my $primary_column (@primary_columns) {
        $checkbox_html .= $self->hidden($c, $primary_column, value=>$found->$primary_column);
      }
      $checkbox_html .= $self->hidden($c, '_destroy', value => $found ? 0:1);
    }

    $content .= $inner ? $inner->(b($checkbox_html), b($label_html)) : b($checkbox_html, $label_html);
  }

  return b($content);
}

## TODO this should handle has_one, belongs_to
sub fields_for_related {
  my ($self, $c, $related, @proto) = @_;
  my ($inner, %attrs) = _parse_proto(@proto);
  my $model = $c->stash->{'valiant.view.form.model'};
  my @namespace = @{$c->stash->{'valiant.view.form.namespace'}||[]};

  die "No relation '$related' for model $model" unless $model->has_relationship($related);
  # die "Empty relation '$related' for model $model" unless $model->$related;
  my @results = $model->related_resultset($related)->all;

  # I think we can drop this feature
  push @results, $model->result_source->related_source($related)->resultset->new_result({})
    if $attrs{add_result_if_none};

  my $content;
  my $idx = 0;
  foreach my $result (@results) {
    local $c->stash->{'valiant.view.form.model'} = $result;
    local $c->stash->{'valiant.view.form.namespace'} = [@namespace, $related, $idx++];

    my @primary_columns = $result->result_source->primary_columns;
    foreach my $primary_column (@primary_columns) {
      next unless my $value = $result->get_column($primary_column);
      $content .= $self->hidden($c, $primary_column, %attrs);
    }
    if(@primary_columns) {
      $content .= $self->hidden($c, '_destroy', %attrs, value=>$result->is_marked_for_deletion);
    }

    $content .= $inner->($c, $result, $idx) unless $result->is_marked_for_deletion;
  }

  if(1) {
    my $result = $model->result_source->related_source($related)->resultset->new_result({});
    local $c->stash->{'valiant.view.form.model'} = $result;
    local $c->stash->{'valiant.view.form.namespace'} = [@namespace, $related, "{{epoch}}"];
    
    $content .= qq|
      <script id='@{[ join '_', (@namespace, $related, "template") ]}' type='text/template'>@{[ $inner->($c, $result, '{{epoch}}') ]}</script>
    |;
  }

  return b($content);
}


# Stuff here is probably semi deprecated
sub select_from_resultset {
  my ($self, $c, $attribute, $resultset, $id, $name, %attrs) = @_;
  my $model = $c->stash->{'valiant.view.form.model'};
  my @namespace = @{$c->stash->{'valiant.view.form.namespace'}||[]};
  my @errors = $model->errors->full_messages_for($name);
  
  $attrs{id} ||= join '_', (@namespace, $attribute);
  $attrs{name} ||= join '.', (@namespace, $attribute);

  my ($options, $label_text);
  foreach my $row ($resultset->all) {
    $label_text ||= $row->model_name->human;
    my $selected = $row->$id eq ($model->read_attribute_for_validation($attribute)||'') ? 'selected':'';
    $options .= "<option value='@{[ $row->$id ]}' $selected >@{[ $row->$name ]}</option>"
  }

  my $content;
  if(my $label_attrs = delete $attrs{label}) {
    my %label_params = %$label_attrs if ref($label_attrs);
    $content .= $self->label($c, for=>$attrs{id}, %label_params, sub {  $label_text });
  }

  $content .= $self->tag('select', \%attrs, $options);
  $content .= $self->tag('div', +{class=>'invalid-feedback'}, $errors[0]) if @errors;

  return b($content);
}

sub related_fields {
  my ($self, $c, $related, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  my $form = $c->stash->{'valiant.form'};
  if($form->model->has_relationship($related)) {
    my $related_model = $form->model->$related;
    #todo cope with one to many
    local $c->stash->{'valiant.form'} = $form->create_subform($related_model);
    $content = b($content->());
    return $content;
  } else {
    die "No relation '$related' for model";
  }
}

sub related_resultset2 {
  my ($self, $c, $related, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  my $form = $c->stash->{'valiant.form'};
  if($form->model->has_relationship($related)) {
    my @content;
    my $resultset = $form->model->$related;
    my @results = $resultset->all;
    push @results, $form->model->result_source->related_source($related)->resultset->new_result({}) if $attrs{add_result_if_none};
    foreach my $result (@results) {
      local $c->stash->{'valiant.form'} = $form->create_subform($result, 0);
      push @content, $content->();
    }
    return b(@content);
  } else {
    die "No relation '$related' for model";
  }
}


sub sub_form {
  my ($self, $c, $related, @proto) = @_;
  my ($block, %attrs) = (pop(@proto), @proto);
  my $model = $c->stash->{'view.form.model'};

  if($model->has_relationship($related)) {
    local $c->stash->{'view.form.model'} = $model->$related;
    local $c->stash->{'view.form.namespace'} = $related, 
    my $content = b($block->());
    return $content;
  } else {
    die "No relation '$related' for model";
  }
}


1;
