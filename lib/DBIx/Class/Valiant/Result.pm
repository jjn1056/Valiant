package DBIx::Class::Valiant::Result;

use base 'DBIx::Class';

use warnings;
use strict;
use Role::Tiny;
use Valiant::Util 'debug';

with 'Valiant::Validates';

sub register_column {
  my $self = shift;
  my ($column, $info) = @_;
  $self->next::method(@_);

  use Devel::Dwarn;
  #Dwarn \@_;
  # TODO future home of validations declares inside the register column call
}

around 'default_validator_namespaces' => sub  {
  my ($orig, $self, @args) = @_;
  return('DBIx::Class::Valiant::Validator', $self->$orig(@args));
};

# Gotta jump thru these hoops because of the way the Catalyst
# DBIC model messes with the result namespace but not the schema
# namespace

sub namespace {
  my $self = shift;
  my $class = ref($self) ? ref($self) : $self; 
  my $source_name = $class->new->result_source->source_name;
  return unless $source_name;

  $class =~s/::${source_name}$//;
  return $class;
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
  # value (otherwise it will fail all the time
  return 1 unless $self->is_column_changed($attribute_name);
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
  foreach my $param (keys %params) {
    # Spot to normalize serialized params (like for dates, etc).
    if($self->has_column($param)) {
      $self->set_column($param => $params{$param});
    } elsif($self->has_relationship($param)) {
      $self->set_related_from_params($param, $params{$param});
    } elsif($self->can($param)) {
      # Right now this is only used by confirmation stuff
      $self->$param($params{$param});
    } else {
      die "Not sure what to do with '$param'";
    }
  }
}

sub set_related_from_params {
  my ($self, $related, $params) = @_;
  my $rel_data = $self->relationship_info($related);
  my $rel_type = $rel_data->{attrs}{accessor};

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
}


sub mutate_recursively {
  my ($self) = @_;
  $self->_mutate if $self->is_changed;
  foreach my $related (keys %{$self->{__valiant_related_resultset}}) {
    next unless $self->related_resultset($related)->first;
    debug 2, "mutating relationship $related";
    $self->_mutate_related($related);
  }
}

sub _mutate {
  my ($self) = @_;
  if($self->is_marked_for_deletion) {
    $self->delete_if_in_storage;
  } else {
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

  return unless $related_result->is_changed || $related_result->is_marked_for_deletion;
  $related_result->set_from_related($reverse_related, $self) if $reverse_related; # Don't have this for might_have
  $related_result->mutate_recursively;

  my @new_cache = $related_result->is_marked_for_deletion ? () : ($related_result);
  $self->related_resultset($related)->set_cache(\@new_cache);
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


