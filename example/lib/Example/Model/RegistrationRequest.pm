package Example::Model::RegistrationRequest;

use Moose;
use CatalystX::RequestModel;

extends 'Catalyst::Model';

has username => (is=>'ro', property=>1);  # TODO?? if required=>0 then predicat MUST be set  
has first_name => (is=>'ro');
has last_name => (is=>'ro');
has password => (is=>'ro');
has password_confirmation => (is=>'ro');

namespace 'person';
content_type 'application/x-www-form-urlencoded';
properties qw(
  first_name
  last_name
  password
  password_confirmation
);

__PACKAGE__->meta->make_immutable();
