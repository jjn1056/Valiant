package Example::View::HTML;

use Moose;
use Mojo::ByteStream qw(b);
use Scalar::Util 'blessed';

extends 'Catalyst::View::MojoTemplate';


__PACKAGE__->config(
  helpers => {
    attr => \&attr,
    method_attr => \&method_attr,
    style_attr => \&style_attr,

    tag => \&tag,
    form_tag => \&form_tag,
    label_tag => \&label_tag,
    input_tag => \&input_tag,
    button_tag => \&button_tag,

    errors_box => \&errors_box,

    form_for => \&form_for,
    label => \&label,
    input => \&input,
    errors_for => \&errors_for,
    model_errors => \&model_errors,
    # fields_for => \&fields_for,
    #  tag_options => \&tag_options,
    # text_field_tag => \&text_field_tag,
  },
);

sub errors_box {
  my ($self, $c, $model, %attrs) = @_;
  my @errors = ();
  if(blessed $model) {
    @errors = $model->errors->full_messages;
  } elsif($model) {
    @errors = ($model);
  }
  if(@errors) {
    my $max_errors = $attrs{max_errors} ? delete($attrs{max_errors}) : scalar(@errors);
    my $errors = join '', map { "<li>$_" } @errors[0..($max_errors-1)];
    my $attrs =  join ' ', map { "$_='$attrs{$_}'"} keys %attrs;
    return b("<div $attrs/>$errors</div>");
  } else {
    return '';
  } 
}

sub _stringify_attrs {
  my %attrs = @_;
  return unless %attrs;
  return my $attrs =  join ' ', map { "$_='@{[ $attrs{$_}||'' ]}'"} keys %attrs;
}

sub _parse_proto {
  my @proto = @_;
  my $content = undef;
  if(@proto && (ref($proto[-1]) eq 'CODE')) {
    $content = pop @proto;
  } elsif(@proto && (ref(\$proto[-1] ||'') eq 'SCALAR')) {
    my $text = pop @proto;
    $content = sub { $text };
  }
  return ($content) unless @proto;
  my %attrs = ref($proto[0])||'' eq 'HASH' ? %{$proto[0]}:  @proto;
  return ($content, %attrs);
}

sub attr {
  my ($self, $c, $name, $value) = (shift, shift, shift, shift);
  return $name => $value, @_;
}

sub method_attr {
  my ($self, $c, $attr) = (shift, shift, shift);
  die "invalid method value" unless grep { $attr =~ /$_/i } qw(GET POST PUT);
  return $self->attr($c, 'method', $attr, @_);
}

sub style_attr {
  my ($self, $c, $attr) = (shift, shift, shift);
  return $self->attr($c, 'style', $attr, @_);
}


sub tag {
  my ($self, $c, $name, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);

  my $tag = "<${name}";
  $tag .= " @{[ _stringify_attrs(%attrs) ]}" if %attrs;
  return b "$tag/>" unless $content;

  $c->stash->{'valiant.view.current_tag'} = $name;
  $tag .= ">" . $content->() . "</${name}>";
  delete $c->stash->{'valiant.view.current_tag'};
  return b $tag;
}

sub form_tag {
  my ($self, $c, @proto) = @_;
  return $self->tag($c, 'form', @proto);
}

sub label_tag {
  my ($self, $c, @proto) = @_;
  return $self->tag($c, 'label', @proto);
}

sub input_tag {
  my ($self, $c, @proto) = @_;
  return $self->tag($c, 'input', @proto);
}

sub button_tag {
  my ($self, $c, @proto) = @_;
  return $self->tag($c, 'button', @proto);
}

# ====

sub form_for {
  my ($self, $c, $model, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);

  $attrs{id} ||= $model->model_name->param_key;
  $attrs{method} ||= 'POST';

  if($model->can('in_storage') && $model->in_storage) {
    my $value = $model->model_name->param_key . '_edit';
    $attrs{id} ||= $value;
    $attrs{class} ||= $value;
  } else {
    my $value = $model->model_name->param_key . '_new';
    $attrs{id} ||= $value;
    $attrs{class} ||= $value;
  }

  local $c->stash->{'valiant.view.form.model'} = $model;
  local $c->stash->{'valiant.view.form.namespace'}[0] = $attrs{id};

  return $self->form_tag($c, \%attrs, $content);
}

