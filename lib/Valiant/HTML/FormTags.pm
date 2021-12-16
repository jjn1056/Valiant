package Valiant::HTML::FormTags;

{
  package Valiant::HTML::FormTags::raw;

    sub concat {
      my $self = shift;
      my $target = join '', map { $$_ } @_;
      return bless \"${$self}${target}", 'Valiant::HTML::FormTags::raw';
    }

    sub to_string {
      my $self = shift;
      return $$self;
    }
}

use warnings;
use strict;
use Exporter 'import'; # gives you Exporter's import() method directly
use String::CamelCase qw(decamelize wordsplit);
use HTML::Escape 'escape_html';
use Module::Runtime 'use_module';

our @EXPORT_OK = qw(
  tag content_tag raw input_tag color_input_tag date_input_tag datetime_input_tag email_input_tag
  file_field_tag hidden_field_tag button_tag checkbox_tag fieldset_tag form_tag label_tag
  radio_button_tag month_field_tag number_field_tag password_field_tag range_field_tag search_field_tag
  week_field_tag url_field_tag time_field_tag text_area_tag submit_tag select_tag options_for_select
  form_for _merge_attrs CONTENT_ARGS_KEY _e
);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

our $CONTENT_ARGS_KEY = 'content_args';
sub CONTENT_ARGS_KEY { $CONTENT_ARGS_KEY }

our $DEFAULT_SUBMIT_TAG_VALUE = 'Save changes';
sub DEFAULT_SUBMIT_TAG_VALUE { return $DEFAULT_SUBMIT_TAG_VALUE }

our $DEFAULT_OPTIONS_DELIM = "";
sub DEFAULT_OPTIONS_DELIM { return $DEFAULT_OPTIONS_DELIM }

our $DEFAULT_FORMBUILDER = 'Valiant::HTML::FormBuilder';
sub DEFAULT_FORMBUILDER { return $DEFAULT_FORMBUILDER }

our $DEFAULT_ID_DELIM = '_';
sub DEFAULT_ID_DELIM { return $DEFAULT_ID_DELIM } 

our @ATTRIBUTES_NEEDING_ESCAPING = qw(value);
sub _normalize_attrs {
  my %attrs = ref($_[0]) ? %{$_[0]} : @_;

  if(my $data = delete $attrs{data}) {
      foreach my $dataset_attr_proto (keys %$data) {
        my $dataset_key = join('-', wordsplit(decamelize($dataset_attr_proto)));
        $attrs{"data-${dataset_key}"} = $data->{$dataset_attr_proto};
      }
  }
  if( (ref($attrs{class})||'') eq 'ARRAY') {
    my @classes = @{delete $attrs{class}};
    $attrs{class} = join ' ', @classes;
  }
  if( (ref($attrs{id})||'') eq 'ARRAY') {
    my @id = @{delete $attrs{id}};
    $attrs{id} = join '_', @id;
  }

  foreach my $attr (@ATTRIBUTES_NEEDING_ESCAPING) {
    $attrs{$attr} = _e($attrs{$attr}) if exists $attrs{$attr};
  }

  return %attrs;
}

sub _sanitize_name_to_id {
  my $name_attr = shift;
  $name_attr =~ s/\]//g;
  $name_attr =~ s/[^a-zA-Z0-9:.-]/_/g;
  return $name_attr;
}

sub _stringify_attrs {
  my %attrs = @_;
  return '' unless %attrs;
  return join ' ', map { qq|$_="$attrs{$_}"|} grep { defined($attrs{$_}) } sort keys %attrs;
}

# _merge_attrs does a smart merge of two hashrefs that represent HTML tag attributes.  This
# needs special processing since we need to merge 'data' and 'class' attributes with special
# rules.  For merging in general key/values in the second hashref will override those in the
# first (unless its a special attributes like 'data' or 'class'

sub _merge_attrs {
  my ($attrs1, $attrs2) = @_;
  foreach my $key (keys %{$attrs2||{}}) {
    if($key eq 'data') {
      my $data1 = exists($attrs1->{$key}) ? $attrs1->{$key} : +{};
      my $data2 = exists($attrs2->{$key}) ? $attrs2->{$key} : +{};
      $attrs1->{$key} = +{ %$data1, %$data2 };
    } elsif($key eq 'class') {
      my $class1 = exists($attrs1->{$key}) ? $attrs1->{$key} : [];
      $class1 = [$class1] unless ref $class1;
      my $class2 = exists($attrs2->{$key}) ? $attrs2->{$key} : [];
      $class2 = [$class2] unless ref $class2;
      $attrs1->{$key} = [ @$class1, @$class2 ];
    } elsif($key eq 'id') {
      my $id1 = exists($attrs1->{$key}) ? $attrs1->{$key} : [];
      $id1 = [$id1] unless ref $id1;
      my $id2 = exists($attrs2->{$key}) ? $attrs2->{$key} : [];
      $id2 = [$id2] unless ref $id2;
      $attrs1->{$key} = [ @$id1, @$id2 ];
    } else {
      $attrs1->{$key} = $attrs2->{$key};
    }
  }
  return $attrs1;
}

