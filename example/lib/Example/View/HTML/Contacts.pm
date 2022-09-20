package Example::View::HTML::Contacts;

use Moo;
use Example::Syntax;
use Valiant::HTML::TagBuilder qw(legend a button :table div $sf);

extends 'Example::View::HTML';

has 'list' => (is=>'ro', required=>1);

__PACKAGE__->views(
  layout => 'HTML::Layout',
  navbar => 'HTML::Navbar',
  form => 'HTML::Form',
);

sub render($self, $c) {
  $self->layout(page_title=>'Contact List', sub($layout) {
    $self->navbar(active_link=>'/contacts'),
      div { style=>'width: 35em; margin:auto' }, [
        legend 'Contact List',
        table +{ class=>'table table-striped table-bordered' }, [
          thead
            trow [
              th +{ scope=>"col" }, 'Name',
            ],
          tbody { repeat=>$self->list }, sub ($contact, $i) {
            trow [
              td a +{ href=>$contact->$sf('/contacts/{:id}') }, $contact->$sf('{:first_name} {:last_name}'),
            ],
          },
        ],
        a { href=>'/contacts/new', role=>'button', class=>'btn btn-lg btn-primary btn-block' }, "Create a new Contact",
     ],
  });
}

1;
