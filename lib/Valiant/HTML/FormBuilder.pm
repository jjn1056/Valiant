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

has model => ( is => 'ro', required => 1);
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

sub DEFAULT_MODEL_ERROR_MSG_ON_FIELD_ERRORS { return 'Your form has errors' }
sub DEFAULT_MODEL_ERROR_TAG_ON_FIELD_ERRORS { return 'invalid_form' }
sub DEFAULT_COLLECTION_CHECKBOX_BUILDER { return 'Valiant::HTML::FormBuilder::Checkbox' }
sub DEFAULT_COLLECTION_RADIO_BUTTON_BUILDER { return 'Valiant::HTML::FormBuilder::RadioButton' }

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

  my @errors = $self->_get_model_errors;

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

sub _get_model_errors {
  my ($self) = @_;
  return my @errors = $self->model->errors->model_messages;
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
  my $model = $self->model->can('to_model') ? $self->model->to_model : $self->model;
  
  $options->{class} = join(' ', (grep { defined $_ } $options->{class}, $errors_classes))
    if $errors_classes && $model->can('errors') && $model->errors->where($attribute);

  set_unless_defined(type => $options, 'text');
  set_unless_defined(id => $options, $self->tag_id_for_attribute($attribute));
  set_unless_defined(name => $options, $self->tag_name_for_attribute($attribute));
  $options->{value} = $self->tag_value_for_attribute($attribute) unless defined($options->{value});

  return Valiant::HTML::FormTags::input_tag $attribute, $options;
}

sub password {
  my ($self, $attribute, $options) = (shift, shift, (@_ ? shift : +{}));
  $options->{type} = 'password';
  $options->{value} = '' unless exists($options->{value});
  return $self->input($attribute, $options);
}

sub hidden {
  my ($self, $attribute, $options) = (shift, shift, (@_ ? shift : +{}));
  $options->{type} = 'hidden';
  return $self->input($attribute, $options);
}

