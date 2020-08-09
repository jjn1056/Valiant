package DBIx::Class::Valiant::Result;

use base 'DBIx::Class';

use warnings;
use strict;
use Role::Tiny::With;
use Valiant::Util 'debug';

with 'DBIx::Class::Valiant::Validates';

sub register_column {
  my $self = shift;
  my ($column, $info) = @_;
  $self->next::method(@_);
  #use Devel::Dwarn;
  #Dwarn \@_;
  # TODO future home of validations declares inside the register column call
}

sub insert {
  my ($self, @args) = @_;
  $self->validate(%{ $self->{__VALIANT_CREATE_ARGS} ||+{} });
  return $self if $self->invalid;
  return $self->next::method(@args);
}

sub update {
  my ($self, $upd) = @_;
  my $context = delete $upd->{__context};
  my %validate_args = (context => $context) if $context;
  $self->set_inflated_columns($upd) if $upd;
  $self->validate(%validate_args);

  return $self if $self->invalid;
  return $self->next::method();

}


# Gotta jump thru these hoops because of the way the Catalyst
# DBIC model messes with the result namespace but not the schema
# namespace

sub namespaceiXX {
  my $self = shift;  
  my $class = ref($self) ? ref($self) : $self; 
#  $class =~s/::${source_name}$//;

  warn ".... $class";
  return $class;


  # Rest of this is to deal with Catalyst wrapper (for later)
  my $source_name = $class->new->result_source->source_name;
  return unless $source_name; # Trouble... somewhere $self is a package

}

# Trouble here is you can only inject one attribute per model.  Will be an
# issue if you have more than one confirmation validation. Should be an easy
# fix, we just need to track incoming attributes so 'new' knows how to init
# all of them

sub inject_attribute {
  my ($class, $attribute_to_inject) = @_;
  my $injection = "
    package $class; 

    __PACKAGE__->mk_group_accessors(simple => '$attribute_to_inject');

    sub new {
      my (\$class, \$args) = \@_;
      my \$val = delete \$args->{$attribute_to_inject};
      my \$new = \$class->next::method(\$args);
      \$new->$attribute_to_inject(\$val);
      return \$new;
    }
  ";

  eval $injection;
  die $@ if $@;
}

# We override here because we really want the uninflated values for the columns.
# Otherwise if we try to inflate first we can get an error since the value has not
# been validated and may not inflate.

sub read_attribute_for_validation {
  my ($self, $attribute) = @_;
  return unless defined $attribute;
  return $self->get_column($attribute) if $self->result_source->has_column($attribute);

  if($self->has_relationship($attribute)) {
    my $rel_data = $self->relationship_info($attribute);
    my $rel_type = $rel_data->{attrs}{accessor};
    if($rel_type eq 'single') {
      return $self->related_resultset($attribute)->first;
    } elsif($rel_type eq 'multi') {
      return $self->related_resultset($attribute);
    } else {
      die "Can't read_attribute_for_validation for '$attribute' of rel_type '$rel_type' in @{[ref $self]}";
    }

  }

  return $self->$attribute if $self->can($attribute); 
}

# Provide basic uniqueness checking for columns.  This is basically a dumb DB lookup.  
# Its probably fine for light work but you'll need something more performant when your
# table gets big.

sub is_unique {
  my ($self, $attribute_name, $value) = @_;
  # Don't do this check unless the user is actually trying to change the
  # value (otherwise it will fail all the time).
  if($self->in_storage) {
    return 1 unless $self->is_column_changed($attribute_name);
  }
  my $found = $self->result_source->resultset->find({$attribute_name=>$value});
  return $found ? 0:1;
}

#### these next few might go away
sub mark_for_deletion {
  my ($self) = @_;
  $self->{__valiant_kiss_of_death} = 1;
}

sub unmark_for_deletion {
  my ($self) = @_;
  $self->{__valiant_kiss_of_death} = 0;
}

sub is_marked_for_deletion {
  my ($self) = @_;
  return $self->{__valiant_kiss_of_death} ? 1:0;
}

sub delete_if_in_storage {
  my ($self) = @_;
  $self->delete if $self->in_storage;  #TODO some sort of relationship handling...
}

####

sub build {
  my ($self, %attrs) = @_;
  return $self->result_source->resultset->new_result(\%attrs);
}

sub build_related {
  my ($self, $related, $attrs) = @_;
  debug 2, "Building related entity '$related' for @{[ $self->model_name->human ]}";

  my $related_obj = $self->new_related($related, ($attrs||+{}));

  # TODO do this dance need to go into other places???
  # TODO do I need some set_from_related or something here to get everthing into _relationship_data ???
  my $relinfo = $self->relationship_info($related);
  if ($relinfo->{attrs}{accessor} eq 'single') {
    $self->{_relationship_data}{$related} = $related_obj;
  }
  elsif ($relinfo->{attrs}{accessor} eq 'filter') {
    $self->{_inflated_column}{$related} = $related_obj;
  }

  my @current_cache = @{ $self->related_resultset($related)->get_cache ||[] };
  $self->related_resultset($related)->set_cache([@current_cache, $related_obj]);

  return $related_obj;
}

sub build_related_if_empty {
  my ($self, $related, $attrs) = @_;
  debug 2, "Build related entity '$related' for @{[ ref $self ]} if empty";
  return if @{ $self->related_resultset($related)->get_cache ||[] };
  return $self->build_related($related, $attrs);
}

