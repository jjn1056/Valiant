package Valiant::HTML::FormBuilder;

use Moo;
use Valiant::HTML::FormTags ();
use Valiant::HTML::TagBuilder ();
use Valiant::HTML::Util::Collection;

use Valiant::I18N;
use Scalar::Util (); 

with 'Valiant::Naming';

# Non public helper methods

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
    # in_storage, human_attribute_name, primary_columns
    # errors, has_errors, i18n
  },
);

has name => ( is => 'ro', required => 1 );
has options => ( is => 'ro', required => 1, default => sub { +{} } );  
has index => ( is => 'ro', required => 0, predicate => 'has_index' );
has namespace => ( is => 'ro', required => 0, predicate => 'has_namespace' );
has _nested_child_index => (is=>'rw', init_arg=>undef, required=>1, default=>sub { +{} });

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;
  my $options = $class->$orig(@args);

  $options->{index} = $options->{child_index} if !exists($options->{index}) && exists($options->{child_index});
  
  return $options;
};

sub DEFAULT_MODEL_ERROR_MSG_ON_FIELD_ERRORS { return our $DEFAULT_MODEL_ERROR_MSG_ON_FIELD_ERRORS = 'Your form has errors' }
sub DEFAULT_MODEL_ERROR_TAG_ON_FIELD_ERRORS { return our $DEFAULT_MODEL_ERROR_TAG_ON_FIELD_ERRORS = 'invalid_form' }

sub sanitized_object_name {
  my $self = shift;
  return $self->{__cached_sanitized_object_name} if exists $self->{__cached_sanitized_object_name};

  my $value = $self->name;
  $value =~ s/\]//g;
  $value =~ s/[^a-zA-Z0-9:-]/_/g; # Different from Rails since I use foo.bar instead of foo[bar]
  $self->{__cached_sanitized_object_name} = $value;
  return $value;
}

sub nested_child_index {
  my ($self, $attribute) = @_;
  if(exists($self->_nested_child_index->{$attribute})) {
    return ++$self->_nested_child_index->{$attribute};
  } else {
    return $self->_nested_child_index->{$attribute} = 0
  }
}

sub tag_id_for_attribute {
  my ($self, $attribute) = @_;
  my $id = $self->has_namespace ? $self->namespace . '_' : '';
  $id .= $self->has_index ?
    "@{[$self->sanitized_object_name]}_@{[ $self->index ]}_${attribute}" :
    "@{[$self->sanitized_object_name]}_${attribute}";
  return $id;
}

# $self->tag_name_for_attribute($attribute, +{ multiple=>1 });
sub tag_name_for_attribute {
  my ($self, $attribute, $opts) = @_;  
  my $name = $self->has_index ?
    "@{[$self->name]}\[@{[ $self->index ]}\].${attribute}" :
    "@{[$self->name]}.${attribute}";
  $name .= '[]' if $opts->{multiple};

  return $name;
}

sub tag_value_for_attribute {
  my ($self, $attribute) = @_;
  return Valiant::HTML::FormTags::field_value($self->model, $attribute);
}

sub human_name_for_attribute {
  my ($self, $attribute) = @_;
  return $self->model->can('human_attribute_name') ?
    $self->model->human_attribute_name($attribute) :
      Valiant::HTML::FormTags::_humanize($attribute);
}

sub attribute_has_errors {
  my ($self, $attribute) = @_;
  return $self->model->can('errors') && $self->model->errors->where($attribute) ? 1:0;
}

# Public methods for HTML generation
# $fb->model_errors()
# $fb->model_errors(\%options)
# $fb->model_errors(\%options, \&template)
# $fb->model_errors(\&template)

