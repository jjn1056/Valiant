package Example::View::JS::Session::Build;

use Moo;
use Example::Syntax;
extends 'Catalyst::View::MojoTemplate::PerContext';

sub login_path($self) {
  return my $login_path = $self->ctx->uri('build');
};

__PACKAGE__->config(
  content_type => 'application/javascript',
  file_extension => 'js'
);

__DATA__
% my ($self, $c) = @_;
document.addEventListener('ajaxSuccess', function(event) {
  console.log("Redirecting: <%= $self->login_path %>");
  alert("Your session has expired; redirecting to login page.");
  window.location.href = "<%= $self->login_path %>";
});

