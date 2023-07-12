package Example::View::JS::Home::UserHome;

use Moo;
use Example::Syntax;
extends 'Example::View::JS';

sub alert { return "aaaaaaa" }
sub add_info { return shift }

1;

__DATA__
% my ($self, $c) = @_;
document.addEventListener('ajaxSuccess', function(event) {
  // Access the custom event data
  var element = event.detail.element;
  alert(22222);
  element.html('test');
  alert("<%= $self->alert %>");
});



