package Catalyst::View::JSONBuilder::Model;

use Moo;
use Carp;
use Scalar::Util 'blessed';
use Module::Runtime 'use_module';
use Valiant::HTML::Util::Collection;
use Valiant::Naming;

has model => (is=>'rw', required=>1);
has view => (is=>'ro', required=>1);
has namespace => (is=>'ro', required=>1);

has data => (is=>'rw', required=>1, default=>sub { +{} });
has index => (is=>'rw', clearer=>1, predicate=>1);
has data_pointer => (
  is=>'rw', 
  required=>1, 
  lazy=>1,
  builder=>sub {
    my $self = shift;
    my $ns = $self->namespace;
    if($ns eq '') {
      return [ $self->data ];
    } else {
      $self->data(+{ $ns => +{} });
      return [ $self->data->{$ns} ];
    }
  }
);

sub push_model {
  my ($self, $model) = @_;
  $self->model([@{$self->model}, $model]);
  return $self;
}

sub pop_model {
  my ($self) = @_;
  my @models = @{ $self->model };
  my $discard = pop @models;
  $self->model(\@models);
  return $self;
}

sub push_pointer {
  my ($self, $key, $type, %opts) = @_;
  my $ns = exists $opts{namespace} ? $opts{namespace} : $key;

  $type ||= +{};
  $self->current_data->{$ns} = $type;
  $self->data_pointer([
    @{$self->data_pointer},
    $self->current_data->{$ns},
  ]);
  $self->index(0) if ref($type) eq 'ARRAY';
  return $self;
}

sub pop_pointer {
  my ($self) = @_;
  my @pointers = @{ $self->data_pointer };
  my $discard = pop @pointers;
  $self->data_pointer(\@pointers);
  return $self;
}

sub inc_index {
  my ($self) = @_;
  $self->index($self->index + 1);
  return $self;
}

sub _to_model {
  my ($self, $model) = @_;
  croak "No model provided" unless $model;
  confess "Model is not an object: $model" unless Scalar::Util::blessed($model);
  return $model->to_model if $model->can('to_model');
  return $model;
}

sub _model_name_from_object_or_class {
  my ($self, $proto) = @_;
  my $model = $self->_to_model($proto);
  return $model->model_name if $model->can('model_name');
  return Valiant::Name->new(Valiant::Naming::prepare_model_name_args($model));
}

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;
  my $options = $class->$orig(@args);
  my $model_name = '';

  croak "You must provide a view" if !$options->{view};
  croak "You must provide a model" if !$options->{model};

  if(blessed $options->{model}) {
    $model_name = $class->_model_name_from_object_or_class($options->{model})->param_key;
    $options->{namespace} ||= $model_name;
  } else {
    $model_name = $options->{model};
    $options->{model} = $options->{view}->get_model_for_json($model_name);
    $options->{namespace} ||= $model_name;
  }

  $options->{model} = [$options->{model}]
    unless ref $options->{model} eq 'ARRAY';

  return $options;
};

sub get_attribute_for_json {
  my ($self, $name) = @_;
  my $model = $self->model->[-1];
  return my $value = $model->get_attribute_for_json($name) if $model->can('get_attribute_for_json');
  return $model->$name if $model->can($name);
  croak "Can't find attribute '$name' for model '$model'";
}

sub has_attribute_for_json {
  my ($self, $name) = @_;
  my $model = $self->model->[-1];
  return my $value = $model->has_attribute_for_json($name) if $model->can('has_attribute_for_json');
  return $self->view->has_attribute_for_json($model, $name) if $self->view->can('has_attribute_for_json');
  my $predicate = $self->view->can('build_predicate') ? $self->view->build_predicate($model, $name) : "has_${name}";
  return $model->$predicate if $model->can($predicate);
  croak "Can't find attribute '$name' for model '$model'";
}

sub current_data {
  my ($self) = @_;
  my $what = $self->data_pointer->[-1];
  return $what;
}

sub current_model {
  my ($self) = @_;
  my $model = $self->model->[-1];
  return $model;  
}

sub set_current_data {
  my ($self, $key, $value, %opts) = @_;
  return $self if $opts{omit_undef} && !defined($value);
  return $self if $opts{omit_empty} && (ref($value)||'') eq 'ARRAY' && !@$value;
  return $self if $opts{omit_empty} && (ref($value)||'') eq 'HASH' && !%$value;
  return $self if $opts{omit_empty} && !$self->has_attribute_for_json($key);;

  $key = $opts{name} if exists $opts{name};
  if($self->has_index) {
    $self->current_data->[$self->index]{$key} = $value;
  } else {
    $self->current_data->{$key} = $value;
  }
  return $self;
}

