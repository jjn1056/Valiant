package Valiant::Filterable;

use Moo::Role;
use Module::Runtime 'use_module';
use String::CamelCase 'camelize';
use Scalar::Util 'blessed';
use Valiant::Util 'throw_exception', 'debug';
use namespace::clean;

requires 'ancestors';

my @_filters;
sub _filters {
  my ($class, $arg) = @_;
  $class = ref($class) if ref($class);
  my $varname = "${class}::_filters";

  no strict "refs";
  push @$varname, $arg if defined($arg);

  return @$varname,
    map { $_->_filters } 
    grep { $_->can('validations') }
      $class->ancestors;
}

sub default_filter_namepart { 'Filter' }
sub default_collection_class { 'Valiant::Filter::Collection' }

sub _filters_coderef {
  my ($self, $coderef) = @_;
  $self->_filters($coderef);
  return $self;
}

sub _prepare_filter_packages {
  my ($class, $key) = @_;
  my $camel = camelize($key);
  return (
    $class->_normalize_filter_package($camel),
    map {
      "${_}::${camel}";
    } $class->default_filter_namespaces
  );
}

sub default_filter_namespaces {
  my ($self) = @_;
  return ('Valiant::FilterX', 'Valiant::Filter');
}

sub _filter_package {
  my ($self, $key) = @_;
  my @filter_packages = $self->_prepare_filter_packages($key);
  my ($filter_package, @rest) = grep {
    my $package_to_test = $_;
    eval { use_module $package_to_test } || do {
      # This regexp matches too much... We need to add the package
      # path here just the path delim will vary from platform to platform
      my $notional_filename = Module::Runtime::module_notional_filename($package_to_test);
      if($@=~m/^Can't locate $notional_filename/) {
        debug 1, "Can't find '$package_to_test' in \@INC";
        0;
      } else {
        throw_exception UnexpectedUseModuleError => (package => $package_to_test, err => $@);
      }
    }
  }  @filter_packages;
  throw_exception('NameNotFilter', name => $key, packages => \@filter_packages)
    unless $filter_package;
  debug 1, "Found $filter_package in \@INC";
  return $filter_package;
}

sub _create_filter {
  my ($self, $filter_package, $args) = @_;
  debug 1, "Trying to create filter from $filter_package";
  my $filter = $filter_package->new($args);
  return $filter;
}

sub filters {
  my ($self, @proto) = @_;

  # handle a list of attributes with filters
  my $attributes = shift @proto;
  $attributes = [$attributes] unless ref $attributes;
  my @options = @proto;

  my (@filter_info) = ();
  while(@options) {
    my $args;
    my $key = shift(@options);
    if((ref($key)||'') eq 'CODE') { # This bit allows for callbacks instead of a filter => \%params setup
      $args = { cb => $key };
      $key = 'with';
      if((ref($options[0])||'') eq 'HASH') {
        my $base_args = shift(@options);
        $args = +{ %$args, %$base_args };
      }
    } else { # Otherwise its a normal validator with params
      $args = shift(@options);
    }
    push @filter_info, [$key, $args];
  }
  
  my @filters = ();
  foreach my $info(@filter_info) {
    my ($package_part, $args) = @$info;
    my $filter_package = $self->_filter_package($package_part);

    unless((ref($args)||'') eq 'HASH') {
      $args = $filter_package->normalize_shortcut($args);
      throw_exception InvalidFilterArgs => ( args => $args) unless ref($args) eq 'HASH';
    }
    
    $args->{attributes} = $attributes;
    $args->{model} = $self;

    my $new_filter = $self->_create_filter($filter_package, $args);
    push @filters, $new_filter;
  }
  my $coderef = sub {
    my ($class, $attrs) = @_;
    foreach my $filter (@filters) {
      $attrs = $filter->filter($class, $attrs);
    }
    return $attrs;
  };
  $self->_filters_coderef($coderef); 
}

