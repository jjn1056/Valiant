package Valiant::HTML::FormBuilder;

use Moo;
use Valiant::I18N;
use Valiant::HTML::FormTags 'CONTENT_ARGS_KEY', 'input_tag', 'label_tag', 'tag', 'content_tag', '_e', 'options_for_select';

our $DEFAULT_INPUT_ERROR_CLASS = 'is_invalid';
sub DEFAULT_INPUT_ERROR_CLASS { return $DEFAULT_INPUT_ERROR_CLASS }

our $DEFAULT_ERROR_CONTAINER_CLASS = 'invalid-feedback';
sub DEFAULT_ERROR_CONTAINER_CLASS { return $DEFAULT_ERROR_CONTAINER_CLASS }

# Non public helper methods

sub merge_classes_into {
  my $attrs = shift;
  my $existing = exists($attrs->{class}) ? $attrs->{class} : [];
  $existing = [$existing] unless (ref($existing)||'') eq 'ARRAY';
  $attrs->{class} = [@$existing, @_];
}

sub set_unless_defined {
  my ($key, $options, $value) = @_;
  return if exists($options->{$key}) && defined($options->{$key});
  $options->{$key} = $value;
}

has model => (
  is => 'ro',
  required => 1,
  isa => sub {
    return 1;
    my $model = shift;
    # in_storage, human_attribute_name, errors
  },
);

has model_name => ( is => 'ro', required => 1 );
has options => ( is => 'ro', required => 1 );

# $fb->input($attribute, \%options)
# $fb->input($attribute)
sub input {
  my ($self, $attribute, $options) = (shift, shift, (@_ ? shift : +{}));
  my @errors_classes = (@{ delete($options->{errors_classes}) || [] }, $DEFAULT_INPUT_ERROR_CLASS);

  merge_classes_into($options, @errors_classes) if $self->model->can('errors') && $self->model->errors->where($attribute);
  set_unless_defined(type => $options, 'text');
  set_unless_defined(id => $options, $self->input_id($attribute));
  set_unless_defined(name => $options, $self->input_name($attribute));
  set_unless_defined(value => $options, $self->input_value($attribute));

  return input_tag $attribute, $options;
}

sub input_id {
  my ($self, $attribute) = @_;
  return join '_', ($self->model_name, $attribute);
}

sub input_name {
  my ($self, $attribute) = @_;
  return join '.', ($self->model_name, $attribute);
}

sub input_value {
  my ($self, $attribute) = @_;
  return $self->model->read_attribute_for_validation($attribute) || '';
}

sub password {
  my ($self, $attribute, $options) = (shift, shift, (@_ ? shift : +{}));
  $options->{type} = 'password';
  $options->{value} = '';
  return $self->input($attribute, $options);
}

# $fb->label($attribute)
# $fb->label($attribute, \%options)
# $fb->label($attribute, $content)
# $fb->label($attribute, \%options, $content) 
# $fb->label($attribute, \&content);   sub content { my ($translated_attribute) = @_;  ... }
# $fb->label($attribute, \%options, \&content);   sub content { my ( $translated_attribute) = @_;  ... }
sub label {
  my ($self, $attribute) = (shift, shift);
  my ($options, $content) = (+{}, (my $translated_attribute = $self->model->human_attribute_name($attribute)));
  while(my $arg = shift) {
    $options = $arg if (ref($arg)||'') eq 'HASH';
    $content = $arg if (ref($arg)||'') eq 'CODE';
    $content = $arg if (ref(\$arg)||'') eq 'SCALAR';
  }

  set_unless_defined(for => $options, $self->input_id($attribute));
  push @{$options->{CONTENT_ARGS_KEY}}, $translated_attribute  if((ref($content)||'') eq 'CODE');
  
  return label_tag($attribute, $content, $options);
}

# $fb->errors_for($attribute)
# $fb->errors_for($attribute, \%options)
# $fb->errors_for($attribute, \%options, \&template)
# $fb->errors_for($attribute, \&template)