sub _e {
  my $value = shift;
  return ref($value)||'' eq 'Valiant::HTML::FormTags::raw' ? $$value : escape_html($value);
}

# raw $string
sub raw {
  my $value = shift;
  return bless \$value, 'Valiant::HTML::FormTags::raw';
}

# tag 'div';
# tag 'div', +{ class=>'container', id=>'content' }
sub tag {
  my $tag = shift;
  my %attrs = _normalize_attrs(@_);
  return _closed_tag($tag, %attrs);

}

sub _closed_tag {
  my ($tag, %attrs) = @_;
  return "<$tag @{[ _stringify_attrs(%attrs) ]}/>";
}

# content_tag($tag, \%attrs, $coderef_content_block)
# content_tag($tag, $raw_content, \%attrs)
sub content_tag {
  my $tag = shift;
  my $content = "";
  if( (ref($_[-1])||'') eq 'CODE' ) {
    $content = pop(@_);
  } else {
    my $raw_content = _e shift(@_);
    $content = sub { $raw_content };
  }
  my %attrs = _normalize_attrs(@_);
  return _tag_with_body($tag, $content, %attrs);
}

sub _tag_with_body {
  my ($tag, $content, %attrs) = @_;
  my @content_args = exists($attrs{CONTENT_ARGS_KEY}) ? @{delete $attrs{CONTENT_ARGS_KEY}} : ();
  my $body = _flattened_content($content->(@content_args));
  my $open_tag = %attrs ? "$tag @{[ _stringify_attrs(%attrs) ]}" : "$tag";
  return "<$open_tag>@{[ defined $body ? $body : '' ]}</$tag>";
}

sub _flattened_content {
  return join '', @_;
}


## GENERNIC FORM TAGS

# input_tag($name, $value = nil, \%attrs = {})
# input_tag($name, \%attrs = {})
# input_tag(\%attrs = {})

sub input_tag {
  my ($name, $value, $attrs) = (undef, undef, +{});
  $attrs = pop @_ if (ref($_[-1])||'') eq 'HASH';
  $name = shift @_ if @_;
  $value = shift @_ if @_;

  $attrs = _merge_attrs(+{type => "text", name => $name, value => $value}, $attrs);
  $attrs->{id} = _sanitize_name_to_id($attrs->{name}) if exists($attrs->{name}) && defined($attrs->{name}) && !exists($attrs->{id});
  return tag('input', $attrs);
}

sub color_input_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'color'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub date_input_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'date'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub datetime_input_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'datetime-local'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub email_input_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'email'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub file_field_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'file'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub hidden_field_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'hidden'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub month_field_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'month'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub number_field_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'number'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub range_field_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'range'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub password_field_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'password'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub search_field_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'search'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub week_field_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'week'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub url_field_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'url'}, $attrs);
  return input_tag('input', $value, $attrs);
}

sub time_field_tag {
  my ($name, $value, $attrs) = @_;
  $attrs = _merge_attrs(+{type => 'time'}, $attrs);
  return input_tag('input', $value, $attrs);
}

# checkbox_tag $name
# checkbox_tag $name, $attrs
# checkbox_tag $name, $value, $attrs
# checkbox_tag $name, $value, $checked, $attrs
# checkbox_tag $name, $value
# checkbox_tag $name, $value, $checked

sub checkbox_tag {
  my $name = shift;
  my ($value, $checked, $attrs) = (1, 0, +{});
  $attrs = pop(@_) if (ref($_[-1])||'') eq 'HASH';
  $value = shift(@_) if defined $_[0];
  $checked = shift(@_) if defined $_[0];
  $attrs = _merge_attrs(+{type => 'checkbox', name=>$name, id=>_sanitize_name_to_id($name), value=>$value}, $attrs);

  return tag('input', $attrs);
}

# button_tag('content', \%attrs)
# button_tag('content')
# button_tag(\%attrs, $content_block)
# button_tag($content_block)

sub button_tag {
  my ($content, $attrs) = (undef, +{});

  $attrs = shift @_ if (ref($_[0])||'') eq 'HASH';
  $content = shift @_ if (ref($_[0])||'') eq 'CODE';
  $content = shift @_ unless defined $content;
  $attrs = shift @_ if (ref($_[0])||'') eq 'HASH';
  $attrs = _merge_attrs(+{name => 'button'}, $attrs);

  return ref($content) ? content_tag('button', $attrs, $content) : content_tag('button', $content, $attrs)
}