sub model_errors {
  my ($self) = shift;
  my ($options, $content) = (+{}, undef);
  while(my $arg = shift) {
    $options = $arg if (ref($arg)||'') eq 'HASH';
    $content = $arg if (ref($arg)||'') eq 'CODE';
  }

  my @errors = $self->model->errors->model_messages;

  if(
    $self->model->has_errors &&
    (my $tag = delete $options->{show_message_on_field_errors})
  ) {
    unshift @errors, $self->_generate_default_model_error($tag);
  }
  return '' unless @errors;

  my $max_errors = exists($options->{max_errors}) ? delete($options->{max_errors}) : undef;
  @errors = @errors[0..($max_errors-1)] if($max_errors);
  $content = $self->_default_model_errors_content($options) unless defined($content);

  my $error_content = $content->(@errors);
  return $error_content;
}

sub _generate_default_model_error {
  my ($self, $tag) = @_;
  $tag = _t('invalid_form') if $tag eq '1';
  return $tag unless ref $tag;
  return $self->DEFAULT_MODEL_ERROR_MSG_ON_FIELD_ERRORS unless $self->model->can('i18n');
  return $self->model->i18n->translate(
      $tag,
      scope=>'valiant.html.errors.messages',
      default=>[ _t("errors.messages.$tag"), _t("messages.$tag") ],
    );
}

sub _default_model_errors_content {
  my ($self, $options) = @_;
  return sub {
    my (@errors) = @_;
    if( scalar(@errors) == 1 ) {
       return Valiant::HTML::TagBuilder::content_tag 'div', $errors[0], $options;
    } else {
       return Valiant::HTML::TagBuilder::content_tag 'ol', $options, sub { map { Valiant::HTML::TagBuilder::content_tag('li', $_) } @errors };
    }
  }
}

# $fb->label($attribute)
# $fb->label($attribute, \%options)
# $fb->label($attribute, $content)
# $fb->label($attribute, \%options, $content) 
# $fb->label($attribute, \&content);   sub content { my ($translated_attribute) = @_;  ... }
# $fb->label($attribute, \%options, \&content);   sub content { my ( $translated_attribute) = @_;  ... }

sub label {
  my ($self, $attribute) = (shift, shift);
  my ($options, $content) = (+{}, (my $translated_attribute = $self->human_name_for_attribute($attribute)));
  while(my $arg = shift) {
    $options = $arg if (ref($arg)||'') eq 'HASH';
    $content = $arg if (ref($arg)||'') eq 'CODE';
    $content = $arg if (ref(\$arg)||'') eq 'SCALAR';
  }

  set_unless_defined(for => $options, $self->tag_id_for_attribute($attribute));

  if((ref($content)||'') eq 'CODE') {
    return Valiant::HTML::FormTags::label_tag($attribute, $options, sub { $content->($translated_attribute) } );
  } else {
    return Valiant::HTML::FormTags::label_tag($attribute, $content, $options);
  }
}

# $fb->errors_for($attribute)
# $fb->errors_for($attribute, \%options)
# $fb->errors_for($attribute, \%options, \&template)
# $fb->errors_for($attribute, \&template)

sub errors_for {
  my ($self, $attribute) = (shift, shift);
  my ($options, $content) = (+{}, undef);
  while(my $arg = shift) {
    $options = $arg if (ref($arg)||'') eq 'HASH';
    $content = $arg if (ref($arg)||'') eq 'CODE';
  }

  die "Can't display errors on a model that doesn't support the errors method" unless $self->model->can('errors');

  my @errors = $self->model->errors->full_messages_for($attribute);
  return '' unless @errors;
  
  my $max_errors = exists($options->{max_errors}) ? delete($options->{max_errors}) : undef;
  @errors = @errors[0..($max_errors-1)] if($max_errors);
  $content = $self->_default_errors_for_content($options) unless defined($content);

  return $content->(@errors);  
}