sub errors_for {
  my ($self, $attribute) = (shift, shift);
  my ($options, $content) = (+{}, $self->_default_errors_for_content);
  while(my $arg = shift) {
    $options = $arg if (ref($arg)||'') eq 'HASH';
    $content = $arg if (ref($arg)||'') eq 'CODE';
  }
  my @errors = $self->model->errors->full_messages_for($attribute);
  my $max_errors = exists($options->{max_errors}) ? delete($options->{max_errors}) : undef;
  merge_classes_into($options, DEFAULT_ERROR_CONTAINER_CLASS);

  @errors = @errors[0..($max_errors-1)] if($max_errors);
  
  return $content->($options, @errors);
  
}

sub _default_errors_for_content {
  return sub {
    my ($options, @errors) = @_;
    if( scalar(@errors) == 1 ) {
      content_tag 'div', $errors[0], $options;
    } else {
      content_tag 'ol', $options, sub { join '', map { content_tag('li', $_) } @errors };
    }
  }
}

# $fb->model_errors()
# $fb->model_errors(\%options)
# $fb->model_errors(\%options, \&template)
# $fb->model_errors(\&template)

sub model_errors {
  my ($self) = shift;
  my ($options, $content) = (+{}, $self->_default_model_errors_content);
  while(my $arg = shift) {
    $options = $arg if (ref($arg)||'') eq 'HASH';
    $content = $arg if (ref($arg)||'') eq 'CODE';
  }
  my @errors = $self->model->errors->model_messages;

  if(
    $self->model->has_errors &&
    (my $tag = delete $options->{always_show_message})
  ) {
    # Ok so sometimes you just want to display a 'form has errors' global message
    # even if there's no explcit model errors (although there' might be, this logic
    # works either way).  Like if you have attribute errors or nested errors.   This
    # is common in a UI since you might have errors offscreen that you need to prompt
    # the user about.
    unshift @errors, $self->_generate_default_model_error($tag);
  }

  my $max_errors = exists($options->{max_errors}) ? delete($options->{max_errors}) : undef;
  @errors = @errors[0..($max_errors-1)] if($max_errors);

  merge_classes_into($options, DEFAULT_ERROR_CONTAINER_CLASS);
  return $content->($options, @errors);
}

sub _generate_default_model_error {
  my ($self, $tag) = @_;
  $tag = _t('invalid_form') if $tag eq '1';
  return $tag unless ref $tag;
  return "Your form has errors" unless $self->model->can('i18n');
  return $self->model->i18n->translate(
      $tag,
      scope=>'valiant.html.errors.messages',
      default=>[ _t("errors.messages.$tag"), _t("messages.$tag") ],
    );
}

sub _default_model_errors_content {
  return sub {
    my ($options, @errors) = @_;
    if( scalar(@errors) == 1 ) {
      content_tag 'div', $errors[0], $options;
    } else {
      content_tag 'ol', $options, sub { join '', map { content_tag('li', $_) } @errors };
    }
  }
}

sub content {
  my ($self, @content) = @_;
  return map { _e $_ } @content;
}

# Where $collection_arrayref is an arrayref suitable for passing to 'options_for_select'.
# $fb->select($attribute, \@collection, \%options)
# $fb->select($attribute, \@collection)

# Where $collection_obj is an object that responds to ->all, returning an array of item objects
# where each item object responds to both $value_method and $text_method.  If those are not specified
# they default to 'option_value' and 'option_text'.  Maybe we should also check $collection_obj->select_option_text / value??
# $fb->select($attribute, $collection_obj, $value_method, $text_method, \%options)
# $fb->select($attribute, $collection_obj, \%options)
# $fb->select($attribute, $collection_obj)

# Where $collection_method is a a method name on $model which is called with $attribute, $value, \%options
# and returns an arrayref suitable for options_for_select.  If the method name is not given, it defaults to
# "select_options_for_${attribute}".
# $fb->select($attribute, $collection_method, \%options)
# $fb->select($attribute, $collection_method)
# $fb->select($attribute, \%options)
# $fb->select($attribute)
#
# In all cases when the final argument is a coderef that is used as a template for generating everything
# inside the <select> tag.  Useful for when you have complex render needs.  This should return whatever
# you want inside the <select>
# $fb->select($attribute, sub {
#   my ($normalized_collection, @selected) = @_;
# });
#
# If the $attribute returns a collection instead of a value
# $fb->select( +{ $attribute=>4key }, ...)

sub select {
  my $self = shift;
}

1;

__END__

=head1 NAME

Valiant::HTML::Formbuilder - HTML Forms

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 SEE ALSO
 
L<Valiant>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

