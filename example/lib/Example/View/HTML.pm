package Example::View::HTML;

use Moose;
use Mojo::ByteStream qw(b);
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
    fields_for_related    => \&fields_for_related,
    model_errors => \&model_errors,
    model_errors_for => \&model_errors_for,
    current_namespace_id => sub { join '_', @{$_[1]->stash->{'valiant.view.form.namespace'}||[]} },
    namespace_id_for => sub { join '_', (@{$_[1]->stash->{'valiant.view.form.namespace'}||[]}, @_[2...$#_]) },
  },
);

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
 # TODO
}

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

## TODO this should handle has_one, belongs_to
sub fields_for_related {
  my ($self, $c, $related, @proto) = @_;
  my ($inner, %attrs) = _parse_proto(@proto);
  my $model = $c->stash->{'valiant.view.form.model'};
  my @namespace = @{$c->stash->{'valiant.view.form.namespace'}||[]};

  die "No relation '$related' for model" unless $model->has_relationship($related);

  my @results = $model->$related->all;

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
      $content .= $self->hidden($c, $primary_column, type=>'hidden', %attrs);
    }
    if(@primary_columns) {
      $content .= $self->hidden($c, '_destroy', type=>'hidden', %attrs, value=>0);
    }

    $content .= $inner->($c, $result, $idx);
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