sub text_area {
  my ($self, $attribute, $options) = (shift, shift, (@_ ? shift : +{}));
  my $errors_classes = exists($options->{errors_classes}) ? delete($options->{errors_classes}) : undef;
  
  $options->{class} = join(' ', (grep { defined $_ } $options->{class}, $errors_classes))
    if $errors_classes && $self->model->can('errors') && $self->model->errors->where($attribute);

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
  $options->{checked} = do { $self->tag_value_for_attribute($attribute) eq $value ? 1:0 } unless exists($options->{checked});
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

  return "@{[ _humanize($key) ]} ${model_placeholder}" unless $self->model->can('i18n');

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
  my $value_method = @_ ? shift(@_) : 'value';
  my $label_method = @_ ? shift(@_) : 'label';
  my $model = $self->model->can('to_model') ? $self->model->to_model : $self->model;

  # It's either +{ person_roles => role_id } or roles 
  my ($attribute, $attribute_value_method) = ();
  if( (ref($attribute_spec)||'') eq 'HASH' ) {
    ($attribute, $attribute_value_method) = (%{ $attribute_spec });
  } else {
    $attribute = $attribute_spec;
    $attribute_value_method = $value_method;
  }

  $codeblock = $self->_default_collection_checkbox_content unless defined($codeblock);

  my @checked_values = ();
  my $value_collection = $self->tag_value_for_attribute($attribute);
  while(my $value_model = $value_collection->next) {
    push @checked_values, $value_model->$attribute_value_method unless $value_model->is_marked_for_deletion;
  }

  my @checkboxes = ();
  my $checkbox_builder_options = +{
    builder => (exists($options->{builder}) ? $options->{builder} : $self->DEFAULT_COLLECTION_CHECKBOX_BUILDER),
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

sub collection_radio_buttons {
  my ($self, $attribute, $collection) = (shift, shift, shift);
  my $codeblock = (ref($_[-1])||'') eq 'CODE' ? pop(@_) : undef;
  my $options = (ref($_[-1])||'') eq 'HASH' ? pop(@_) : +{};
  my $value_method = @_ ? shift(@_) : 'value';
  my $label_method = @_ ? shift(@_) : 'label';
  my $model = $self->model->can('to_model') ? $self->model->to_model : $self->model;
  my $checked_value = exists($options->{checked_value}) ? $options->{checked_value} : $self->tag_value_for_attribute($attribute);

  $codeblock = $self->_default_collection_radio_buttons_content unless defined($codeblock);

  my @radio_buttons = ();
  my $radio_buttons_builder_options = +{
    builder => (exists($options->{builder}) ? $options->{builder} : $self->DEFAULT_COLLECTION_RADIO_BUTTON_BUILDER),
    value_method => $value_method,
    label_method => $label_method,
    checked_value => $checked_value,
    parent_builder => $self,
  };
  $radio_buttons_builder_options->{namespace} = $self->namespace if $self->has_namespace;

  while (my $radio_button_model = $collection->next) {
    my $name = "@{[ $self->name ]}.${attribute}";
    my $checked = $radio_button_model->$value_method eq $checked_value ? 1:0;

    unless(@radio_buttons) { # Add nop as first to handle empty list
      my $hidden_fb = Valiant::HTML::Form::_instantiate_builder($name, $model);
      push @radio_buttons, $hidden_fb->hidden($name, +{name=>$name, id=>$self->tag_id_for_attribute($attribute).'_hidden', value=>''});
    }

    $radio_buttons_builder_options->{checked} = $checked;

    my $radio_button_fb = Valiant::HTML::Form::_instantiate_builder($name, $radio_button_model, $radio_buttons_builder_options);
    push @radio_buttons, $codeblock->($radio_button_fb);
  }
  $collection->reset if $collection->can('reset');
  return shift(@radio_buttons)->concat(@radio_buttons);
}

sub _default_collection_radio_buttons_content {
  my ($self) = @_;
  return sub {
    my ($fb) = @_;
    my $label = $fb->label();
    my $checkbox = $fb->radio_button();
    return $label->concat($checkbox);
  };
}


# select collection needs work (with multiple)
# select with opt grounps needs to work
# ?? date and date time helpers (month field, weeks, etc) ??

1;


=head1 NAME

Valiant::HTML::Formbuilder - General HTML Forms

=head1 SYNOPSIS

Given a model with the correct API such as:

    package Local::Person;

    use Moo;
    use Valiant::Validations;

    has first_name => (is=>'ro');
    has last_name => (is=>'ro');

    validates ['first_name', 'last_name'] => (
      length => {
        maximum => 10,
        minimum => 3,
      }
    );

Wrap a formbuilder object around it and generate HTML form field controls:

    my $person = Local::Person->new(first_name=>'J', last_name=>'Napiorkowski');
    $person->validate;

    my $fb = Valiant::HTML::FormBuilder->new(
      model => $person,
      name => 'person'
    );

    print $fb->input('first_name');
    # <input id="person_first_name" name="person.first_name" type="text" value="J"/> 

    print $fb->errors_for('first_name');
    # <div>First Name is too short (minimum is 3 characters)</div> 

Although you can create a formbuilder instance directly as in the above example you might
find it easier to use the export helper method L<Valiant::HTML::Form/form_for> which encapsulates
the display logic needed for creating the C<form> tags.  This builder creates form tag elements
but not the actual C<form> open and close tags.  

=head1 DESCRIPTION

This class wraps an underlying data model and makes it easy to build HTML form elements based on
the state of that model.  Inspiration for this design come from Ruby on Rails Formbuilder as well
as similar designs in the Phoenix Framework.

You can subclass this to future customize how your form elements display as well as to add more complex
form elements for your templates.

Documentation here is basically API level, a more detailed tutorial will follow eventually but for now
you'll need to review the source, test cases and example application bundled with this distribution
for for hand holding.

Currently this is designed to work mostly with the L<Valiant> model validation framework as well as the
glue for L<DBIx:Class>, L<DBIx:Class::Valiant>, although I did take pains to try and make the API
agnostic many of the test cases are assuming that stack and getting that integration working well is
the primary use case for me.  Thoughts and code to make this more stand alone are very welcomed.

=head1 ATTRIBUTES

This class defines the following attributes used in creating an instance.

=head2 model

This is the data model that the formbuilder inspects for field state and error conditions.   This should be
a model that does the API described here: L<Valiant::HTML::Form/'REQUIRED MODEL API'>. Required but the API
is pretty flexible (see docs).

Please note that my initial use case for this is using L<Valiant> for validation and L<DBIx::Class> as the
model (via L<DBIx:Class::Valiant>) so that combination has the most testing and examples.   If you are using
a different storage or validation setup you need to complete the API described.  Please send test cases
and pull requests to improve interoperability!

=head2 name

This is a string which is the internal name given to the model.  This is used to set a namespace for form
field C<name> attributes and the default namespace for C<id> attributes.  Required.

=head2 options

A optional hashref of options used in form field generation.   Some of these might become attributes in the
future.  Here's a list of the current options

=over 4

=item index

The index of the formbuilder when it is a sub formbuilder with a parent and we are iterating over a collection.

=item child_index

When creating a sub formbuilder that is an element in a collection, this is used to pass the index value

=item builder

The package name of the current builder

=item parent_builder

The parent formbuilder instance to a sub builder.

=item include_id

Used to indicated that a sub formbuilder should add hidden fields indicating the storage ID for the current model.

=item namespace

The ID namespace; used to populate the C<namespace> attribute.

=item as

Used to override how the class and ids are made for your forms.

=back

=head2 index

The current index of a collection for which the current formbuilder is one item in.

=head2 namespace

Used to add a prefix to the ID for your form elements.

=head1 METHODS

This class defines the following public instance methods.

=head2 model_errors

    $fb->model_errors();
    $fb->model_errors(\%attrs);
    $fb->model_errors(\%attrs, \&template); # %attrs limited to 'max_errors' and 'show_message_on_field_errors'
    $fb->model_errors(\&template);

Display model level errors, either with a default or custom template.  'Model' errors are
errors that are not associated with a model attribute in particular, but rather the model
as a whole.

Arguments to this method are optional.  "\%attrs" is a hashref which is passed to the tag 
builder to create any needed HTML attributes (such as class and style). "\&template" is
a coderef that gets the @errors as an argument and you can use it to customize how the errors
are displayed.  Otherwise we use a default template that lists the errors with an HTML ordered
list, or a C<div> if there's only one error.

"\%attrs" can also contain two options that gives you some additional control over the display

=over

=item max_errors

Don't display more than a certain number of errors

=item show_message_on_field_errors

Sometimes you want a global message displayed when there are field errors.  L<Valiant> doesn't
add a model error if there's field errors (although it would be easy for you to add this yourself
with a model validation) so this makes it easy to display such a message.  If a string or translation
tag then show that, if its a '1' the show the default message, which is "Form has errors" unless
you overide it.

=back

Examples.  Assume two model level errors "Trouble 1" and "Trouble 2":

    $fb->model_errors;
    # <ol><li>Trouble 1</li><li>Trouble 2</li></ol>

    $fb->model_errors({class=>'foo'});
    # <ol class="foo"><li>Trouble 1</li><li>Trouble 2</li></ol>

    $fb->model_errors({max_errors=>1});
    # <div>Trouble 1</div>

    $fb->model_errors({max_errors=>1, class=>'foo'})
    # <div class="foo">Trouble 1</div>

    $fb->model_errors({show_message_on_field_errors=>1})
    # <ol><li>Form has errors</li><li>Trouble 1</li><li>Trouble 2</li></ol>

    $fb->model_errors({show_message_on_field_errors=>"Bad!"})
    # <ol><li>Bad!</li><li>Trouble 1</li><li>Trouble 2</li></ol>

    $fb->model_errors(sub {
      my (@errors) = @_;
      join " | ", @errors;
    });
    # Trouble 1 | Trouble 2

=head2 label

    $fb->label($attribute)
    $fb->label($attribute, \%options)
    $fb->label($attribute, $content)
    $fb->label($attribute, \%options, $content) 
    $fb->label($attribute, \&content);   sub content { my ($translated_attribute) = @_;  ... }
    $fb->label($attribute, \%options, \&content);   sub content { my ( $translated_attribute) = @_;  ... }

Creates a HTML form element C<label> with the given "\%options" passed to the tag builder to
create HTML attributes and an optional "$content".  If "$content" is not provided we use the
human, translated (if available) version of the "$attribute" for the C<label> content.  Alternatively
you can provide a template which is a subroutine reference which recieves the translated attribute
as an argument.  Examples:

    $fb->label('first_name');
    # <label for="person_first_name">First Name</label>

    $fb->label('first_name', {class=>'foo'});
    # <label class="foo" for="person_first_name">First Name</label>

    $fb->label('first_name', 'Your First Name');
    # <label for="person_first_name">Your First Name</label>

    $fb->label('first_name', {class=>'foo'}, 'Your First Name');
    # <label class="foo" for="person_first_name">Your First Name</label>

    $fb->label('first_name', sub {
      my $translated_attribute = shift;
      return "$translated_attribute ",
        $fb->input('first_name');
    });
    # <label for="person_first_name">
    #   First Name 
    #   <input id="person_first_name" name="person.first_name" type="text" value="John"/>
    # </label>

    $fb->label('first_name', +{class=>'foo'}, sub {
      my $translated_attribute = shift;
      return "$translated_attribute ",
        $fb->input('first_name');
    });
    # <label class="foo" for="person_first_name">
    #   First Name
    #   <input id="person_first_name" name="person.first_name" type="text" value="John"/>
    # </label>

=head2 errors_for

    $fb->errors_for($attribute)
    $fb->errors_for($attribute, \%options)
    $fb->errors_for($attribute, \%options, \&template)
    $fb->errors_for($attribute, \&template)

Similar to L</model_errors> but for errors associated with an attribute of a model.  Accepts
the $attribute name, a hashref of \%options (used to set options controling the display of
errors as well as used by the tag builder to create HTML attributes for the containing tag) and
lastly an optional \&template which is a subroutine reference that received an array of the
translated errors for when you need very custom error display.  If omitted we use a default
template displaying errors in an ordered list (if more than one) or wrapped in a C<div> tag
(if only one error).

\%options used for error display and which are not passed to the tag builder as HTML attributes:

=over

=item max_errors

Don't display more than a certain number of errors

=back

Assume the attribute 'last_name' has the following two errors in the given examples: "first Name
is too short", "First Name contains non alphabetic characters".

    $fb->errors_for('first_name');
    # <ol><li>First Name is too short (minimum is 3 characters)</li><li>First Name contains non alphabetic characters</li></ol>

    $fb->errors_for('first_name', {class=>'foo'});
    # <ol class="foo"><li>First Name is too short (minimum is 3 characters)</li><li>First Name contains non alphabetic characters</li></ol>

    $fb->errors_for('first_name', {class=>'foo', max_errors=>1});
    # <div class="foo">First Name is too short (minimum is 3 characters)</div>

    $fb->errors_for('first_name', sub {
      my (@errors) = @_;
      join " | ", @errors;
    });
    # First Name is too short (minimum is 3 characters) | First Name contains non alphabetic characters

=head2 input

    $fb->input($attribute, \%options)
    $fb->input($attribute)

Create an C<input> form tag using the $attribute's value (if any) and optionally passing a hashref of
\%options which are passed to the tag builder to create HTML attributes for the C<input> tag.  Optionally
add C<errors_classes> which is a string that is appended to the C<class> attribute when the $attribute has
errors.  Examples:

    $fb->input('first_name');
    # <input id="person_first_name" name="person.first_name" type="text" value="J"/>

    $fb->input('first_name', {class=>'foo'});
    # <input class="foo" id="person_first_name" name="person.first_name" type="text" value="J"/>

    $fb->input('first_name', {errors_classes=>'error'});
    # <input class="error" id="person_first_name" name="person.first_name" type="text" value="J"/>

    $fb->input('first_name', {class=>'foo', errors_classes=>'error'});
    # <input class="foo error" id="person_first_name" name="person.first_name" type="text" value="J"/>

=head2 password

    $fb->password($attribute, \%options)
    $fb->password($attribute)

Create a C<password> HTML form field.   Similar to L</input> but sets the C<type> to 'password' and also
sets C<value> to '' since generally you don't want to show the current password (and if you are doing the
right thing and saving a 1 way hash not the plain text you don't even have it to show anyway).

Example:

    $fb->password('password');
    # <input id="person_password" name="person.password" type="password" value=""/>

    $fb->password('password', {class='foo'});
    # <input class="foo" id="person_password" name="person.password" type="password" value=""/>

    $fb->password('password', {class='foo', errors_classes=>'error'});
    # <input class="foo error" id="person_password" name="person.password" type="password" value=""/>

=head2 hidden

    $fb->hidden($attribute, \%options)
    $fb->hidden($attribute)

Create a C<hidden> HTML form field.   Similar to L</input> but sets the C<type> to 'hidden'.

    $fb->hidden('id');
    # <input id="person_id name="person.id" type="hidden" value="101"/>

    $fb->hidden('id', {class='foo'});
    # <input class="foo" id="person_id name="person.id" type="hidden" value="101"/>

=head2 text_area

    $fb->text_area($attribute);
    $fb->text_area($attribute, \%options);

Create an HTML C<text_area> tag based on the attribute value and with optional \%options
which is a a hashref passed to the tag builder for generating HTML attributes.   Can also set
C<errors_classes> that will append a string of additional CSS classes when the $attribute has
errors.  Examples:

    $fb->text_area('comments');
    # <textarea id="person_comments" name="person.comments">J</textarea>

    $fb->text_area('comments', {class=>'foo'});
    # <textarea class="foo" id="person_comments" name="person.comments">J</textarea>

    $fb->text_area('comments', {class=>'foo', errors_classes=>'error'});
    # <textarea class="foo error" id="person_comments" name="person.comments">J</textarea>



=head1 SEE ALSO

L<Valiant>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