sub TO_JSON {
  my ($self) = @_;
  return $self->data;
}

sub _normalize_opts {
  my ($self, $arg) = @_;
  return () unless defined $arg;
  return %$arg if ref($arg) eq 'HASH';
  return (value => $arg );
}

sub _normalize_value {
  my ($self, $key, %opts) = @_;
  my $value = exists $opts{value} ? $opts{value} : $self->get_attribute_for_json($key);
  if(( ref($value)||'') eq 'CODE') {
    $value = $value->($self->view, $self->get_attribute_for_json($key));
  }
  return $value;

}

# type handlers 

sub string {
  my $self = shift;
  my $key = shift;
  my %opts = $self->_normalize_opts(@_);
  my $value = $self->_normalize_value($key, %opts);
  $self->set_current_data($key, $value, %opts);
  return $self;
}

sub boolean {
  my $self = shift;
  my $key = shift;
  my %opts = $self->_normalize_opts(@_);
  my $raw_value = $self->_normalize_value($key, %opts);
  my $boolean_value = $raw_value ?
    $self->view->json_true :
      $self->view->json_false;
  $self->set_current_data($key, $boolean_value, %opts);
  return $self;
}

sub number {
  my $self = shift;
  my $key = shift;
  my %opts = $self->_normalize_opts(@_);
  my $raw_value = $self->_normalize_value($key, %opts);
  my $num_value = 0+$raw_value;
  $self->set_current_data($key, $num_value, %opts);
  return $self;
}

sub object {
  my $self = shift;
  my $key = shift;
  my $cb = pop;
  my %opts = $self->_normalize_opts(@_);

  croak 'You must provide a callback to object' unless ref($cb) eq 'CODE';
  
  my $model;
  if(blessed $key) {
    $model = $key;
    $key = $self->_model_name_from_object_or_class($model)->param_key;
  } else {
    $model = $self->get_attribute_for_json($key);
  }

  $self->push_model($model);
  $self->push_pointer($key, +{}, %opts);
  $cb->($self->view, $self, $model);
  $self->pop_model;
  $self->pop_pointer;

  my $ns = exists($opts{namespace}) ? $opts{namespace} : $key;
  delete $self->current_data->{$ns} if $opts{omit_empty} && !%{$self->current_data->{$ns}};


  return $self;
}

sub skip { return bless {}, 'Valiant::JSON::Util::Skip'}

sub array {
  my $self = shift;
  my $key = shift;
  my $cb = pop;

  croak 'You must provide a callback to object' unless ref($cb) eq 'CODE';

  my %opts = $self->_normalize_opts(@_);
  
  my $collection;
  if( ((ref($key)||'') eq 'ARRAY') || blessed($key)) {
    $collection = $key;
    $key = $opts{namespace};
  } else {
    $collection = $self->get_attribute_for_json($key);
  } 
  
  $collection = Valiant::HTML::Util::Collection->new(@$collection)
    if ref($collection) eq 'ARRAY';

  $self->push_pointer($key, [], %opts);
  while(my $model = $collection->next) {
    $self->push_model($model);
    my $return = $cb->($self->view, $self, $model);
    $self->pop_model;
    $self->inc_index unless ((ref($return)||'') eq 'Valiant::JSON::Util::Skip');
  }
  $self->pop_pointer;
  $self->clear_index;
  $collection->reset if $collection->can('reset');

  my $ns = exists($opts{namespace}) ? $opts{namespace} : $key;
  delete $self->current_data->{$ns} if $opts{omit_empty} && !@{$self->current_data->{$ns}};

  return $self;
}

sub if {
  my ($self, $cond, $cb) = @_;
  croak 'You must provide a callback to if' unless ref($cb) eq 'CODE';

  $cond = $cond->($self->view, $self) if ref($cond) eq 'CODE';
  $cb->($self->view, $self) if $cond;

  return $self;
}

sub with_model {
  my ($self, $model, $cb) = @_;
  $self->push_model($model);
  $cb->($self->view, $self, $model);
  $self->pop_model;
  return $self;
}

1;

=head1 NAME

Catalyst::View::JSONBuilder - Per Request, JSON view that wraps a model

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

This class inherits all of the attributes from L<Catalyst::View::BasePerRequest>

=head1 METHODS

This class inherits all of the methods from L<Catalyst::View::BasePerRequest> as well as:

=head1 EXPORTS

=head1 SUBCLASSING

You can subclass this view in order to provide your own default behavior and additional methods.

=head1 SEE ALSO
 
L<Catalyst::View>, L<JSON::MaybeXS>, L<Catalyst::View::BasePerRequest>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut
