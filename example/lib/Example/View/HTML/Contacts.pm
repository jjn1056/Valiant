package Example::View::HTML::Contacts;

use Moo;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'h1', 'a', 'button', ':table', ':utils';
use Valiant::HTML::SafeString ':all';

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
    $self->form($self->ctx->user, +{style=>'width: 35em; margin:auto'}, sub($fb) {
      table +{class=>'table table-striped table-bordered'}, [
        h1 'Contact List',
        thead
          trow [
            th +{scope=>"col"},'Name',
            th +{scope=>"col", style=>'width:8em'}, '',
          ],
        tbody [
          $fb->fields_for('contacts', sub($contact_fb, $contact) {
            trow [
              td a +{ href=>"/contacts/@{[ $contact->id ]}" }, $contact->last_name .', '.$contact->first_name,
              td $contact_fb->button( '_delete', +{ value=>1 }, 'Delete'),
            ],
          }),
        ],
        tfoot [
          trow td {colspan=>2}, a {href=>'/contacts/new', role=>'button', class=>'btn btn-lg btn-primary btn-block'}, "Create a new Contact",
        ],
      ],
    }),
  });
}

1;
