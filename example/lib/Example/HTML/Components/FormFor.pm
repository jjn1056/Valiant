package Example::HTML::Components::FormFor;

use Moo;
use Valiant::HTML::Form 'form_for';
use Scalar::Util 'blessed';

with 'Valiant::HTML::ContentComponent';

has 'model' => (is=>'ro', required=>1);
has 'attrs' => (is=>'ro', required=>1, default=>sub {+{}});

sub prepare_args {
  my ($class, @args) = @_;
  if(blessed($args[0])) {
    my $model = shift(@args);
    my $attrs = (ref($args[0])||'') eq 'HASH' ? shift(@args) : +{};
    return +{ model=>$model, attrs=>$attrs }, @args;
  }
  return @args;
}

sub expand_content {
  my $self = shift;
  return unless $self->has_content;
  local $Valiant::HTML::BaseComponent::SELF = $self; # Is this needed???
  return $self->content;
}

sub render {
  my ($self, $content) = @_;
  return form_for($self->model, $self->attrs, $content);
}

1;