# fieldset_tag $content_block
# fieldset_tag $attrs, $content_block
# fieldset_tag $legend, $attrs, $content_block
# fieldset_tag $legend, $content_block

sub fieldset_tag {
  my ($legend, $attrs, $content) = (undef, +{}, undef);
  $content = pop @_; # Required
  $attrs = pop @_ if (ref($_[-1])||'') eq 'HASH';
  $legend = shift @_ if @_;

  my $output = '';
  my @content_args = exists($attrs->{CONTENT_ARGS_KEY}) ? @{delete $attrs->{CONTENT_ARGS_KEY}} : ();
  $output .= content_tag('legend', $legend) if $legend;
  $output .= $content->(@content_args);

  return content_tag('fieldset', $attrs, sub { $output });
}

# form_tag '/signup', \%attrs, ?$content
# form_tag \@args, +{ uri_for=>sub {...}, %attrs }, ?$content

sub form_tag {
  my ($url_options, $attrs, $content) = @_;
  $attrs = _process_form_attrs($url_options, $attrs);
  return $content ? content_tag('form', $attrs, $content) : tag('form', $attrs);
}

# Breaking this bit out in case we want to make it easier to do custom attributes
# and overall processing on the form_tag

sub _process_form_attrs {
  my ($url_options, $attrs) = @_;
  my $uri_for = delete $attrs->{uri_for};
  $attrs->{action} ||= $uri_for ? $uri_for->($url_options) : $url_options;
  $attrs->{method} ||= 'POST';
  $attrs->{'accept-charset'} ||= 'UTF-8';
  return $attrs;
}

# label_tag $name, $content, \%attrs
# label_tag $name, \%attrs, \&content;
# label_tag \%attrs, \&content;
# label_tag \%attrs, $content;
# label_tag $name, $content,

sub label_tag {
  my ($name, $content, $attrs) = ('', '', +{});
  if(ref $_[0]) {
    $attrs = shift @_;
    $content = shift @_;
  } else {
    $name = shift @_;
  }
  if( (ref($_[0])||'') eq 'HASH' ) {
    $attrs = shift @_;
  } elsif(@_) {
    $content = shift @_;
    $attrs = shift @_ if ref($_[0]);
  }
  $attrs->{for} ||= _sanitize_name_to_id($name) if $name;
  $content ||= $name;

  return ref($content) ? content_tag('label', $attrs, $content) : content_tag('label', $content, $attrs)
}

# radio_button_tag $name, $value
# radio_button_tag $name, $value, $checked
# radio_button_tag $name, $value, $checked, \%attrs
# radio_button_tag $name, $value, \%attrs

sub radio_button_tag {
  my ($name, $value) = (shift @_, shift @_);
  my $attrs = (ref($_[-1])||'') eq 'HASH' ? pop(@_) : +{};
  my $checked = @_ ? shift(@_) : 0;
  $attrs = _merge_attrs(+{type=>'radio', name=>$name, value=>$value, id=>"@{[ _sanitize_name_to_id($name) ]}_@{[ _sanitize_name_to_id($value) ]}" }, $attrs);
  $attrs->{checked} = 'checked' if $checked;
  return input_tag('input', $value, $attrs);
}

# text_area_tag $name, \%attrs
# text_area_tag $name, $content, %attrs

sub text_area_tag {
  my $name = shift @_;
  my $attrs = (ref($_[-1])||'') eq 'HASH' ? pop @_ : +{};
  my $content = @_ ? shift @_ : '';

  $attrs = _merge_attrs(+{ name=>$name, id=>"@{[ _sanitize_name_to_id($name) ]}" }, $attrs);
  return content_tag('textarea', $content, $attrs);
}

# submit_tag
# submit_tag $value
# submit_tag \%attrs
# submit_tag $value, \%attrs

sub submit_tag {
  my ($value, $attrs);
  $attrs = (ref($_[-1])||'') eq 'HASH' ? pop(@_) : +{};
  $value = @_ ? shift(@_) : DEFAULT_SUBMIT_TAG_VALUE;

  $attrs = _merge_attrs(+{ type=>'submit', name=>'commit', value=>$value }, $attrs);
  return input_tag $attrs;
}

# select_tag $name, $option_tags, \%attrs
# select_tag $name, $option_tags
# select_tag $name, \%attrs

