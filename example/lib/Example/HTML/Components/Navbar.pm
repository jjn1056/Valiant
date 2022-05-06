package Example::HTML::Components::Navbar;

use Moo;
use Example::HTML::Components 'Layout';
use Valiant::HTML::TagBuilder 'nav', 'a', 'div', 'button', 'span';
use Example::Syntax;

with 'Valiant::HTML::Component';

has active_link => (is=>'ro', required=>1);

our @links = (
  +{ href => '/', title => 'Home' },
  +{ href => '/profile', title => 'Profile' },
  +{ href => '/logout', title => 'Logout' },
);

sub links($self) {
  my $class = "nav-item nav-link";
  return map {
    a +{
      class => ( $self->active_link eq $_->{href} ? "$class active" : $class), 
      href => "$_->{href}"
    }, $_->{title};
  } @links;
}

sub render($self) {
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


# MPVA
