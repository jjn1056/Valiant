package OP::Issue::Importer;

use warnings;
use strict;
use Moo::_Utils;

require Moo::Role;

sub import {
  my $class = shift;
  my $target = caller;

  Moo::Role->apply_roles_to_package($target, 'MooRole');
  #   unless Role::Tiny::does_role($target, 'MooRole');
  #  my $test = $target->can('test');
  my $test = defined &{"${target}::test"} ? \&{"${target}::test"} : undef;
  Moo::_Utils::_install_tracked($target, 'test', sub { $test->($target,@_) })
    if $test;
} 

1;
