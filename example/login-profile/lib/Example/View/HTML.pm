package Example::View::HTML;

use Moose;
use Mojo::ByteStream qw(b);
extends 'Catalyst::View::MojoTemplate';

__PACKAGE__->config(
  helpers => {
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
