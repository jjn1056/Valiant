use Test::Most;
use Valiant::MOP::Object;
use Valiant::Validator::Code;
use Valiant::Validator::Size;

my $mop = Valiant::MOP::Object->new(
  fields => [
    Valiant::MOP::Field->new(
      name => 'username',
      display => 'User Name',
      validations => [

      ],
  ],
)

$mop->add_field(
  username => 'User Name', [ 
    Size => { min=>2, max=>20 },
    Code => {
      callback => sub {
        my ($mop, $object, $value) = @_;
        if($object->not_unique_username($value)) {
          $object->add_error(username => "Not Unique");
        }
      },
    },
  ],

$mop->add_field(
  Valiant::MOP::Field->new(
ok 1;

done_testing;

__END__

package User;

use Moo;
use Types::Standard 'Str';

has 'username' => (is=>'ro', required=>1, isa=>Str);

1;

Package UserProxy;

use Moo;
use Valiant::Object;
use User;

has 'users' => (is=>'ro', required, does=>'not_unique_username');
has 'username' => (is=>'ro');

validates 'username' => 'User Name', [
  Size => { min=>2, max=>20 },
  Code => {
    callback => sub {
      my ($mop, $object, $value) = @_;
      if($object->not_unique_username($value)) {
        $object->add_error(username => "Not Unique");
      }
    },
  },
];

1;

my $user = User->validates::UserUI->new(
  users => $c->Model('Users'),
  username => 'jjn1056',
);

my $UserProxy->new(User => {
  users => $c->Model('Users'),
  username => 'jjn1056',
});


  
