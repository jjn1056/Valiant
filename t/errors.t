use Test::Most;

{
  package Local::Object::User;

  use Valiant::Errors;
  use Moo;

  with 'Valiant::Naming';

  has 'errors' => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    default => sub {
      my $self = shift;
      return Valiant::Errors->new(object=>$self);
    },
  );

  sub validate {
    my $self = shift;
    $self->errors->add('test', 'test error', +{message=>'another test error'});
  }

  sub read_attribute_for_validation {
    my $self = shift;
    return shift;
  }

  sub human_attribute_name {
    my $self = shift;
    return shift;
  }

  sub ancestors { }
}

ok my $user = Local::Object::User->new;

$user->validate;

use Devel::Dwarn;
Dwarn $user->errors->to_hash;

done_testing;