sub _normalize_filter_package {
  my ($self, $with) = @_;
  my ($prefix, $package) = ($with =~m/^(\+?)(.+)$/);
  return $package if $prefix eq '+';

  my $class =  ref($self) || $self;
  my @parts = ((split '::', $class), $package);
  my @project_inc = ();
  while(@parts) {
    push @project_inc, join '::', (@parts, $class->default_filter_namepart, $package);
    pop @parts;
  }
  push @project_inc, join '::', $class->default_filter_namepart, $package; # Not sure we should allow (add flag?)
  return @project_inc;
}

sub filters_with {
  my ($self, $proto, %options) = @_;
  my @with = ref($proto) eq 'ARRAY' ? 
    @{$proto} : ($proto);

  my @filters = ();
  FILTER_WITHS: foreach my $with (@with) {
    if( (ref($with)||'') eq 'CODE') {
      push @filters, [$with, \%options];
      next FILTER_WITHS;
    }
    debug 1, "Trying to find a filter for '$with'";
    my @possible_packages = $self->_normalize_filter_package($with);
    foreach my $package(@possible_packages) {
      my $found_package = eval {
        use_module($package);
      } || do {
        my $notional_filename = Module::Runtime::module_notional_filename($package);
        if($@=~m/^Can't locate $notional_filename/) {
          debug 1, "Can't find '$package' in \@INC";
          0;
        } else {
          # Probably a syntax error in the code of $package
          throw_exception UnexpectedUseModuleError => (package => $package, err => $@);
        }
      };
      if($found_package) {
        debug 1, "Found '$found_package' in \@INC";
        push @filters, $package->new(%options);
        next FILTER_WITHS; # Only load the first one found
      } 
    }
    throw_exception General => (msg => "Failed to find Filter for '$with' in \@INC");
  }
  my $collection = use_module($self->default_collection_class)
    ->new(filters=>\@filters);
  $self->_filters_coderef(sub { $collection->filter(@_) }); 
}

sub _process_filters {
  my ($class, $attrs) = @_;
  foreach my $filter ($class->_filters) {
    $attrs = $filter->($class, $attrs);
  }
  return $attrs;
}

around BUILDARGS => sub {
  my ( $orig, $class, @args ) = @_;
  my $attrs = $class->$orig(@args);
  return $class->_process_filters($attrs);
 };

1;

=head1 TITLE

Valiant::Filters - Role that adds class and instance methods supporting field filters

=head1 SYNOPSIS

See L<Valiant>.

=head1 DESCRIPTION

This is a role that adds class level filtering to you L<Moo> or L<Moose> classes.
The main point of entry for use and documentation currently is L<Valiant>. Here
we have API level documentation without details or examples.  You should read L<Valiant>
first and then you can refer to documentation her for further details.

=head1 CLASS METHODS

=head2 filters

Used to declare filters on an attribute.  The first argument is either a scalar or arrayref of
scalars which should be attributes on your object:

    validates name => (...);
    validates ['name', 'age'] => (...);

