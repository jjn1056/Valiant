package Example::Model::ProfileParams;

use Moose;
use Catalyst::InjectableComponent;
extends 'Catalyst::Model';

has 'test' => (is=>'ro', lazy=>1, tags=>['asdasdasdas'], default=>1);

__PACKAGE__->meta->make_immutable();

