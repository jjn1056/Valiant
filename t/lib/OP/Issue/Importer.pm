package OP::Issue::Importer;

use warnings;
use strict;
use Moo::_Utils;

require Moo::Role;

sub import {
  my ($class, $target) = (shift, caller);

  unless(Role::Tiny::does_role($target, 'MooRole')) {
    Moo::Role->apply_roles_to_package($target, 'MooRole');
    Moo::_Utils::_install_tracked($target, '__test_for_exporter', \&{"${target}::test"});
  }

  my $test = $target->can('__test_for_exporter');
  Moo::_Utils::_install_tracked($target, 'test', sub { $test->($target, @_) });
} 

1;