sub _default_errors_for_content {
  my ($self, $options) = @_;
  return sub {
    my (@errors) = @_;
    if( scalar(@errors) == 1 ) {
       return Valiant::HTML::TagBuilder::content_tag 'div', $errors[0], $options;
    } else {
       return Valiant::HTML::TagBuilder::content_tag 'ol', $options, sub { map { Valiant::HTML::TagBuilder::content_tag('li', $_) } @errors };
    }
  }
}

# $fb->input($attribute, \%options)
# $fb->input($attribute)

sub input {
  my ($self, $attribute, $options) = (shift, shift, (@_ ? shift : +{}));
  my $errors_classes = exists($options->{errors_classes}) ? delete($options->{errors_classes}) : undef;
  
  $options->{class} = join(' ', (grep { defined $_ } $options->{class}, $errors_classes))
    if $self->model->can('errors') && $self->model->errors->where($attribute);

  set_unless_defined(type => $options, 'text');
  set_unless_defined(id => $options, $self->tag_id_for_attribute($attribute));
  set_unless_defined(name => $options, $self->tag_name_for_attribute($attribute));
  $options->{value} = $self->tag_value_for_attribute($attribute) unless defined($options->{value});

  return Valiant::HTML::FormTags::input_tag $attribute, $options;
}

sub password {
  my ($self, $attribute, $options) = (shift, shift, (@_ ? shift : +{}));
  $options->{type} = 'password';
  $options->{value} = '';
  return $self->input($attribute, $options);
}

sub hidden {
  my ($self, $attribute, $options) = (shift, shift, (@_ ? shift : +{}));
  $options->{type} = 'hidden';
  return $self->input($attribute, $options);
}

sub text_area {
  my ($self, $attribute, $options) = (shift, shift, (@_ ? shift : +{}));
  my @errors_classes = (@{ delete($options->{errors_classes}) || [] });
  
  $options->{class} = join(' ', (grep { defined $_ } $options->{class}, @errors_classes))
    if $self->model->can('errors') && $self->model->errors->where($attribute);

  set_unless_defined(id => $options, $self->tag_id_for_attribute($attribute));
  return Valiant::HTML::FormTags::text_area_tag(
    $self->tag_name_for_attribute($attribute),
    $self->tag_value_for_attribute($attribute),
    $options,
  );
}

sub checkbox {
  my ($self, $attribute) = (shift, shift);
  my $options = (ref($_[0])||'') eq 'HASH' ? shift(@_) : +{};
  my $checked_value = @_ ? shift : 1;
  my $unchecked_value = @_ ? shift : 0;
  my @errors_classes = (@{ delete($options->{errors_classes}) || [] });
  my $show_hidden_unchecked = exists($options->{include_hidden}) ? delete($options->{include_hidden}) : 1;
  my $name = $self->tag_name_for_attribute($attribute);

  my $checked = 0;
  if(exists($options->{checked})) {
    $checked = delete $options->{checked};
  } else {
    $checked = $self->tag_value_for_attribute($attribute) ? 1:0;
  }

  $options->{type} = 'checkbox';
  $options->{value} = $checked_value unless exists($options->{value});
  $options->{class} = join(' ', (grep { defined $_ } $options->{class}, @errors_classes))
    if $self->model->can('errors') && $self->model->errors->where($attribute);

  set_unless_defined(id => $options, $self->tag_id_for_attribute($attribute));

  my $checkbox = Valiant::HTML::FormTags::checkbox_tag(
    $name,
    $checked_value,
    $checked,
    $options,
  );

  if($show_hidden_unchecked) {
    my $hidden_name = exists($options->{name}) ? $options->{name} : $name;
    $checkbox = Valiant::HTML::TagBuilder::tag('input', +{type=>'hidden', name=>$hidden_name, value=>$unchecked_value})->concat($checkbox);
  }

  return $checkbox;
}

#radio_button(object_name, method, tag_value, options = {})