Following arguments should be in one of two forms: a coderef or subroutine reference that contains
filter rules, a key - value pair which is a validator class and its arguments   You may also have key value pairs which are global
arguments for the validate set as a whole:

    package Local::Model::User;

    use Moo;
    use Valiant::Validations;
    use Types::Standard 'Int';

    has ['name', 'age'] => (is=>'ro);

    validates name => (
      length => { minimum => 5, maximum => 25 },
      format => { match => 'words' },
      sub {
        my ($self, $attribute, $value, $opts) = @_;
        $self->errors->add($attribute, "can't be Joe.  We hate Joe :)" ,$opts) if $value eq 'Joe';
      }, +{ arg1=>'1', arg2=>2 }, # args are optional for coderefs but are passed into $opts
      \&must_be_unique,
    );

    valiates age => (
      Int->where('$_ >= 65'), +{
        message => 'A retiree must be at least 65 years old,
      },
      ..., # additional validations
    );

    sub must_be_unique {
      my ($self, $attribute, $value, $opts) = @_;
      # Some local validation to make sure the name is unique in storage (like a database).
    }

If you use a validator class name then the hashref of arguments that follows is not optional.  If you pass
an options hashref it should contain arguments that are defined for the validation type you are passing
or one of the global arguments: C<on>, C<message>, C<if> and C<unless>.  See L</"GLOBAL OPTIONS"> for more.

For subroutine reference and L<Type::Tiny> objects you can or not pass an options hashref depending on your
needs.  Additionally the three types can be mixed and matched within a single C<validates> clause.

When you use a validator class (such as C<length => { minimum => 5, maximum => 25 }>) we resolve the class
name C<length> in the following way.  We first camel case the name and then look for a 'Validator' package
in the current class namespace.  If we don't find a match we check each namespace up the hierarchy and
then check the two global namespaces C<Valiant::ValidatorX> and C<Validate::Validator>.  For example if
you declare validators as in the example class above C<Local::Model::User> we would look for the following:

    Local::Model::User::Validator::Length
    Local::Model:::Validator::Length
    Local::Validator::Length
    Validator::Length
    Valiant::ValidatorX::Validator::Length
    Valiant::Validator::Validator::Length

These get checked in the order above and loaded and instantiated once at setup time.

B<NOTE:> The namespace C<Valiant::Validator> is reserved for validators that ship with L<Valiant>.  The
C<Valiant::ValidatorX> namespace is reserved for additional validators on CPAN that are packaged separately
from L<Valiant>.  If you wish to share a custom validator that you wrote the proper namespace to use on
CPAN is C<Valiant::ValidatorX>.

You can also prepend your validator name with '+' which will cause L<Valiant> to ignore the namespace 
resolution and try to load the class directly.  For example:

    validates_with '+App::MyValidator';

Will try to load the class C<App::MyValidator> and use it as a validator directly (or throw an exception if
it fails to load).

=head2 validates_with

C<validates_with> is intended to process validations that are on the class as a whole, or which are very
complex and can't easily be assigned to a single attribute.  It accepts either a subroutine reference
with an optional hash of key value pair options (which are passed to C<$opts>) or a scalar name which
should be a stand alone validator class (basically a class that does the C<validates> method although
you should consume the L<Validate::Validator> role to enforce the contract).

    validates_with sub {
      my ($self, $opts) = @_;
      ...
    };

    validates_with \&check_object => (arg1=>'foo', arg2=>'bar');

    sub check_object {
      my ($self, $opts) = @_;
      ...
    }

    validates with 'Custom' => (arg1=>'foo', arg2=>'bar');

If you pass a string that is a validator class we resolve its namespace using the same approach as
detailed above for C<validates>.  Any arguments are passed to the C<new> method of the found class
excluding global options.

=head1 INSTANCE METHODS

=head2 validate

Run validation rules on the current object, optionally with arguments hash.  If validation has already
been run on this object, we clear existing errors and run validations again.  Currently the return
value of this method is not defined in the API.  Example:

    $object->validate(%args);

Currently the only arguments with defined meaning is C<context>, which is used to defined a validation
context.  All other arguments will be passed down to the C<$opts> hashref.

=head2 valid

=head2 invalid

Return true or false depending on if the current object state is valid or not.  If you call this method and
validations have not been run (via C<validate>) then we will first run validations and pass any arguments
to L</valiates>.  If validations have already been run we just return true or false directly UNLESS you
pass arguments in which case we clear errors first and then rerun validations with the arguments before
returning true or false.

=head1 ATTRIBUTES

=head2 errors

An instance of L<Valiant::Errors>.  

=head2 validated

This attribute will be true if validations have already been been run on the current instance.  It
merely says if validations have been run or not, it does not indicate if validations have been passed
or failed see L</valid> pr L</invalid>

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Valiant::Validations>

=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

