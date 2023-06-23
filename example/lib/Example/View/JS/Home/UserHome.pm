package Example::View::JS::Home::UserHome;

use Moo;
use Example::Syntax;
use Mojo::Template;
use Scalar::Util qw(blessed);
extends 'Catalyst::View::BasePerRequest';

my $mt = Mojo::Template->new;

sub add_info { return shift }
sub alert { return "aaaaaaa" }
sub render {
  my ($self, $c, @args) = @_;
  my $data = join '', <DATA>;
  $mt->parse($data);
  my $rendered = $mt->process($self, $c);
  $c->log->error($rendered) if blessed($rendered) && $rendered->isa('Mojo::Exception');
  return $rendered;
}

__PACKAGE__->config(content_type=>'application/javascript');

__DATA__
% my ($self, $c) = @_;
function testRemote (target) {
  alert(11111);
  $(callingObject).html('test');
  alert("<%= $self->alert %>");
}