sub radio_button {
  my ($self, $attribute) = (shift, shift);
  my $options = (ref($_[-1])||'') eq 'HASH' ? pop(@_) : +{};
  my $value = @_ ? shift : undef;

  $options->{type} = 'radio';
  $options->{value} = $value unless exists($options->{value});
  $options->{checked} = $self->tag_value_for_attribute($attribute) eq $value ? 1:0;
  $options->{id} = $self->tag_id_for_attribute($attribute, $value);

  return $self->input($attribute, $options);
}
 
sub date_field {
  my ($self, $attribute, $options) = (@_, +{});
  my $value = $self->tag_value_for_attribute($attribute);

  $options->{type} = 'date';
  $options->{value} ||= Scalar::Util::blessed($value) ? $value->ymd : $value;
  $options->{min} = $options->{min}->ymd if exists($options->{min}) && Scalar::Util::blessed($options->{min});
  $options->{max} = $options->{max}->ymd if exists($options->{max}) && Scalar::Util::blessed($options->{max});

  return $self->input($attribute, $options);
}

sub datetime_local_field {
  my ($self, $attribute, $options) = (@_, +{});
  my $value = $self->tag_value_for_attribute($attribute);

  $options->{type} = 'datetime-local';
  $options->{value} ||= Scalar::Util::blessed($value) ? $value->strftime('%Y-%m-%dT%T') : $value;
  $options->{min} = $options->{min}->strftime('%Y-%m-%dT%T') if exists($options->{min}) && Scalar::Util::blessed($options->{min});
  $options->{max} = $options->{max}->strftime('%Y-%m-%dT%T') if exists($options->{max}) && Scalar::Util::blessed($options->{max});

  return $self->input($attribute, $options);
}

sub time_field {
  my ($self, $attribute, $options) = (@_, +{});
  my $value = $self->tag_value_for_attribute($attribute);
  my $format = (exists($options->{include_seconds}) && !delete($options->{include_seconds})) ? '%H:%M' : '%T.%3N';

  $options->{type} = 'time';
  $options->{value} ||= Scalar::Util::blessed($value) ? $value->strftime($format) : $value;

  return $self->input($attribute, $options);
}

sub submit {
  my ($self) = shift;
  my $options = pop(@_) if (ref($_[-1])||'') eq 'HASH';
  my $value = @_ ? shift(@_) : $self->_submit_default_value;
  return Valiant::HTML::FormTags::submit_tag($value, $options);
}

sub _humanize {
  my $value = shift;
  $value =~s/_id$//; # remove trailing _id
  $value =~s/_/ /g;
  return ucfirst($value);
}

sub _submit_default_value {
  my $self = shift;
  my $model = $self->model->can('to_model') ? $self->model->to_model : $self->model;
  my $key = $model->can('in_storage') ? ( $model->in_storage ? 'update':'create' ) : 'submit';
  my $model_placeholder = $model->can('model_name') ? $model->model_name->human : _humanize($self->name);

  my @defaults = ();

  push @defaults, _t "formbuilder.submit.@{[ $self->name ]}.${key}";
  push @defaults, _t "formbuilder.submit.${key}";
  push @defaults, "@{[ _humanize($key) ]} ${model_placeholder}";

  return $self->model->i18n->translate(
      shift(@defaults),
      model=>$model_placeholder,
      default=>\@defaults,
    );
}

# ->button($name, \%attrs, \&block)
# ->button($name, \%attrs, $content)
# ->button($name, \&block)
# ->button($name, $content)

sub button {
  my $self = shift;
  my $attribute = shift;
  my $attrs = (ref($_[0])||'') eq 'HASH' ? shift(@_) : +{};
  my $content = shift;

  $attrs->{type} = 'submit' unless exists($attrs->{type});
  $attrs->{value} = $self->tag_value_for_attribute($attribute) unless exists($attrs->{value});
  $attrs->{name} = $self->tag_name_for_attribute($attribute) unless exists($attrs->{name});
  $attrs->{id} = $self->tag_id_for_attribute($attribute) unless exists($attrs->{id});

  return ref($content) ? Valiant::HTML::FormTags::button_tag($attrs, $content) : Valiant::HTML::FormTags::button_tag($content, $attrs);
}