sub select_tag {
  my $name = shift;
  my $attrs = (ref($_[-1])||'') eq 'HASH' ? pop(@_) : +{};
  my $option_tags = @_ ? shift(@_) : "";
  my $html_name = $attrs->{multiple} && ($name !~ m/\[\]$/) ? "${name}[]" : $name;

  if(my $include_blank = delete $attrs->{include_blank}) {
    my $options_for_blank_options_tag = +{ value => '' };
    if($include_blank eq '1') {
      $include_blank = '';
      $options_for_blank_options_tag->{label} = ' ';
    }
    $option_tags = raw(content_tag('option', $include_blank, $options_for_blank_options_tag))->concat($option_tags);
  }
  if(my $prompt = delete $attrs->{prompt}) {
      $option_tags = raw(content_tag('option', $prompt, +{value=>''}))->concat($option_tags);
  }

  $attrs = _merge_attrs(+{ name=>$html_name, id=>"@{[ _sanitize_name_to_id($name) ]}" }, $attrs);
  return content_tag('select', $option_tags, $attrs);
}

# options_for_select [$value1, $value2, ...], $selected_value
# options_for_select [$value1, $value2, ...], +{ selected => $selected_value, %global_options_attributes }
# options_for_select [ [$label, $value], [$label, $value, \%attrs], ...]

sub options_for_select {
  my $options_proto = shift @_;
  return $options_proto unless( (ref($options_proto)||'') eq 'ARRAY');
  my $attrs_proto = $_[0] ? shift(@_) : [];
  my @selected = (ref($attrs_proto)||'' eq 'ARRAY') ? @$attrs_proto : ($attrs_proto);
  my @options = _normalize_options_for_select($options_proto);
  my $options_string = join DEFAULT_OPTIONS_DELIM,
    map {
      my %attrs = (value=>$_->[1], %{$_->[2]});
      $attrs{selected} = 'selected' if grep { $_ eq $attrs{value} } @selected;
      content_tag('option', $_->[0], \%attrs);
    } @options;

  return  raw($options_string);
}

sub _normalize_options_for_select {
  my $options_proto = shift;
  my @options = map {
    push @$_, +{} unless (ref($_->[-1])||'') eq 'HASH';
    unshift @$_, $_->[0] unless scalar(@$_) == 3;
    $_;
  } map {
    (ref($_)||'') eq 'ARRAY' ? $_ : [$_, $_, +{}];
  } @$options_proto;
  return @options;
}

# Formbuilder stuff

sub form_for {
  my $model = shift; # required; at the start
  my $content_block_coderef = pop; # required; at the end
  my $options = @_ ? shift : +{};
  my $model_name = exists $options->{as} ? $options->{as} : _model_name_from($model)->param_key;
  
  _apply_form_for_options($model, $options);
  my $html_options = $options->{html};

  $html_options->{method} = $options->{method} if exists $options->{method};
  $html_options->{data} = $options->{data} if exists $options->{data};

  my $builder = _instantiate_builder($model_name, $model, $options);
  push @{$html_options->{CONTENT_ARGS_KEY}}, $builder;
  
  return form_tag '', $html_options, $content_block_coderef;
}

# TODO I think this needs to support nested forms
sub _model_name_from {
  my $proto = shift;
  my $model = $proto->can('to_model') ? $proto->to_model : $proto;
  return $model->model_name;
}

sub _apply_form_for_options {
  my ($model, $options) = @_;
  $model = $model->to_model if $model->can('to_model');

  my $as = exists $options->{as} ? $options->{as} : undef;
  my $namespace = exists $options->{namespace} ? $options->{namespace} : undef;
  my ($action, $method) = @{ $model->can('in_storage') && $model->in_storage ? ['edit', 'patch']:['new', 'post'] };

  $options->{html} = _merge_attrs(
    ($options->{html} || +{}),
    +{
      class => $as ? "${action}_${as}" : _dom_class($model, $action),
      id => ( $as ? [ grep { defined $_ } $namespace, $action, $as ] : join('_', grep { defined $_ } ($namespace, _dom_id($model, $action))) ),
      method => $method,
    },
  );
}

sub _dom_class {
  my ($model, $prefix) = @_;
  my $singular = _model_name_from($model)->param_key;
  return $prefix ? "${prefix}@{[ DEFAULT_ID_DELIM ]}${singular}" : $singular;
}

sub _dom_id {
  my ($model, $prefix) = @_;
  if(my $model_id = _model_id_for_dom_id($model)) {
    return "@{[ _dom_class($model, $prefix) ]}@{[ DEFAULT_ID_DELIM ]}${model_id}";
  } else {
    $prefix ||= 'new';
    return _dom_class($model, $prefix)
  }
}

sub _model_id_for_dom_id {
  my $model = shift;
  return unless $model->can('id');
  return join '_', ($model->id);
}

sub _instantiate_builder {
  my ($model_name, $model, $options) = @_;
  my $builder_class = delete $options->{builder} || DEFAULT_FORMBUILDER;
  return use_module($builder_class)->new(model_name=>$model_name, model=>$model, options=>$options);
}

1;


=head1 NAME

DBIx::Class::Valiant::HTML::FormTags - HTML Form Tags

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

