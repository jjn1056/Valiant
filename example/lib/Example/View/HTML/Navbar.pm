package Example::View::HTML::Navbar;

use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(nav a div button span),
  -util => qw($sf content_for path ),

has active_link => (is=>'ro', required=>1, default=>sub($self) { $self->ctx->req->uri->path });

our @links = (
  +{ href => '/', title => 'Home' },
  +{ href => '/account', title => 'Account Details' },
  +{ href => '/todos', title => 'Todo List' },
  +{ href => '/contacts', title => 'Contact List' },
  +{ href => '/logout', title => 'Logout' },
);

sub links :Renders ($self) {
  my $class = "nav-item nav-link";
  return map {
    a +{
      class => ( $self->active_link eq $_->{href} ? "$class active" : $class), 
      href => "$_->{href}"
    }, $_->{title};
  } @links;
}

sub render($self, $c) {
  nav +{ class=>"navbar navbar-expand-lg navbar-light bg-light" }, [
    a +{ class=>"navbar-brand", href=>"/" }, 'Example Application',
    button +{
      class=>"navbar-toggler", type=>"button",
      data=>{toggle=>"collapse", target=>"#navbarNavAltMarkup"},
      aria=>{controls=>"navbarNavAltMarkup", expanded=>"false", label=>"Toggle navigation"},
    }, span +{ class=>"navbar-toggler-icon" }, '',
    div +{ class=>"collapse navbar-collapse", id=>"navbarNavAltMarkup" },
      div +{ class=>"navbar-nav" },
        [ $self->links ]
  ];
}

1;
