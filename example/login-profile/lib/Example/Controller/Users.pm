package Example::Controller::Users;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

__PACKAGE__->meta->make_immutable;
