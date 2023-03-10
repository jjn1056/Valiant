package Valiant::HTML::Util::Form;

use Moo;
use Scalar::Util;
use Module::Runtime;

extends 'Valiant::HTML::Util::FormTags';

has 'context' => (is=>'ro', required=>0);  # For the future
has 'controller' => (is=>'ro', required=>0);  # For the future

has 'form_with_generates_ids' => (
  is => 'ro', 
  required => 1,
  builder => '_form_with_generates_ids'
);

  sub _form_with_generates_ids { 0 }

has 'formbuilder_class' => (
  is => 'ro',
  required => 1,
  builder => '_default_formbuilder_class',
);

  sub _default_formbuilder_class { 'Valiant::HTML::FormBuilder' };

# private methods

sub _DEFAULT_ID_DELIM { '_' }

sub _dom_class {
  my ($model, $prefix) = @_;
  my $singular = _model_name_from_object_or_class($model)->param_key;
  return $prefix ? "${prefix}@{[ _DEFAULT_ID_DELIM ]}${singular}" : $singular;
}

sub _dom_id {
  my ($model, $prefix) = @_;
  if(my $model_id = _model_id_for_dom_id($model)) {
    return "@{[ _dom_class($model, $prefix) ]}@{[ _DEFAULT_ID_DELIM ]}${model_id}";
  } else {
    $prefix ||= 'new';
    return _dom_class($model, $prefix)
  }
}

sub _model_id_for_dom_id {
  my $model = shift;
  return unless $model->can('id') && defined($model->id);
  return join '_', ($model->id);
}

sub _to_model {
  my ($self, $model) = @_;
  return $model->to_model if $model->can('to_model');
  return $model;
}

sub _model_name_from_object_or_class {
  my ($self, $proto) = @_;
  my $model = $self->_to_model($proto);
  return $model->model_name;
}

sub _apply_form_options {
  my ($self, $model, $options) = @_;
  $model = $self->_to_model($model);

  my $as = exists $options->{as} ? $options->{as} : undef;
  my $namespace = exists $options->{namespace} ? $options->{namespace} : undef;
  my ($action, $method) = @{ $self->model_persisted($model) ? ['edit', 'patch']:['new', 'post'] };

  $options->{html} = $self->_merge_attrs(
    ($options->{html} || +{}),
    +{
      class => $as ? "${action}_${as}" : _dom_class($model, $action),
      id => ( $as ? [ grep { defined $_ } $namespace, $action, $as ] : join('_', grep { defined $_ } ($namespace, _dom_id($model, $action))) ),
      method => $method,
    },
  );
}

# public methods

sub model_persisted {
  my ($self, $model) = @_;
  return $model->persisted if $model->can('persisted');
  return $model->in_storage if $model->can('in_storage');
  return 0;
}

# form_for $model, \%options, \&block
# form_for $model, \&block
#
# Where %options are:
# action: actual url the action.  not required
# method: default is POST
# namespace: additional prefix for form and element IDs for uniqueness.  not required
# html: additional hash of values for html attributes

sub form_for {
  my $self = shift;
  my $proto = shift; # required; at the start
  my $content_block_coderef = pop; # required; at the end
  my $options = @_ ? shift : +{};

  die "You must provide a content block to form_for" unless ref($content_block_coderef) eq 'CODE';
  die "options must be a hashref" unless ref($options) eq 'HASH';

  my ($model, $object_name);
  if( ref(\$proto) eq 'SCALAR') {
    $object_name = $proto;
  } elsif(Scalar::Util::blessed($proto)) {
    $model = $proto;
    $object_name = exists $options->{as} ?
      $options->{as} :
        $self->_model_name_from_object_or_class($model)->param_key;
    $self->_apply_form_options($model, $options);
  }

  $options->{model} = $model;
  $options->{scope} = $object_name;
  $options->{skip_default_ids} = 0;
  $options->{allow_method_names_outside_object} = exists $options->{allow_method_names_outside_object} ?
    $options->{allow_method_names_outside_object} : 0;

  return $self->form_with($options, $content_block_coderef);
}

