package Catalyst::View::Valiant::HTML::_ComponentProxy;

use Moose;
use HTTP::Status ();

has ctx => (is=>'ro', required=>1);
has component => (is=>'ro', required=>1);

my $__class = __PACKAGE__;
foreach my $helper( grep { $_=~/^http/i} @HTTP::Status::EXPORT_OK) {
  my $subname = lc $helper;
  eval "sub ${\$__class}::${\$subname} { return shift->respond(HTTP::Status::$helper,\@_) }";
}

sub detach { shift->ctx->detach(@_) }

sub render { shift->component->render(@_) }

sub respond {
  my ($self, $status, $headers) = @_;

  for my $r ($self->ctx->res) {
    $r->status($status) if $status && $r->status != 200; # Catalyst sets 200
    $r->content_type('text/html') if !$r->content_type;
    $r->headers->push_header(@{$headers}) if $headers;
    $r->body($self->render);
  }

  return $self;
}

# Support old school Catalyst::Action::RenderView  TBD
sub process {
  my ($self, $c, $args) = @_;
  $self->respond();
}

sub profile {
  my $self = shift;
  $self->ctx->stats->profile(@_)
    if $self->ctx->debug;
}

around 'can', sub {

  my ($orig, $self, $target) = @_;
  my $can = $self->$orig($target);
  return $can if $can;
  return unless ref $self;
  return $self->component->can($target);
};

sub AUTOLOAD {
    my $self = shift;
    (my $method) = (our $AUTOLOAD =~ /([^:]+)$/);
    return if $method eq "DESTROY";
    return $self->component->$method(@_) if $self->component->can($method); 
}

__PACKAGE__->meta->make_immutable;
