package Valiant::Validations;

use Sub::Exporter 'build_exporter';
use Class::Method::Modifiers qw(install_modifier);
use Valiant::Util 'debug';

require Role::Tiny;

sub default_roles { 'Valiant::Validates' }
sub default_exports { qw(validates validates_with validates_each) }

sub import {
  my $class = shift;
  my $target = caller;

  foreach my $default_role ($class->default_roles) {
    next if Role::Tiny::does_role($target, $default_role);
    debug 1, "Applying role '$default_role' to '$target'";
    Role::Tiny->apply_roles_to_package($target, $default_role);
  }

  my %cb = map {
    $_ => $target->can($_);
  } $class->default_exports;
  
  my $exporter = build_exporter({
    into_level => 1,
    exports => [
      map {
        my $key = $_; 
        $key => sub {
          sub { return $cb{$key}->($target, @_) };
        }
      } keys %cb,
    ],
  });

  $class->$exporter($class->default_exports);

  install_modifier $target, 'around', 'has', sub {
    my $orig = shift;
    my ($attr, %opts) = @_;

    my $method = \&{"${target}::validates"};
 
    if(my $validates = delete $opts{validates}) {
      debug 1, "Found validation in attribute $attr";
      $method->($attr, @$validates);
    }
      
    return $orig->($attr, %opts);
  } if $target->can('has');
} 

1;