sub legend {
  my ($self) = shift;
  my $options = pop(@_) if (ref($_[-1])||'') eq 'HASH';
  my $value = @_ ? shift(@_) : $self->_legend_default_value;
  return Valiant::HTML::FormTags::legend_tag($value, $options);
}

sub _legend_default_value {
  my $self = shift;
  my $model = $self->model->can('to_model') ? $self->model->to_model : $self->model;
  my $key = $model->can('in_storage') ? ( $model->in_storage ? 'update':'create' ) : 'new';
  my $model_placeholder = $model->can('model_name') ? $model->model_name->human : _humanize($self->name);

  my @defaults = ();

  push @defaults, _t "formbuilder.legend.@{[ $self->name ]}.${key}";
  push @defaults, _t "formbuilder.legend.${key}";
  push @defaults, "@{[ _humanize($key) ]} ${model_placeholder}";

  return $self->model->i18n->translate(
      shift(@defaults),
      model=>$model_placeholder,
      default=>\@defaults,
    );
}

# fields_for($related_attribute, ?\%options?, \&block)
sub fields_for {
  my ($self, $related_attribute) = (shift, shift);
  my $options = (ref($_[0])||'') eq 'HASH' ? shift(@_) : +{};
  my $codeblock = (ref($_[0])||'') eq 'CODE' ? shift(@_) : die "Missing required code block";
  my $finally_block = (ref($_[0])||'') eq 'CODE' ? shift(@_) : undef;

  $options->{builder} = $self->options->{builder};
  $options->{namespace} = $self->namespace if $self->has_namespace;
  $options->{parent_builder} = $self;

  my $related_record = $self->tag_value_for_attribute($related_attribute);
  my $name = "@{[ $self->name ]}.@{[ $related_attribute ]}";

  $related_record = $related_record->to_model if Scalar::Util::blessed($related_record) && $related_record->can('to_model');

  # Coerce an array into a collection.  Not sure if we want this here or not TBH...
  $related_record = Valiant::HTML::Util::Collection->new(map { $_->can('to_model') ? $_->to_model : $_ } @$related_record)
    if (ref($related_record)||'') eq 'ARRAY';

  # Ok is the related record a collection or something else.
  if($related_record->can('next')) {
    my $output = undef;
    my $explicit_child_index = exists($options->{child_index}) ? $options->{child_index} : undef;

    while(my $child_model = $related_record->next) {
      if(defined($explicit_child_index)) {
        $options->{child_index} = $options->{child_index}->($child_model) if ref() eq 'CODE';  # allow for callback version of this
      } else {
        $options->{child_index} = $self->nested_child_index($related_attribute); 
      }
      my $nested = $self->fields_for_nested_model("${name}[@{[ $options->{child_index} ]}]", $child_model, $options, $codeblock);

      if(defined $output) {
        $output = $output->concat($nested);
      } else {
        $output = $nested;
      }
    }
    if($finally_block) {
      my $finally_model = $related_record->can('build') ? $related_record->build : die "Can't have a finally block if the collection doesn't support 'build'";
      my $finally_content = $self->fields_for_nested_model("${name}[]", $finally_model, $options, $finally_block);
      if(defined $output) {
        $output = $output->concat($finally_content);
      } else {
        $output = $finally_content;
      }

    }
    return defined($output) ? $output : '';
  } else {
    return $self->fields_for_nested_model($name, $related_record, $options, $codeblock);
  }
}

