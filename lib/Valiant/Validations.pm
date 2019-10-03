package Valiant::Validations;

use Moo;
use Moo::_Utils;
use Module::Runtime 'use_module';
require Moo::Role;

sub default_roles { 'Valiant::Object' }
sub default_meta { 'Valiant::Meta' }

sub import {
  my $target = caller;
  my $class = shift;

  Moo::Role->apply_roles_to_package($target, $class->default_roles);

  my $meta = use_module('Valiant::Meta')->new;
  my $validate = sub {
    $meta->validations->push(\@_);
  };

  _install_coderef "${target}::validate" => "ValiantMeta::validate" => $validate;
  _install_coderef "${target}::validations" => "ValiantMeta::::validations" => sub {
    my $class = shift;
    $class = ref $class if ref $class;
    use Devel::Dwarn;  
    no strict 'refs';
    Dwarn +{ $class => \@{ "${class}::ISA" } };
    return $meta;
  };  
}

1;
