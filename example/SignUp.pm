package SignUp;

use Moo;
use Valiant::Validations;

has 'user_name' => (is => 'ro');
has 'password' => (is => 'ro');
has 'password_confirmation' => (is => 'ro');


validates user_name => (presence=>1, length=>[3,24], format=>'alpha');
validates password => (presence=>1, length=>[6,24], confirmation => 1);
validates password_confirmation => (presence=>1, length=>[6,24]);

1;