sub fields_for_nested_model {
  my ($self, $name, $model, $options, $codeblock) = @_;
  my $emit_hidden_id = 0;
  $model = $model->to_model if $model->can('to_model');

  if($model->can('in_storage') && $model->in_storage) {
    $emit_hidden_id = exists($options->{include_id}) ? $options->{include_id} : 1;
  }

  return Valiant::HTML::Form::fields_for($name, $model, $options, sub {
    my $fb = shift;
    my $output = Valiant::HTML::FormTags::capture($codeblock, $fb);
    if($output && $emit_hidden_id && $model->can('primary_columns')) {
      foreach my $id_field ($model->primary_columns) {
        $output = $output->concat($fb->hidden($id_field)); #TODO this cant be right...
      }
    }
    return $output;
  });
}

sub select {
  my ($self, $attribute) = (shift, shift);
  my $block = (ref($_[-1])||'') eq 'CODE' ? pop(@_) : undef;
  my $options = (ref($_[-1])||'') eq 'HASH' ? pop(@_) : +{};
  my $value = $self->tag_value_for_attribute($attribute);  # TODO handle multiple

  my $options_tags = '';
  if(!$block) {
    my $option_tags_proto = @_ ? shift : ();
    my @selected = ( @{$options->{selected}||[]}, $value);
    my @disabled = ( @{$options->{disabled}||[]});

    $options_tags = Valiant::HTML::FormTags::options_for_select($option_tags_proto, +{
      selected => \@selected,
      disabled => \@disabled,
    });
  } else {
    $options_tags = $block->($self->model, $attribute);
  }

  my $name = $self->tag_name_for_attribute($attribute);
  $options->{id} = $self->tag_id_for_attribute($attribute);

  return Valiant::HTML::FormTags::select_tag($name, $options_tags, $options);
}

#collection_select(object, method, collection, value_method, text_method, options = {}, html_options = {})
sub collection_select {
  my ($self, $method_proto, $collection) = (shift, shift, shift);
  my $options = (ref($_[-1])||'') eq 'HASH' ? pop(@_) : +{};
  my ($value_method, $label_method) = (@_, 'value', 'label');
  my $model = $self->model->can('to_model') ? $self->model->to_model : $self->model;

  my (@selected, $name, $id) = @_;
  if(ref $method_proto) {
    $options->{multiple} = 1 unless exists($options->{multiple});
    $options->{include_hidden} = 0 unless exists($options->{include_hidden}); # Avoid adding two
    my ($bridge, $value_method) = %$method_proto;
    my $collection = $model->$bridge;
    while(my $item = $collection->next) {
      push @selected, $item->$value_method;
    }
    $name = $self->tag_name_for_attribute($bridge, +{multiple=>1}) . ".$value_method";
    $options->{id} = $self->tag_id_for_attribute($bridge) . "_$value_method" unless exists $options->{id};
  } else {
    my $value = $self->tag_value_for_attribute($method_proto);
    my $errors_classes = exists($options->{errors_classes}) ? delete($options->{errors_classes}) : undef;
    $options->{class} = join(' ', (grep { defined $_ } $options->{class}, $errors_classes))
      if $model->can('errors') && $model->errors->where($method_proto);

    if((ref($value)||'') eq 'ARRAY') {
      @selected = @$value;
      $options->{multiple} = 1 unless exists($options->{multiple});
    } elsif(defined($value)) {
      @selected = ($value);
    } else {
      @selected = ();
    }

    $name = $self->tag_name_for_attribute($method_proto);
    $id = $self->tag_id_for_attribute($method_proto);
  }

  my $select_tag = Valiant::HTML::FormTags::select_tag(
    $name,
    Valiant::HTML::FormTags::options_from_collection_for_select($collection, $value_method, $label_method, \@selected),
    $options);

  if(ref($method_proto)) {
    #$select_tag = $self->hidden($name, '', +{id=>$options->{id}.'_hidden'})->concat($select_tag);    
  }

  return $select_tag;
}

