package View::Example::View;

use Moo;
use Sub::Util;
use Valiant::HTML::Util::Form;
use Valiant::HTML::Util::View;
use Valiant::HTML::SafeString ();

extends 'Catalyst::View::BasePerRequest';

my $view = Valiant::HTML::Util::View->new;
my $form = Valiant::HTML::Util::Form->new(view=>$view);
my %views = ();

sub import {
  my $class = shift;
  my $target = caller;
  my @tags = @_;

  Moo->_set_superclasses($target, $class);

  {
    no strict 'refs';
    $class->_install_tags($target, @tags);
    Moo::_Utils::_install_tracked($target, 'view', sub {
        %views = (%views, @_);
    });
  }
}

sub _form { $form }

sub _install_tags {
  my $class = shift;
  my $target = shift;
  foreach my $tag (@_) {
    my $method;
    if($form->is_content_tag($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag}" => sub {
        my ($args, $content) = (+{}, '');
        $args = shift if ref $_[0] eq 'HASH';
        $content = shift if $_[0];
        return $form->safe_concat($form->tags->$tag($args, $content), @_);
      };
    } elsif($form->is_void_tag($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag}" => sub {
        my ($args, $content) = (+{}, '');
        $args = shift if ref $_[0] eq 'HASH';
        $content = shift if $_[0];
        return $form->safe_concat($form->tags->$tag($args), @_);
      };
    } elsif($form->can($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag}" => sub {
        return $form->safe_concat($form->$tag(@_));
      };
    } else {
      die "No such tag '$tag' for view";
    }

    Moo::_Utils::_install_tracked($target, $tag, $method);
  }
}

sub _install_views {
  my $class = shift;
  foreach my $name (keys %views) {
    my $method = Sub::Util::set_subname "${class}::${name}" => sub {
      my (@args) = @_;
      $form->view->ctx->view($views{$name}, @args);
    };
    no strict 'refs';
    *{"${class}::${name}"} = $method;
  }
}

sub safe { shift; return Valiant::HTML::SafeString::safe(@_) }
sub raw { shift; return Valiant::HTML::SafeString::raw(@_) }
sub safe_concat { shift; return Valiant::HTML::SafeString::safe_concat(@_) }
sub escape_html { shift; return Valiant::HTML::SafeString::escape_html(@_) }

sub read_attribute_for_html {
  my ($self, $attribute) = @_;
  return unless defined $attribute;
  return my $value = $self->$attribute if $self->can($attribute);
  die "No such attribute '$attribute' for view"; 
}

sub attribute_exists_for_html {
  my ($self, $attribute) = @_;
  return unless defined $attribute;
  return 1 if $self->can($attribute);
  return;
}

sub flatten_rendered { return shift->safe_concat(@_) }

around 'get_rendered' => sub {
  my ($orig, $self, $c, @args) = @_;
  local $form->{view} = $self; # Evil Hack lol
  return $self->$orig($c, @args);
};

before 'COMPONENT' => sub {
  my ($class, $app, $args) = @_;
  $class->_install_views;
};

1;