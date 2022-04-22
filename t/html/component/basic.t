use Test::Most;

{
  package Valiant::HTML::Component;

  use Moo::Role;
  use Valiant::HTML::TagBuilder;
  use Valiant::HTML::SafeString;
  
  sub safe { shift; return Valiant::HTML::SafeString::safe(@_); }
  sub raw { shift; return Valiant::HTML::SafeString::raw(@_); }
  sub concat { shift; return Valiant::HTML::SafeString::concat(@_); }

  requires 'render';

  has _registry => (is=>'ro', required=>1, init_arg=>'registry');
  has parent => (is=>'ro', predicate=>'has_parent');
  has content => (is=>'ro', predicate=>'has_content');


  sub get_component {
    my ($self, $comp_name, $args, $inner) = @_;
    $args->{parent} = $self;
    return $self->_registry->get_component($comp_name, $args, $inner);
  }

  sub render_component {
    my $self = shift;
    my $component = $self->get_component(@_);
    return $component->render;
  }

  around render => sub {
    my ($orig, $self) = (shift, shift);
    my @args = $self->prepare_render_args(@_);
    my @rendered = $self->$orig(@args);

    return $self->concat(@rendered);
  };

  sub prepare_render_args {
    my ($self, @args) = @_;
    my $content = $self->expand_content;
    return $content ? ( $content, @args) : @args;
  }

  sub expand_content {
    my $self = shift;
    return unless $self->has_content;
    return $self->concat($self->content->($self->content_args));
  }
  
  sub content_args {
    my $self = shift;
    return $self;
  }

  package Valiant::HTML::ComponentRegistry;

  use Moo;
  use Module::Runtime 'use_module';

  has factory_class => (is=>'ro', required=>1, default=>sub { 'Valiant::HTML::ComponentFactory' });
  has _components => (is=>'ro', required=>1, init_arg=>undef, default=>sub { +{} });

  sub new_factory {
    my ($self, %args) = @_;
    return use_module($self->factory_class)->new(%args);
  }

  sub add_component {
    my ($self, $comp_name, $factory_args) = @_;
    die "Component '$comp_name' already added" if exists $self->_components->{$comp_name};
    return $self->_components->{$comp_name} = $self->new_factory(%$factory_args, registry=>$self);
  }

  sub get_component {
    my ($self, $comp_name, $args, $inner) = @_;
    my $component_factory = $self->_components->{$comp_name} || die "Component '$comp_name' does not exist";
    my $component = $component_factory->create(%$args, (defined($inner) ? (content => $inner) : ()));
    return $component;
  }

  sub render_component {
    my $self = shift;
    my $component = $self->get_component(@_);
    return $component->render;
  }
  
  package Valiant::HTML::ComponentFactory;

  use Moo; 
  use Valiant::HTML::SafeString 'concat';

  has class => (is=>'ro', required=>1);
  has constructor => (is=>'ro', lazy=>1, required=>1, builder=>'_build_constructor' );
  has registry => (is=>'ro', required=>1);

  sub _build_constructor {
    return sub {
      my ($self, $class, %args) = @_;
      return $class->new(%args, registry=>$self->registry);
    };
  }

  has _init_args => (is=>'ro', init_args=>'init_args', predicate=>'has_init_args');

  sub get_init_args {
    my $self = shift;
    return $self->has_init_args ? %{$self->_init_args} : ();
  }

  sub prepare_args {
    my ($self, %args) = @_;
    %args = ($self->get_init_args, %args);
    return %args;
  }

  sub create {
    my $self = shift;
    my %args = $self->prepare_args(@_);
    my $component = $self->constructor->($self, $self->class, %args);
    return $component;
  }
}

{
  package Local::Template::Hello;

  use Moo;
  with 'Valiant::HTML::Component';

  has 'name' => (is=>'ro', required=>1);

  sub render {
    my ($self) = @_;
    return  $self->raw("<p>Hello ", $self->safe($self->name), "</p>");
  }

  package Local::Template::List;

  use Moo;
  with 'Valiant::HTML::Component';

  has 'items' => (is=>'ro', required=>1);

  sub render {
    my ($self) = @_;
    return  $self->raw(
              "<ol>",
                (map { 
                  $self->raw("<li>", $self->safe($_))
                } @{ $self->items }
                ),
              "</ol>");
  }

  package Local::Template::Page;

  use Moo;
  with 'Valiant::HTML::Component';

  has size => (is=>'ro', required=>1);

  sub render {
    my ($self) = @_;
    my $page = $self->get_component(Layout => +{title=>'Landing'}, sub {
      my $layout = shift;
      return  $layout->render_component(Hello => +{name=>'John'}),
              do {
                if($self->size ne 'big') {
                  $layout->render_component(List => +{items=>[1,2,3]});
                } else {
                  $layout->render_component(List => +{items=>[10,20,30]});
                }
              };
    });
    return $page->render;
  }


  package Local::Template::Layout;

  use Moo;
  with 'Valiant::HTML::Component';

  has 'title' => (is=>'ro', required=>1);

  sub render {
    my ($self, $inner) = @_;
    return  $self->raw('
      <html>
        <head>
          <title>', $self->safe($self->title), '</title>
        </head>
        <body>',
          $inner,
        '</body>
      </html>');
  }
}

ok my $registry = Valiant::HTML::ComponentRegistry->new;
ok $registry->add_component(Hello => +{class=>'Local::Template::Hello'});
ok $registry->add_component(List => +{class=>'Local::Template::List'});
ok $registry->add_component(Page => +{class=>'Local::Template::Page'});
ok $registry->add_component(Layout => +{class=>'Local::Template::Layout'});

ok my $hello = $registry->get_component(Hello => +{name=>'John'});
is $hello->render, '<p>Hello John</p>';

use Devel::Dwarn;

ok my $page = $registry->get_component(Page => {size=>'big'});
ok my $html = $page->render;  $html =~s/^\s+|\n//gm;
is $html, '<html><head><title>Landing</title></head><body><p>Hello John</p><ol><li>10<li>20<li>30</ol></body></html>';

warn $html;

done_testing;

__END__

  sub render($self) {
    my $list = $self->size ne 'big' ?
      <List items=[1,2,3] /> : 
      <List items=[10,20,30] />;

    return <Layout title='Landing'>
      <Hello name='John' />
      {{$list}}
      </Layout>
  }

  sub render {
    my ($self, $inner) = @_;
    return html {
      head {
        title { $self->title }
      }
      body { $inner }
    };
  }


sub {
    package Mojo::Template::Sandbox;
    BEGIN {${^WARNING_BITS} = "\x55\x55\x55\x55\x55\x55\x55\x51\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55\x55"}
    use strict;
    use feature 'current_sub', 'evalbytes', 'fc', 'say', 'state', 'switch', 'unicode_strings', 'unicode_eval';
    my $_O = '';
    {
        {
            $a = 99;
            $_O .= "<div>\n";
            my $now = Mojo::Template::Sandbox::localtime();
            $_O .= '  Time: ';
            $_O .= scalar($now->hms);
            $_O .= "\n";
            if ($a == 100) {
                $_O .= "  ddddddd\n";
            }
            $_O .= "</div>\n";
        }
    }
    $_O;
}
