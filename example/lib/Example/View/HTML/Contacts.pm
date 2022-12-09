package Example::View::HTML::Contacts;

use Moo;
use Example::Syntax;
use Valiant::HTML::TagBuilder qw(legend a button div $sf :table b u);

extends 'Example::View::HTML';

has 'list' => (is=>'ro', required=>1, handles=>['pager']);

__PACKAGE__->views(
  layout => 'HTML::Layout',
  navbar => 'HTML::Navbar',
);

sub render($self, $c) {
  $self->layout(page_title=>'Contact List', sub($layout) {
    $self->navbar(active_link=>'/contacts'),
      div { style=>'width: 35em; margin:auto' }, [
        legend 'Contact List',

        $self->last_page_warning,
        $self->page_window_info,

        table +{ class=>'table table-striped table-bordered' }, [
          thead
            trow [
              th +{ scope=>"col" }, 'Name',
            ],
          tbody { repeat=>$self->list }, sub ($contact, $idx) {
            trow [
              td a +{ href=>$contact->$sf('/contacts/{:id}') }, $contact->$sf('{:first_name} {:last_name}'),
            ],
          },
          tfoot { cond=>$self->pager->last_page > 1  },
            td {colspan=>2, style=>'background:white'},
              ["Page: ", $self->pagelist ],
        ],
        a { href=>'/contacts/new', role=>'button', class=>'btn btn-lg btn-primary btn-block' }, "Create a new Contact",
     ],
  });
}

sub last_page_warning($self) {
  div { cond=>$self->pager->current_page > $self->pager->last_page, class=>'alert alert-warning', role=>'alert' },
    "The selected page is greater than the total number of pages available.  Showing the last page.",
}

sub page_window_info($self) {
  return '' unless $self->pager->total_entries > 0;
  my $message = $self->pager->last_page == 1 ?
    "@{[ $self->pager->total_entries ]} @{[ $self->pager->total_entries > 1 ? 'todos':'todo' ]}" :
    "@{[ $self->pager->first]} to @{[ $self->pager->last ]} of @{[ $self->pager->total_entries ]}";

  return div {style=>'text-align:center; margin-top:0; margin-bottom: .5rem'}, $message;
}

sub pagelist($self) {
  my @page_html = ();
  foreach my $page (1..$self->pager->last_page) {
    push @page_html, a {href=>$self->link('#ContactsList', +{page=>$page}), style=>'margin: .5rem'}, $page == $self->pager->current_page ? b u $page : $page;
  }
  return @page_html;
}

1;
