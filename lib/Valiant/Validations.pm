package Valiant::Validations;

use Moo;
use Moo::_Utils;
use Module::Runtime 'use_module';

require Moo::Role;

sub default_roles { 'Valiant::Validatable' }
sub default_meta { 'Valiant::Meta' }

sub import {
  my $target = caller;
  my $class = shift;

  Moo::Role->apply_roles_to_package($target, $class->default_roles);

  my $meta = use_module('Valiant::Meta')->new;
  my $validate = sub {
    $meta->validations->push(@_);
  };

  _install_coderef "${target}::validate" => "ValiantMeta::validate" => $validate;
  eval "package ${target}; sub validations { shift->maybe::next::method(\@_) } ";

  my $around = \&{"${target}::around"};
      $around->(validations => sub {
          my ($orig, $self) = @_;
          return ($self->$orig, $meta->validations->all);
      });
}

1;
