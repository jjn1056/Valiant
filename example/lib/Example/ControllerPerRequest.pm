package Example::ControllerPerRequest;

use Moose;
extends 'Catalyst::Controller';

has 'ctx' => (is=>'ro', predicate=>'has_ctx');

sub COMPONENT {
  my ($class, $app, $args) = @_;
  $args = $class->merge_config_hashes($args, $class->_config);

  ## All this crazy will probably break if you do even more insane things
  my $application_self = bless $args, $class;
  $application_self->{_application} = $class;

  my $action  = delete $args->{action}  || {};
  my $actions = delete $args->{actions} || {};
  $application_self->{actions} = $application_self->merge_config_hashes($actions, $action);
  $application_self->{_all_actions_attributes} = delete $application_self->{actions}->{'*'} || {};
  $application_self->{_action_role_args} =  delete($application_self->{action_roles}) || [];
  $application_self->{path_prefix} =  delete $application_self->{path} if exists $application_self->{path};
  $application_self->{_action_roles} = $application_self->_build__action_roles;

  #Dwarn $application_self;
  # Dwarn $application_self->_application;

  return $application_self;
}

sub ACCEPT_CONTEXT {
  my $application_self = shift;
  my $c = shift;
  my $class = ref($application_self);

  my $self = $c->stash->{"__ControllerPerContext_${class}"} ||= do {
    my %args = (%$application_self, ctx=>$c, @_);  
    $class->new($c, \%args);
  };

  return $self;
}

###

around gather_default_action_roles => sub {
  my ($orig, $self, %args) = @_;
  my @roles = $self->$orig(%args);
  push @roles, 'Catalyst::ActionRole::CurrentView'
    if $args{attributes}->{View};
  push @roles, 'Catalyst::ActionRole::RequestModel'
    if $args{attributes}->{RequestModel};

  return @roles;
};

__PACKAGE__->meta->make_immutable;
