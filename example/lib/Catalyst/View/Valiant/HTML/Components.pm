package Catalyst::View::Valiant::HTML::Components;

use Moose;
use Module::Runtime;

extends 'Catalyst::View';

has components => (is=>'ro');
has injected_args => (is=>'ro', predicate=>'has_injected_args');

sub find_injected_args {
  my ($self, $c, $component_name) = @_;
  my %injectors = $self->has_injected_args ? %{$self->injected_args} : ();
  return exists($injectors{$component_name}) ? 
    $injectors{$component_name}->($self, $c) :
      ();
}

sub COMPONENT {
  my ($class, $app, $args) = @_;
  my $merged_args = $class->merge_config_hashes($class->config, $args);
  my $components_class = delete $merged_args->{components_class};
  my $component_base_class = exists($merged_args->{component_base_class})
    ? delete($merged_args->{component_base_class}) 
      : 'Catalyst::View';

  my $components_model;
  $merged_args->{constructor} ||= sub {
    my ($self, $comp_name, $component_class, %args) = @_;    
    my $config = $app->config_for("${class}::${comp_name}");
    my $c = exists($args{ctx}) ?
      $args{ctx} : 
        exists($args{container}->{__ctx}) ?
          $args{container}->{__ctx} :
            die "Can't find context";

    my %injected_args = $components_model->find_injected_args($c, $comp_name);
    my $component = $component_class->new(%$config, %injected_args, %args, ctx=>$c);
    $component->{__ctx} = $c;  # keep an extra copy for child components
    return $component;
  };

  my $components = Module::Runtime::use_module($components_class)->new($merged_args);
  $components_model = $class->new(components=>$components, %$merged_args);

  {
    no strict 'refs';
    my @names = $components->component_names;
    foreach my $name (@names) {
      my $classname = "${class}::$name";
      @{"${classname}::ISA"} = ($component_base_class);
      *{"${classname}::ACCEPT_CONTEXT"} = sub {
        my ($self, $c, %args) = @_;
        my %injected_args = $components_model->find_injected_args($c, $name);
        my %combined_args = (%$self, %injected_args, %args, ctx=>$c);
        my $component = $components->create($name, \%combined_args);

        return Module::Runtime::use_module("Catalyst::View::Valiant::HTML::_ComponentProxy")->new(component=>$component, ctx=>$c);
      };
    }
  }

  return $components_model;
}

__PACKAGE__->config(
  injected_args => +{
    Hello => sub {
      my ($self, $c) = shift;
      return (
        wow => 'wow', 
      );
    },
  },
);

__PACKAGE__->meta->make_immutable;