sub form_with {
  my $self = shift;
  my $content_block_coderef = pop; # required; at the end
  my $options = @_ ? shift : +{};

  $options->{allow_method_names_outside_object} = 1;
  $options->{skip_default_ids} = 0;

  my ($model, $scope, $url);
  if($options->{model}) {
    $model = $self->_to_model(delete $options->{model});
    $scope = exists $options->{scope} ?
      delete $options->{scope} :
        $self->_model_name_from_object_or_class($model)->param_key;
    
    # TODO: This it where we need to be able to get a url from the model
    # for the builder.  Either the model itself should have a way to do
    # this or possible the controller ($url = $self->controller->url_for_model($model))
    # this method should DTRT in generating a url for a new or existing model and
    # should be able to be overridden by args passed.
  }

  my $builder = $self->_instantiate_builder($scope, $model, $options);
  my $html_options = $self->_html_options_for_form_with($url, $model, $options);
  my $output = $self->join_tags(
    $self->form_tag($html_options, sub {
      my @form_node = $content_block_coderef->($builder, $model);
      return $builder->view->safe_concat(@form_node);
    })
  );

  return $output;
}

# _instantiate_builder($object)
# _instantiate_builder($object, \%options)
# _instantiate_builder($name, $object)
# _instantiate_builder($name, $object, \%options)

sub _instantiate_builder {
  my $self = shift;
  my $options = (ref($_[-1])||'') eq 'HASH' ? pop(@_) : +{};
  my $object = Scalar::Util::blessed($_[-1]) ? pop(@_) : die "Missing required object";
  my $model_name = scalar(@_) ? pop(@_) : $self->_model_name_from_object_or_class($object)->param_key;
  my $builder = exists($options->{builder}) && defined($options->{builder}) ? $options->{builder} :  $self->formbuilder_class;
  $options->{builder} = $builder;
  
  my %args = (
    model => $object,
    name => ($model_name // _model_name_from_object_or_class($object)->param_key),
    options => $options
  );

  $args{namespace} = $options->{namespace} if exists $options->{namespace};
  $args{id} = $options->{id} if exists $options->{id};
  $args{index} = $options->{index} if exists $options->{index};
  $args{parent_builder} = $options->{parent_builder} if exists $options->{parent_builder};
  $args{theme} = $options->{theme} if exists $options->{theme};
  
  if( exists($options->{parent_builder}) && exists($options->{parent_builder}{theme}) ) {
    $args{theme} = +{ %{$args{theme}||+{}}, %{$options->{parent_builder}{theme}} };
  }

  return Module::Runtime::use_module($builder)->new(%args);
}

sub __merge {
  my ($html_options, $options, @list) = @_;
  foreach my $item (@list) {
    $html_options->{$item} = $options->{$item} if
      exists $options->{$item} and 
      !exists($html_options->{$item});
  }
}

sub _html_options_for_form_with {
  my ($self, $url, $model, $options) = @_;  
  my $html_options = $options->{html};

  __merge($html_options, $options, qw(action method data));

  $html_options->{class} = join(' ', (grep { defined $_ } $html_options->{class}, $options->{class})) if exists $options->{class};
  $html_options->{style} = join(' ', (grep { defined $_ } $html_options->{style}, $options->{style})) if exists $options->{style};
  $html_options->{tunneled_method} = 1 unless exists $html_options->{tunneled_method};
  $html_options->{method} = lc($html_options->{method}); # most common standards specify lowercase

  return $html_options;
}

1;

=head1 NAME

Valiant::HTML::Util::Form - HTML Forms for a model and context

=head1 SYNOPSIS

    my $view = Valiant::HTML::Util::View->new(aaa => 1,bbb => 2);

=head1 DESCRIPTION



=head1 INHERITANCE

This class extends L<Valiant::HTML::Util::FormTags> and inherits all methods and attributes
from that class.

=head1 ATTRIBUTES

This class has the following initialization attributes

=head1 METHODS

The following instance methods are supported by this class

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::HTML::FormBuilder>, L<Valiant::HTML::FormTags>, L<Valiant::HTML::Util::View>,
L<Valiant::HTML::Util::TagBuilder>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

1;
