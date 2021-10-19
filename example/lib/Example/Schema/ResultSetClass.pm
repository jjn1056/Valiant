package Example::Schema::ResultSetClass;

use strict;
use warnings;

use Import::Into;
use Module::Runtime;

sub importables {
  my ($class) = @_;
  return (
    'utf8',
    'strict',
    'warnings',
    'namespace::autoclean',
    ['feature', ':5.16'],
    ['experimental', 'signatures', 'postderef'],
  );
}

sub base_class { 'Example::Schema::ResultSet' }

sub import {
  my ($class, @args) = @_;
  my $caller = caller;

  {
    no strict 'refs';
    push @{"${caller}::ISA"},  Module::Runtime::use_module($class->base_class);
  }
  
  foreach my $import_proto($class->importables) {
    my ($module, @args) = (ref($import_proto)||'') eq 'ARRAY' ? 
      @$import_proto : ($import_proto, ());
    Module::Runtime::use_module($module)
      ->import::into($caller, @args)
  }
}

1;
