package Example::HTML::Components::Layout;

use Moo;
use Valiant::HTML::TagBuilder ':html';

with 'Valiant::HTML::ContentComponent';

has 'page_title' => (is=>'ro', required=>1);
has 'css' => (is=>'ro', required=>1, default=>'');

sub prepare_args {
  my ($class, @args) = @_;
  if(ref(\$args[0]) eq 'SCALAR') {
    my $page_title = shift(@args);
    return +{page_title=>$page_title}, @args;
  }
  return @args;
}

sub render {
  my ($self, $content) = @_;
  return  html +{ lang=>'en' }, [
            head [
              title $self->page_title,
              meta +{ charset=>"utf-8" },
              meta +{ name=>"viewport", content=>"width=device-width, initial-scale=1, shrink-to-fit=no" },
              link +{ rel=>"icon", href=>"data:," },
              link +{ rel=>"stylesheet",
                      href=>"https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css",
                      integrity=>"sha384-Vkoo8x4CGsO3+Hhxv8T/Q5PaXtkKtu6ug5TOeNV6gBiFeWPGFN9MuhOf23Q9Ifjh",
                      crossorigin=>"anonymous" },
              $self->css,
            ],
            body [
              $content,
              script +{ src=>"https://code.jquery.com/jquery-3.4.1.slim.min.js",
                        integrity=>"sha384-J6qa4849blE2+poT4WnyKhv5vZF5SrPo0iEjwBvKU7imGFAV0wwj1yYfoRSJoZ+n",
                        crossorigin=>"anonymous" }, '',
              script +{ src=>'https://cdn.jsdelivr.net/npm/popper.js@1.16.0/dist/umd/popper.min.js',
                        integrity=>"sha384-Q6E9RHvbIyZFJoft+2mJbHaEWldlvI9IOYy5n3zV9zzTtmI3UksdQRVvoxMfooAo",
                        crossorigin=>"anonymous" }, '',
              script +{ src=>"https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/js/bootstrap.min.js",
                        integrity=>"sha384-wfSDF2E50Y2D1uUdj0O3uMBJnjuUD4Ih7YwaYd1iqfktj0Uod8GCExl3Og8ifwB6",
                        crossorigin=>"anonymous" }, '',
            ],
          ];
}

1;
