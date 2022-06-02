package Example::Model::ProfileRequest;

use Moose;
use CatalystX::RequestModel;

extends 'Catalyst::Model';
namespace 'person';
content_type 'application/x-www-form-urlencoded';

has username => (is=>'ro', property=>1);  # TODO?? if required=>0 then predicat MUST be set  
has first_name => (is=>'ro', property=>1);
has last_name => (is=>'ro', property=>1);
has profile => (is=>'ro', property=>+{model=>'ProfileRequest::Profile'});
#has person_roles => (is=>'ro', property=>+{ indexed=>1, model=>'ProfileRequest::PersonRole'});
has credit_cards => (is=>'ro', property=>+{ indexed=>1, model=>'ProfileRequest::CreditCard'});

__PACKAGE__->meta->make_immutable();

package Example::Model::ProfileRequest::Profile;

use Moose;
use CatalystX::RequestModel;

extends 'Catalyst::Model';

namespace 'profile';
content_type 'application/x-www-form-urlencoded';

has id => (is=>'ro', property=>1);
has address => (is=>'ro', property=>1);
has city => (is=>'ro', property=>1);
has state_id => (is=>'ro', property=>1);
has zip => (is=>'ro', property=>1);
has phone_number => (is=>'ro', property=>1);
has birthday => (is=>'ro', property=>1);

__PACKAGE__->meta->make_immutable();

package Example::Model::ProfileRequest::PersonRole;

use Moose;
use CatalystX::RequestModel;

extends 'Catalyst::Model';

namespace 'person_roles';
content_type 'application/x-www-form-urlencoded';

has role_id => (is=>'ro', property=>1);

__PACKAGE__->meta->make_immutable();

package Example::Model::ProfileRequest::CreditCard;

use Moose;
use CatalystX::RequestModel;

extends 'Catalyst::Model';

namespace 'person_roles';
content_type 'application/x-www-form-urlencoded';

has id => (is=>'ro', property=>1);
has card_number => (is=>'ro', property=>1);
has expiration => (is=>'ro', property=>1);
has _delete => (is=>'ro', property=>1);
has _add => (is=>'ro', property=>1);

__PACKAGE__->meta->make_immutable();