# $fb->collection_checkbox({person_roles => role_id}, $roles_rs, $value_method, $text_method, \%options, \&block);
# $fb->collection_checkbox({person_roles => role_id}, $roles_rs, $value_method, $text_method, \%options, \&block);
sub collection_checkbox {
  my ($self, $attribute_spec, $collection) = (shift, shift, shift);
  my $codeblock = (ref($_[-1])||'') eq 'CODE' ? pop(@_) : undef;
  my $options = (ref($_[-1])||'') eq 'HASH' ? pop(@_) : +{};
  my ($value_method, $label_method) = (@_, 'value', 'label');
  my ($attribute, $attribute_value_method) = %{ $attribute_spec }; # TODO if just a collection then $attribute_value_method is $valid_method
  my $model = $self->model->can('to_model') ? $self->model->to_model : $self->model;

  $codeblock = $self->_default_collection_checkbox_content unless defined($codeblock);

  my @checked_values = ();
  my $value_collection = $self->tag_value_for_attribute($attribute);
  while(my $value_model = $value_collection->next) {
    push @checked_values, $value_model->$attribute_value_method unless $value_model->is_marked_for_deletion;
  }

  my @checkboxes = ();
  my $checkbox_builder_options = +{
    builder => (exists($options->{builder}) ? $options->{builder} : 'Valiant::HTML::FormBuilder::Checkbox'),
    value_method => $value_method,
    label_method => $label_method,
    attribute_value_method => $attribute_value_method,
    parent_builder => $self,
  };
  $checkbox_builder_options->{namespace} = $self->namespace if $self->has_namespace;

  while (my $checkbox_model = $collection->next) {
    my $index = $self->nested_child_index($attribute); 
    my $name = "@{[ $self->name ]}.${attribute}";
    my $checked = grep { $_ eq $checkbox_model->$value_method } @checked_values;

    unless(@checkboxes) { # Add nop as first to handle empty list
      my $hidden_fb = Valiant::HTML::Form::_instantiate_builder($name, $value_collection->build, {index=>$index});
      push @checkboxes, $hidden_fb->hidden('_nop', +{value=>'1'});
      $index = $self->nested_child_index($attribute);
    }

    $checkbox_builder_options->{index} = $index;
    $checkbox_builder_options->{checked} = $checked;

    my $checkbox_fb = Valiant::HTML::Form::_instantiate_builder($name, $checkbox_model, $checkbox_builder_options);
    push @checkboxes, $codeblock->($checkbox_fb);
  }
  $collection->reset if $collection->can('reset');
  return shift(@checkboxes)->concat(@checkboxes);
}

sub _default_collection_checkbox_content {
  my ($self) = @_;
  return sub {
    my ($fb) = @_;
    my $label = $fb->label;
    my $checkbox = $fb->checkbox;
    return $label->concat($checkbox);
  };
}

{
  package Valiant::HTML::FormBuilder::Checkbox;

  use Moo;
  extends 'Valiant::HTML::FormBuilder';

  sub text { 
    my $self = shift;
    return $self->tag_value_for_attribute($self->options->{label_method});
  }

  sub value { 
    my $self = shift;
    return $self->tag_value_for_attribute($self->options->{value_method});
  }

  around 'label', sub {
    my ($orig, $self, $attrs) = @_;
    $attrs = +{} unless defined($attrs);
    return $self->$orig($self->options->{attribute_value_method}, $attrs, $self->text);
  };

  around 'checkbox', sub {
    my ($orig, $self, $attrs) = @_;
    $attrs = +{} unless defined($attrs);
    $attrs->{name} = $self->tag_name_for_attribute($self->options->{attribute_value_method});
    $attrs->{id} = $self->tag_id_for_attribute($self->options->{attribute_value_method});
    $attrs->{include_hidden} = 0;;
    $attrs->{checked} = $self->options->{checked};

    return $self->$orig($self->options->{value_method}, $attrs, $self->value);
  };
}

# select collection needs work
# radiogrounp collection neede to be done
# ?? date and date time helpers (month field, etc) ??

1;

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

