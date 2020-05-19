package Example::View::HTML;

use Moose;
use Mojo::ByteStream qw(b);
extends 'Catalyst::View::MojoTemplate';

__PACKAGE__->config(
  helpers => {
    tag         => \&tag,
    input       => \&input,
    password    => \&password,
    submit      => \&submit,
    label       => \&label,
    form_for    => \&form_for,
    select_from_resultset => \&select_from_resultset,
    fields_for_related    => \&fields_for_related,
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

  use Devel::Dwarn;
  Dwarn $name;
  Dwarn $c->stash->{'valiant.view.form.namespace'};

  my $model = $c->stash->{'valiant.view.form.model'};
  my @namespace = @{$c->stash->{'valiant.view.form.namespace'}||[]};
  my @errors = $model->errors->full_messages_for($name);

  $attrs{type} ||= 'text';
  $attrs{id} ||= join '_', (@namespace, $name);
  $attrs{name} ||= join '.', (@namespace, $name);
  $attrs{value} ||= $model->read_attribute_for_validation($name) || '';
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
  
  $attrs{id} ||= join '_', (@namespace, $name);
  $attrs{name} ||= join '.', (@namespace, $name);

  my ($options, $label_text);
  foreach my $row ($resultset->all) {
    $label_text ||= $row->model_name->human;
    my $selected = $row->$name eq ($model->read_attribute_for_validation($attribute)||'') ? 'selected':'';
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
  push @results, $model->result_source->related_source($related)->resultset->new_result({})
    if $attrs{add_result_if_none};

  my $content;
  my $idx = 0;
  foreach my $result (@results) {
    local $c->stash->{'valiant.view.form.model'} = $result;
    local $c->stash->{'valiant.view.form.namespace'} = [@namespace, "${related}[@{[ $idx++ ]}]"];
    $content .= $inner->();
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
