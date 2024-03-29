package Example::Model::Account::UpdateBody;

use Moose;
use CatalystX::RequestModel;

extends 'Catalyst::Model';
namespace 'account';
content_type 'application/x-www-form-urlencoded', 'application/json';

has username => (is=>'ro', property=>1);  
has first_name => (is=>'ro', property=>1);
has last_name => (is=>'ro', property=>1);
has profile => (is=>'ro', property=>+{model=>'::Profile' });
has person_roles => (is=>'ro', property=>+{ expand=>'JSON', always_array=>1, indexed=>1, model=>'::PersonRole' });
has credit_cards => (is=>'ro', property=>+{ indexed=>1, model=>'::CreditCard' });

__PACKAGE__->meta->make_immutable();

package Example::Model::Account::UpdateBody::Profile;

use Moose;
use CatalystX::RequestModel;

extends 'Catalyst::Model';

has id => (is=>'ro', property=>1);
has address => (is=>'ro', property=>1);
has city => (is=>'ro', property=>1);
has state_id => (is=>'ro', property=>1);
has zip => (is=>'ro', property=>1);
has phone_number => (is=>'ro', property=>1);
has birthday => (is=>'ro', property=>1);
has status => (is=>'ro', property=>1);
has registered => (is=>'ro', property=>+{ boolean=>1 });
has employment_id => (is=>'ro', property=>1);

__PACKAGE__->meta->make_immutable();

package Example::Model::Account::UpdateBody::PersonRole;

use Moose;
use CatalystX::RequestModel;

extends 'Catalyst::Model';

has role_id => (is=>'ro', property=>1);

__PACKAGE__->meta->make_immutable();

package Example::Model::Account::UpdateBody::CreditCard;

use Moose;
use CatalystX::RequestModel;

extends 'Catalyst::Model';

has id => (is=>'ro', property=>1);
has card_number => (is=>'ro', property=>1);
has expiration => (is=>'ro', property=>1);
has _delete => (is=>'ro', property=>1);
has _add => (is=>'ro', property=>1);

__PACKAGE__->meta->make_immutable();
