package Catalyst::InjectableComponent;

use Sub::Exporter 'build_exporter';
use Class::Method::Modifiers qw(install_modifier);

require Role::Tiny;

our @DEFAULT_ROLES = (qw(Catalyst::ComponentRole::Injects));
our @DEFAULT_EXPORTS = (qw(tags));

sub default_roles { @DEFAULT_ROLES }
sub default_exports { @DEFAULT_EXPORTS }

sub import {
  my $class = shift;
  my $target = caller;

  foreach my $default_role ($class->default_roles) {
    next if Role::Tiny::does_role($target, $default_role);
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

    foreach my $export ($class->default_exports) {
      warn ".... $export";
      my $method = \&{"${target}::${export}"};
      if(my $found = delete $opts{$export}) {
        $method->($attr, @$found);
      }
    } 
    return $orig->($attr, %opts);
  } if $target->can('has');
}

package Catalyst::ComponentRole::Injects;

use Moo::Role;

sub init_tags {
  my ($class, $opts, $attr, @args) = @_;
  
  return %{$opts};
}

my @_tags = ();
sub tags {
  my ($proto, $attr, @arg) = @_;
  my $class = ref($proto) ? ref($proto) : $proto; # can call as instance method
  my $varname = "${class}::_tags";

  no strict "refs";
  push @$varname, ($attr, \@arg) if defined($attr);
  return @$varname,
}


 
1
