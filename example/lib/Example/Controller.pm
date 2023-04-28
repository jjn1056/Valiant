package Example::Controller;

use Scalar::Util;
use Moose;
extends 'Catalyst::ControllerPerContext';
with 'Catalyst::ControllerRole::At';

around gather_default_action_roles => sub {
  my ($orig, $self, %args) = @_;
  my @roles = $self->$orig(%args);
  push @roles, 'Catalyst::ActionRole::CurrentView'
    if $args{attributes}->{View};
  push @roles, 'Catalyst::ActionRole::RequestModel'
    if $args{attributes}->{RequestModel} || 
      $args{attributes}->{QueryModel} || 
        $args{attributes}->{BodyModel};
  return @roles;
};


has view_prefix => (
  is=>'ro', 
  required=>1, 
  lazy=>1, 
  builder=>'_build_view_prefix',
);

  sub _build_view_prefix {
    my $self = shift;
    return '';
  }

sub view {
  my ($self, %args) = @_;
  return $self->view_for($self->ctx->action, %args);
}

sub view_for {
  my ($self, $action_proto, %args) = @_;
  my $action = Scalar::Util::blessed($action_proto) ?
    $action_proto :
      $self->action_for($action_proto);

  my $class = $action->class;
  my $namespace_part = ($class =~ m/^.+::Controller::(.+)$/)[0];
  my $action_namepart = $self->_action_namepart_from_action($action);
  my $view = $self->_build_view_name($namespace_part, $action_namepart);

  $self->ctx->log->debug("Initializing View: $view") if $self->ctx->debug;
  return $self->ctx->view($view, %args);
}

sub _action_namepart_from_action {
  my ($self, $action) = @_;
  my $action_namepart = $action->name;
  $action_namepart =~ s/_(\w)/\U$1/g;
  $action_namepart =~ s/^(\w)/\u$1/g;
  return $action_namepart;
}

sub _build_view_name {
  my ($self, $namespace_part, $action_namepart) = @_;
  my $view = "@{[ $self->view_prefix ]}::@{[ $namespace_part ]}::@{[ $action_namepart ]}";
  return $view;
}

__PACKAGE__->meta->make_immutable;
__PACKAGE__->config(view_prefix=>'HTML');
