package Example::Model::ContactRequest;

use Moose;
use CatalystX::RequestModel;

extends 'Catalyst::Model';

namespace 'contact';
content_type 'application/x-www-form-urlencoded';

has first_name => (is=>'ro', property=>1);   
has last_name => (is=>'ro', property=>1);
has notes => (is=>'ro', property=>1);

__PACKAGE__->meta->make_immutable();
