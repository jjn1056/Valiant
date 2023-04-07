package Example::View::HTML::Todos;

use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(div fieldset a b u span form_for table thead tbody tfoot trow th td),
  -util => qw($sf path ),
  -views => 'HTML::Layout', 'HTML::Navbar';

has 'list' => (is=>'ro', required=>1, handles=>[qw/pager status/]);
has 'todo' => (is=>'ro', required=>1 );

## TODO add bulk operations

sub render($self, $c) {
  html_layout page_title=>'Todo List', sub($layout) {
    html_navbar active_link=>'/todos',
    form_for 'todo', +{style=>'width:35em; margin:auto'}, sub ($self, $fb, $todo) {
      fieldset [
        $fb->legend,
        $fb->model_errors({show_message_on_field_errors=>'Please fix the listed errors.'}),
        $self->page_window_info,

        table +{class=>'table table-striped table-bordered', style=>'margin-bottom:0.5rem'}, [
          thead
            trow [
              th +{scope=>"col"},'Title',
              th +{scope=>"col", style=>'width:8em'}, 'Status',
            ],
          tbody { repeat=>$self->list }, \&rows,
          tfoot { if=>$self->pager->last_page > 1  }, \&pagelist_row,
         ],
        
        $self->status_filter_box,

        div +{ class=>'form-group' }, [
          $fb->input('title', +{ placeholder=>'What needs to be done?' }),
          $fb->errors_for('title'),
        ],
        $fb->submit('Add Todo to List'),
      ],
    },
  };
}

sub rows :Renders ($self, $todo, $i) {
  trow [
   td a +{ href=>path('todo/view', [$todo->id]) }, $todo->title,
   td $todo->status,
  ],
}

sub pagelist_row :Renders ($self) {
 td {colspan=>2, style=>'background:white'},
    ["Page: ", $self->pagelist ],
}

sub page_window_info :Renders ($self) {
  return '' unless $self->pager->total_entries > 0;
  my $message = $self->pager->last_page == 1 ?
    "@{[ $self->pager->total_entries ]} @{[ $self->pager->total_entries > 1 ? 'todos':'todo' ]}" :
    "@{[ $self->pager->first]} to @{[ $self->pager->last ]} of @{[ $self->pager->total_entries ]}";

  return div {style=>'text-align:center; margin-top:0; margin-bottom: .5rem'}, $message;
}

sub pagelist($self) {
  my @page_html = ();
  foreach my $page (1..$self->pager->last_page) {
    push @page_html, a {href=>path('list', +{'todo.page'=>$page, 'todo.status'=>$self->status}), style=>'margin: .5rem'}, $page == $self->pager->current_page ? b u $page : $page;
  }
  return @page_html;
}

sub status_filter_box($self) {
  div {style=>'text-align:center; margin-bottom: 1rem'}, [
    map { $self->status_filter($_) } qw/all active completed/,
  ];
}

sub status_filter($self, $status) {
  return span {style=>'margin: .5rem'}, [b u $status] if $self->status eq $status;
  return a { href=>path('list', +{'todo.page'=>1, 'todo.status'=>$status}), style=>'margin: .5rem'}, $status;
}

1;
