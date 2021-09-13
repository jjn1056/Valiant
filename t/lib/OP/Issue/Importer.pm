package OP::Issue::Importer;

use warnings;
use strict;
use Moo::_Utils;

require Moo::Role;
require Sub::Util;

sub import {
  my $class = shift;
  my $target = caller;

  Moo::Role->apply_roles_to_package($target, 'MooRole')
    unless Role::Tiny::does_role($target, 'MooRole');

  if(my $test = $target->can('test_for_exporter')) {
    my $sub = sub {
      return $test->($target, @_);
    };
    Moo::_Utils::_install_tracked($target, 'test', $sub)
  }
} 

1;



