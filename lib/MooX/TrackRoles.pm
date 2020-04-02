package MooX::TrackRoles;

use Role::Tiny ();

sub import {
  my $class = shift;
  my $target = caller;

  die "'$target' is not a Role" unless Role::Tiny->is_role($target);

  eval qq[
    package ${target}; 
    sub does_roles { shift->maybe::next::method(\@_) }
  ];
  
  my $around = \&{"${target}::around"};
  $around->(does_roles => sub {
    my ($orig, $self) = @_;
    return ($self->$orig, $target);
  });
}

1;
