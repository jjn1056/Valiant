package Valiant::Form;

use Moo;
use Data::Perl::Collection::Array;

has parent => (is=>'ro', required=>0, predicate=>'has_parent');
has model => (is => 'ro', required => 1 );
has namespace => (is=>'ro', required=>1, lazy=>1, builder=>'_build_namespace');

  sub _build_namespace {
    my ($self, @current) = @_;
    unshift @current, $self->model->model_name->param_key;
    return $self->parent->_build_namespace(@current) if $self->has_parent;
    return \@current;
  }

sub create_subform {
  my ($self, $sub_model) = @_;
  return ref($self)->new(parent=>$self, model=>$sub_model);
}

package Example::View::HTML;

use Moose;
use Mojo::ByteStream qw(b);
extends 'Catalyst::View::MojoTemplate';

__PACKAGE__->config(
  helpers => {
    form2 => \&form2,
    input2 => \&input2,
    password2 => \&password2,
    submit2 => \&submit2,
    related_fields => \&related_fields,
    related_resultset => \&related_resultset,

    select_from_resultset => \&select_from_resultset,

    form => sub {
      my ($self, $c, $model, @proto) = @_;
      my ($inner, %attrs) = (pop(@proto), @proto);
      my $attrs =  join ' ', map { "$_='$attrs{$_}'"} keys %attrs;

      LOCAL_TO_FORM: {
        # Do we need a stack so we can refer to the parent or not...?
        my @model_stack = (
          (exists($c->stash->{'view.form.model'}) ? $c->stash->{'view.form.model'} : () ),
          $model,
        );
        local $c->stash->{'view.form.model'} = $model;

      return b("<form $attrs>@{[$inner->()]}</form>");
      }
    },
    model_errors => sub {
      my ($self, $c, %attrs) = @_;
      if(my @errors = $c->stash->{'view.form.model'}->errors->model_errors_array(1)) {
        my $errors = join ', ', @errors;
        my $attrs =  join ' ', map { "$_='$attrs{$_}'"} keys %attrs;
        return b("<div $attrs/>$errors</div>");
      } else {
        return '';
      }
    },
    input => \&input,
    password => \&password,
    submit => \&submit,
    sub_form => \&sub_form,
  },
);

sub _parse_proto {
  my @proto = @_;
  my $content = (ref($proto[-1])||'') eq 'CODE' ? pop @proto : sub { undef };
  my %attrs = @proto;
  return ($content, %attrs);

}

