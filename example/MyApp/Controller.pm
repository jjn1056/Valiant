package MyApp::Controller::Base;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';
with 'Catalyst::ControllerRole::At';
 
#MyApp::Controller::Base->config(namespace=>'');

package MyApp::Controller;

use strict;
use warnings;

use Import::Into;
use Module::Runtime;

sub base_class { 'MyApp::Controller::Base' }

sub importables {
  return (
    'utf8',
    'namespace::autoclean',
    'warnings',
    'strict',
    ['base', shift->base_class],
    ['feature', ':5.10'],
    ['experimental', 'signatures'],
  );
}

sub import {
  foreach my $import_proto(shift->importables) {
    my ($module, @args) = (ref($import_proto)||'') eq 'ARRAY' ? 
      @$import_proto : ($import_proto, ());
    Module::Runtime::use_module($module)
      ->import::into(scalar(caller), @args)
  }
}
