package Example::View::HTML::Contacts::Edit;

use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(div a fieldset link_to legend br button hr form form_for),
  -helpers => qw(path),
  -views => 'HTML::Page', 'HTML::Navbar', 'HTML::Contacts::Form';

has 'contact' => (is=>'ro', required=>1);

sub render($self, $c) {
  html_page page_title => 'Contact List', sub($page) {
    html_navbar active_link => 'contact_list',
    div {class=>"col-5 mx-auto"}, [
      html_contacts_form contact => $self->contact,
      form { method=>'POST', action=>path('delete', [$self->contact->id], {'x-tunneled-method'=>'delete'}) },
        button { class => 'btn btn-danger btn-lg btn-block'}, 'Delete Contact',
    ],
  };
}

1;
