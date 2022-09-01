package Example::Schema::ResultSet::Contact;

use Example::Syntax;
use base 'Example::Schema::ResultSet';

sub new_contact($self) {
  return $self->new_result(+{});
}
1;