sub set_from_params_recursively {
  my ($self, %params) = @_;
  foreach my $param (keys %params) { # probably needs to be sorted so we get specials (_destroy) first
    # Spot to normalize serialized params (like for dates, etc).
    if($self->has_column($param)) {
      $self->set_column($param => $params{$param});
    } elsif($self->has_relationship($param)) {
      $self->set_related_from_params($param, $params{$param});
    } elsif($self->can($param)) {
      # Right now this is only used by confirmation stuff
      $self->$param($params{$param});
    } elsif($param eq '_destroy' && $params{$param}) {
      if($self->in_storage) {
        debug 2, "Marking record @{[ ref $self ]}, id @{[ $self->id ]} for deletion";
        $self->mark_for_deletion;
      } else {
        die "didn't deal with destroy on unsaved records";
      }
    } elsif($param eq '_restore' && $params{$param}) {
      if($self->in_storage) {
        debug 2, "Unmarking record @{[ ref $self ]}, id @{[ $self->id ]} for deletion";
        $self->unmark_for_deletion;
        delete $params{_destroy}; 
      } else {
        die "didn't deal with restore on unsaved records";
      }
    } else {
      die "Not sure what to do with '$param'";
    }
  }
}

sub set_related_from_params {
  my ($self, $related, $params) = @_;
  my $rel_data = $self->relationship_info($related);
  my $rel_type = $rel_data->{attrs}{accessor};
  debug 2, "Setting params for $related on @{[ ref $self ]} using rel_type $rel_type";

  return $self->set_single_related_from_params($related, $params) if $rel_type eq 'single';  
}

sub set_single_related_from_params {
  my ($self, $related, $params) = @_;

  my $related_result = eval {
    my $new_related = $self->new_related($related, +{});
    my @primary_columns = $new_related->result_source->primary_columns;

    my %primary_columns = map {
      exists($params->{$_}) ? ($_ => $params->{$_}) : ();
    } @primary_columns;

    if(scalar(%primary_columns) == scalar(@primary_columns)) {
      my $found_related = $self->find_related($related, \%primary_columns, +{key=>'primary'}); # hits the DB
      die "Result not found for relation $related on @{[ ref $self ]}" unless $found_related;
      $found_related;
    } else {
      $new_related;
    }
  } || die $@; # TODO do something useful here...

  $related_result->set_from_params_recursively(%$params);
  $self->related_resultset($related)->set_cache([$related_result]);
  $self->{__valiant_related_resultset}{$related} = [$related_result];
  $self->{_relationship_data}{$related} = $related_result;
}


sub mutate_recursively {
  my ($self) = @_;
  $self->_mutate if $self->is_changed || $self->is_marked_for_deletion;
  foreach my $related (keys %{$self->{__valiant_related_resultset}}) {
    next unless $self->related_resultset($related)->first; # TODO don't think I need this
    debug 2, "mutating relationship $related";
    $self->_mutate_related($related);
  }
}

sub _mutate {
  my ($self) = @_;
  if($self->is_marked_for_deletion) {
    debug 2, "deleting @{[ ref $self ]} if in storage";
    $self->delete_if_in_storage;
  } else {
    debug 2, "update_or_insert for @{[ ref $self ]}";
    $self->update_or_insert;
  }
}

sub _mutate_related {
  my ($self, $related) = @_;
  my $rel_data = $self->relationship_info($related);
  my $rel_type = $rel_data->{attrs}{accessor};

  return $self->_mutate_single_related($related) if $rel_type eq 'single'; 
}

sub _mutate_single_related {
  my ($self, $related) = @_;
  my ($related_result) = @{ $self->{__valiant_related_resultset}{$related} ||[] };
  my $rev_data = $self->result_source->reverse_relationship_info($related);
  my ($reverse_related) = keys %$rev_data;

  debug 2, "Trying to mutate @{[ ref $related_result ]}, id: @{[ $related_result->id ]}";
  debug 3, "@{[ ref $related_result ]}, id: @{[ $related_result->id ]} is_changed: @{[ $related_result->is_changed]}";
  debug 3, "@{[ ref $related_result ]}, id: @{[ $related_result->id ]} is_marked_for_deletion @{[ $related_result->is_marked_for_deletion]}";

  return unless $related_result->is_changed || $related_result->is_marked_for_deletion;

  debug 3, "@{[ ref $related_result ]}, id: @{[ $related_result->id ]} ready for mutating";
  $related_result->set_from_related($reverse_related, $self) if $reverse_related; # Don't have this for might_have
  $related_result->mutate_recursively;

  # I think if its in storage we need to set cache and all even if marked for deletation
  #my @new_cache = $related_result->is_marked_for_deletion ? () : ($related_result);
  $self->related_resultset($related)->set_cache([$related_result]);
  $self->{__valiant_related_resultset}{$related} = [$related_result];
  $self->{_relationship_data}{$related} = $related_result;
}


1;

=head1 TITLE

DBIx::Class::Valiant::Result - Base component to add Valiant functionality

=head1 SYNOPSIS

    package Example::Schema::Result::Person;

    use base 'DBIx::Class::Core';

    __PACKAGE__->load_components('Valiant::Result');

Or just add to your base Result class


    package Example::Schema::Result;

    use strict;
    use warnings;
    use base 'DBIx::Class::Core';

    __PACKAGE__->load_components('Valiant::Result');

=head1 DESCRIPTION

=head1 METHODS

This component adds the following methods to your result classes.

=head2 

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Valiant>, L<DBIx::Class>

=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut


