package Valiant::Validations;

use Sub::Exporter 'build_exporter';
use Class::Method::Modifiers qw(install_modifier);

require Moo::Role;

sub default_roles { 'Valiant::Validates' }
sub default_exports { qw(validates validates_with validates_each) }

sub import {
  my $class = shift;
  my $target = caller;

  Moo::Role->apply_roles_to_package($target, $class->default_roles);

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
      $method->($attr, @$validates);
    }
      
    return $orig->($attr, %opts);
  } if $target->can('has');
} 

1;
