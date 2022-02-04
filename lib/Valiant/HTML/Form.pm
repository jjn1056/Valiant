package Valiant::HTML::Form;

use warnings;
use strict;
use Exporter 'import'; # gives you Exporter's import() method directly
use Valiant::HTML::FormTags ();
use Scalar::Util (); 
use Module::Runtime ();

our @EXPORT_OK = qw(form_for fields_for);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub _default_formbuilder_class { 'Valiant::HTML::FormBuilder' };
sub _DEFAULT_ID_DELIM { '_' }

# _instantiate_builder($object)
# _instantiate_builder($object, \%options)
# _instantiate_builder($name, $object)
# _instantiate_builder($name, $object, \%options)
sub _instantiate_builder {
  my $options = (ref($_[-1])||'') eq 'HASH' ? pop(@_) : +{};
  my $object = Scalar::Util::blessed($_[-1]) ? pop(@_) : die "Missing required object";
  my $model_name = scalar(@_) ? pop(@_) : _model_name_from_object_or_class($object)->param_key;
  my $builder = exists $options->{builder} ? $options->{builder} : $options->{builder} = _default_formbuilder_class;
  my %args = (
    model => $object,
    name => $model_name,
    options => $options
  );

  $args{namespace} = $options->{namespace} if exists $options->{namespace};
  $args{id} = $options->{id} if exists $options->{id};
  $args{index} = $options->{index} if exists $options->{index};

  return Module::Runtime::use_module($builder)->new(%args);
}

sub _model_name_from_object_or_class {
  my $proto = shift;
  my $model = $proto->can('to_model') ? $proto->to_model : $proto;
  return $model->model_name;
}

sub _apply_form_options {
  my ($model, $options) = @_;
  $model = $model->to_model if $model->can('to_model');

  my $as = exists $options->{as} ? $options->{as} : undef;
  my $namespace = exists $options->{namespace} ? $options->{namespace} : undef;
  my ($action, $method) = @{ $model->can('in_storage') && $model->in_storage ? ['edit', 'patch']:['new', 'post'] };

  $options->{html} = Valiant::HTML::FormTags::_merge_attrs(
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

# form_for $model, \%options, \&block
# form_for $model, \&block
#
# Where %options are:
# action: actual url the action.  not required
# method: default is POST
# namespace: additional prefix for form and element IDs for uniqueness.  not required
# html: additional hash of values for html attributes

sub form_for {
  my $model = shift; # required; at the start
  my $content_block_coderef = pop; # required; at the end
  my $options = @_ ? shift : +{};
  my $model_name = exists $options->{as} ? $options->{as} : _model_name_from_object_or_class($model)->param_key;
  
  _apply_form_options($model, $options);
  my $html_options = $options->{html};

  my @extra_classes = ();
  #push @extra_classes, 'was-validated' if $model->can('validated') && $model->validated;

  $html_options->{method} = $options->{method} if exists $options->{method};
  $html_options->{data} = $options->{data} if exists $options->{data};
  $html_options->{class} = join(' ', (grep { defined $_ } $html_options->{class}, $options->{class}, @extra_classes)) if exists($options->{class}) || @extra_classes;
  $html_options->{style} = join(' ', (grep { defined $_ } $html_options->{style}, $options->{style})) if exists $options->{style};

  my $builder = _instantiate_builder($model_name, $model, $options);
  return Valiant::HTML::FormTags::form_tag $html_options, sub { $content_block_coderef->($builder) };
}

#fields_for($name, $model, $options, sub {

sub fields_for {
  my ($name, $model, $options, $block) = @_;
  my $builder = _instantiate_builder($name, $model, $options);
  return Valiant::HTML::FormTags::capture($block, $builder); 
}

1;

=head1 NAME

Valiant::HTML::Form - HTML Form 

=head1 SYNOPSIS

    use Valiant::HTML::Form 'form_for'; # import all tags

=head1 DESCRIPTION


=head1 EXPORTABLE FUNCTIONS

The following functions can be exported by this library

=head2 form_for

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::HTML::FormBuilder>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut
