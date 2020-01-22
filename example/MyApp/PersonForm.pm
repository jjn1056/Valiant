package MyApp::PersonForm;

use Moo;
use Valiant::Validations;

has 'username' => (is => 'ro');
has 'password' => (is => 'ro');

validates username => (presence=>1, length=>[3,24], format=>'alpha');
validates password => (presence=>1, length=>[6,24]);

1;