sub form2 {
  my ($self, $c, $model, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  my $form = Valiant::Form->new(model=>$model);

  $attrs{id} ||= $model->model_name->param_key;
  $attrs{method} ||= 'POST';

  my $attrs =  join ' ', map { "$_='$attrs{$_}'"} keys %attrs;
  
  local $c->stash->{'valiant.form'} = Valiant::Form->new(model=>$model);

  my $rendered = b("<form $attrs>@{[$content->()]}</form>");
  return $rendered;
}

sub input2 {
  my ($self, $c, $name, %attrs) = @_;
  my $form = $c->stash->{'valiant.form'};
  my $model = $form->model;
  my @errors = $form->model->errors->full_messages_for($name);

  $attrs{type} ||= 'text';
  $attrs{id} ||= join '_', (@{$form->namespace}, $name);
  $attrs{name} ||= join '.', (@{$form->namespace}, $name);
  $attrs{value} ||= $model->read_attribute_for_validation($name) || '';
  $attrs{placeholder} = $model->human_attribute_name($name) if( ($attrs{placeholder}||'') eq '1');
  $attrs{class} .= ' is-invalid' if @errors;

  my @content;

  if(my $label = delete $attrs{label}) {
    my %label_params = %$label if ref($label);
    push @content, $self->label2($c, for=>$attrs{id}, %label_params, sub {  $model->human_attribute_name($name) });
  }

  push @content, $self->tag('input', \%attrs);
  push @content, $self->tag('div', +{class=>'invalid-feedback'}, $errors[0]) if @errors;

  return b(@content);
}

sub password2 {
  my ($self, $c, $name, %attrs) = @_;
  my @content = $self->input2($c, $name, type=>'password', %attrs);
  return b(@content);
}

sub submit2 {
  my ($self, $c, $name, %attrs) = @_;
  $self->input2($c, $name, type=>'submit', %attrs);
}

sub label2 {
  my ($self, $c, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  my $form = $c->stash->{'valiant.form'};
  my $text = $content->() || $form->model->human_attribute_name($attrs{for});

  return $self->tag('label', \%attrs, $text);
}

# select_related 'State', 
sub select_from_resultset {
  my ($self, $c, $attribute, $resultset, $id, $name, %attrs) = @_;
  my $form = $c->stash->{'valiant.form'};
  my $model = $form->model;
  my @errors = $form->model->errors->full_messages_for($name);
  
  $attrs{id} ||= join '_', (@{$form->namespace}, $attribute);
  $attrs{name} ||= join '.', (@{$form->namespace}, $attribute);

  # Needs cache option
  my $options = '';
  my $label_text;
  foreach my $row ($resultset->all) {
    unless($label_text) {
      $label_text = $row->model_name->human;
    }
    my $selected = $row->$name eq ($model->read_attribute_for_validation($attribute)||'') ? 'selected':'';
    $options .= "<option value='@{[ $row->$id ]}' $selected >@{[ $row->$name ]}</option>"
  }

  my $label = '';
  if(my $label_attrs = delete $attrs{label}) {
    my %label_params = %$label_attrs if ref($label_attrs);
    $label = $self->label2($c, for=>$attrs{id}, %label_params, sub {  $label_text });
  }

  my $select = $self->tag('select', \%attrs, $options);

  return b($label, $select);
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

sub related_resultset {
  my ($self, $c, $related, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  my $form = $c->stash->{'valiant.form'};
  if($form->model->has_relationship($related)) {
    my @content;
    my $resultset = $form->model->$related;
    foreach my $result ($resultset->all) {
      warn "..................... $result " x 5;
      local $c->stash->{'valiant.form'} = $form->create_subform($result);
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

sub tag {
  my ($self, $name, $attrs, $content) = @_;
  my $attrs_string =  join ' ', map { "$_='$attrs->{$_}'"} keys %{$attrs||+{}};
  if($content) {
    return b("<$name $attrs_string>$content</$name>");
  } else {
    return b("<$name $attrs_string />");
  }
}

sub label {
  my ($self, $c, %attrs) = @_;
  my $model = $c->stash->{'view.form.model'};
  my $text = $attrs{text} || $model->human_attribute_name($attrs{for});

  return $self->tag('label', \%attrs, $text);
}

sub input {
  my ($self, $c, $name, %attrs) = @_;
  my $model = $c->stash->{'view.form.model'} || die "Can't find model for '$name'";
  my @errors = $model->errors->full_messages_for($name);

  $name = $c->stash->{'view.form.namespace'} . ".${name}" if exists $c->stash->{'view.form.namespace'};

  $attrs{type} ||= 'text';
  $attrs{id} ||= $name;
  $attrs{name} ||= $name;
  $attrs{value} ||= $model->read_attribute_for_validation($name) || '';
  $attrs{placeholder} = $model->human_attribute_name($name) if( ($attrs{placeholder}||'') eq '1');
  $attrs{class} .= ' is-invalid' if @errors;

  my @content;

  if(my $label = delete $attrs{label}) {
    my %label_params = %$label if ref($label);
    push @content, $self->label($c, for=>$name, %label_params);
  }

  push @content, $self->tag('input', \%attrs);
  push @content, $self->tag('div', +{class=>'invalid-feedback'}, $errors[0]) if @errors;

  return b(@content);
}

sub password {
  my ($self, $c, $name, %attrs) = @_;
  my $confirmation = delete $attrs{confirmation} if exists $attrs{confirmation};
  my @content = $self->input($c, $name, type=>'password', %attrs);
  if($confirmation) {
    delete $attrs{label} if exists $attrs{label};
    push @content, $self->input($c, $name .'_confirmation', type=>'password', %attrs);
  }
  return b(@content);
}

sub submit {
  my ($self, $c, $name, %attrs) = @_;
  $self->input($c, $name, type=>'submit', %attrs);
}

1;
