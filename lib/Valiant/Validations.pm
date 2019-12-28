package Valiant::Validations;

use Moo;
use Moo::_Utils;
use Module::Runtime 'use_module';

require Moo::Role;

sub default_meta { 'Valiant::Meta' }
sub default_roles { 'Valiant::Validatable' }

sub import {
  my $class = shift;
  my $target = caller;
  my $meta = use_module(my $meta_class = $class->default_meta)
    ->new(target=>$target);

  _install_coderef "${target}::validates" => "${meta_class}::validates" => sub { $meta->validates(@_) };
  _install_coderef "${target}::validates_with" => "${meta_class}::validates_with" => sub { $meta->validates_with(@_) };
  _install_coderef "${target}::validates_each" => "${meta_class}::validates_each" => sub { $meta->validates_each(@_) };

  Moo::Role->apply_roles_to_package($target, $class->default_roles);

  eval "package ${target}; sub validations { shift->maybe::next::method(\@_) } ";
  eval "package ${target}; sub ancestors { shift->maybe::next::method(\@_) } ";

  my $around = \&{"${target}::around"};
  $around->(validations => sub {
      my ($orig, $self) = @_;
      return ($self->$orig, $meta->validations->all);
  });
  $around->(ancestors => sub {
      my ($orig, $self) = @_;
      return ($self->$orig, $target);
  });
}

1;