sub label {
  my ($self, $c, $field, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  my $model = $c->stash->{'valiant.view.form.model'};
  my @namespace = @{$c->stash->{'valiant.view.form.namespace'}||[]};

  $attrs{for} ||= join '_', (@namespace, $field);
  $content ||= sub { $model->human_attribute_name($field) };
  
  return $self->label_tag($c, \%attrs, $content);
}

sub input {
  my ($self, $c, $field, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  my $model = $c->stash->{'valiant.view.form.model'};
  my @namespace = @{$c->stash->{'valiant.view.form.namespace'}||[]};
  my @errors = $model->errors->messages_for($field);

  $attrs{type} ||= 'text';
  $attrs{id} ||= join '_', (@namespace, $field);
  $attrs{name} ||= join '.', (@namespace, $field);
  $attrs{value} = ($model->read_attribute_for_validation($field) || '') unless defined($attrs{value});
  $attrs{class} .= ' is-invalid' if @errors;

  return $self->input_tag($c, \%attrs, $content);

  #push @content, $self->tag('div', +{class=>'invalid-feedback'}, $errors[0]) if @errors;

}

sub errors_for {
  my ($self, $c, $field, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  my $model = $c->stash->{'valiant.view.form.model'};
  my @namespace = @{$c->stash->{'valiant.view.form.namespace'}||[]};
  my @errors = $model->errors->full_messages_for($field);

  return '' unless @errors;

  my $class = $attrs{class}||'';
  $class .= ' invalid-feedback';
  $attrs{class} = $class;

  my $max_errors = $attrs{max_errors} ? delete($attrs{max_errors}) : scalar(@errors);
  my $divider = $max_errors > 1 ? '<li>' : '';
  my $errors = join '', map { "${divider}$_" } @errors[0..($max_errors-1)];

  return $self->tag($c, 'div', \%attrs, $errors);
}

sub model_errors {
  my ($self, $c, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  my $model = $c->stash->{'valiant.view.form.model'};
  my @errors = $model->errors->model_errors;

  if($model->has_errors && !@errors) {
    push @errors, delete $attrs{default_msg} if exists $attrs{default_msg};
  }

  return '' unless @errors;

  my $max_errors = $attrs{max_errors} ? delete($attrs{max_errors}) : scalar(@errors);
  my $divider = $max_errors > 1 ? '<li>' : '';
  my $errors = join '', map { "${divider}$_" } @errors[0..($max_errors-1)];

  return $self->tag($c, 'div', \%attrs, $errors);
}

__PACKAGE__->meta->make_immutable;






__END__

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
sub form_tag {
  my ($self, $c, $url, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);
  
  # $attr{action} ||= $c->uri_for()...

  my $out = $self->tag($c, 'form', \%attrs);
  if($content) {
    $out .= $content->();
    $out .= "</form>";
    $out = b $out;
  }

  return $out;
}








sub form_for {
  my ($self, $c, $model, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);

  if($model->can('in_storage') && $model->in_storage) {
    my $value = $model->model_name->param_key . '_edit';
    $attrs{id} ||= $value;
    $attrs{class} ||= $value;
  } else {
    my $value = $model->model_name->param_key . '_new';
    $attrs{id} ||= $value;
    $attrs{class} ||= $value;
  }
  $attrs{method} ||= 'POST';

  return $self->form_tag($c, '', %attrs, $content);
}


sub fields_for {
  my ($self, $c, $model, @proto) = @_;
  my ($content, %attrs) = _parse_proto(@proto);

  local $c->stash->{'valiant.view.form.model'} = $model;
  local $c->stash->{'valiant.view.form.namespace'}[0] = $model->model_name->param_key;

  $attrs{id} ||= $model->model_name->param_key;
  $attrs{method} ||= 'POST';

  my $attrs = _stringify_attrs(%attrs);



}





sub text_field_tag {
  my ($self, $c, $name, $value, $options) = @_;
  $options ||= +{};
  $options->{type} ||= 'text';
  $options->{name} ||= $name;
  $options->{id} ||= do { $name=~tr/\./_/; $name };
  $options->{value} ||= $value;
  return $self->tag($c, 'input', $options);
}

1;
