package Valiant::Error;

use Moo;
use Text::Autoformat 'autoformat';

# These groups are often present in the options hash and need to be removed 
# before passing options onto other classes in some cases

my @CALLBACKS_OPTIONS = (qw(if unless on allow_undef, allow_blank, strict));
my @MESSAGE_OPTIONS = (qw(message));

# object is the underlying object that has an error.  This object
# must do the 'validatable' role.

has 'object' => (
  is => 'ro',
  required => 1,
  #weak_ref => 1, # not sure about this...
);

# The type of the error, a string
has type => (
  is => 'ro',
  required => 1,
  lazy => 1, 
  builder =>'_build_type'
);

  sub _build_type {
    my $self = shift;
    return $self->i18n->make_tag('invalid');
  }

has raw_type => (is=>'ro');

# The attribute that has the error.  If undef that means its
# a model error (an error on the model itself in general).
has attribute => (is=>'ro', required=>0, predicate=>'has_attribute');

# A hashref of extra meta info
has options => (is=>'ro', required=>1);

sub i18n {
  my $self = shift;
  return $self->options->{i18n} || $self->object->i18n;
}


around BUILDARGS => sub {
  my ( $orig, $class, @args ) = @_;
  my $args = $class->$orig(@args);
  my %args = delete %{$args}{qw/object attribute type/};

  $args->{type} ||= ($args->{i18n} || )->make_tag('invalid');

  $args{options} = $args;
  $args{raw_type} = $args{type};
  return \%args;
};

# This takes an already translated error message part and creates a full message
# by combining it with the attribute human name (which itself needs to be translated
# if translation info exists for it) using a template 'format'.  You can have a format
# for each attribute or model/attribute combination or use a default format.

sub full_message { 
  my ($self, $attribute, $message) = @_;
  return $message if $attribute eq '_base';

  # Current hack for nested support
  if(ref $message) {
    if(ref $message eq 'HASH') {
      my %result = ();
      foreach my $key (CORE::keys %$message) {
        foreach my $m (@{ $message->{$key} }) {
          my $full_message = $self->full_message($key, $m); # TODO this probably doesn't localise the right model name
          push @{$result{$key}}, $full_message;
        }
      }
      return \%result;
    }
  }
  # End nested hack
  
  my @defaults = ();
  if($self->object->can('i18n_scope')) {
    my $i18n_scope = $self->object->i18n_scope;
    my @parts = split '.', $attribute; # For nested attributes
    my $attribute_name = pop @parts;
    my $namespace = join '/', @parts if @parts;
    my $attributes_scope = "${i18n_scope}.errors.models";
    if($namespace) {
      @defaults = map {
        my $class = $_;
        "${attributes_scope}.${\$class->i18n_key}/${namespace}.attributes.${attribute_name}.format",
        "${attributes_scope}.${\$class->i18n_key}/${namespace}.format";      
      } $self->object->ancestors;
    } else {
      @defaults = map {
        my $class = $_;
        "${attributes_scope}.${\$class->i18n_key}.attributes.${attribute_name}.format",
        "${attributes_scope}.${\$class->i18n_key}.format";    
      } $self->object->ancestors;
    }
  }

  @defaults = map { $self->i18n->make_tag($_) } @defaults;

  push @defaults, $self->i18n->make_tag("errors.format");
  push @defaults, $self->i18n->make_tag("errors.${attribute}.format"); # This isn't in Rails but I find it useful

  # This last one 
  push @defaults, "{{attribute}} {{message}}";

  # We do this dance to cope with nested attributes like 'user.name'.
  my $attr_name = do {
    my $human_attr = $attribute;
    $human_attr =~s/\./ /g;
    $human_attr =~s/_/ /g;
    $human_attr = autoformat $human_attr, {case=>'title'};
    $human_attr =~s/[\n]//g; # Is this a bug in Text::Autoformat???
    $human_attr;
  };
  
  $attr_name = $self->object->human_attribute_name($attribute, +{default=>$attr_name});
  
  return my $translated = $self->i18n->translate(
    shift @defaults,
    default => \@defaults,
    attribute => $attr_name,
    message => $message
  );
}

sub generate_message {
  my ($self, $attribute, $type, $options) = @_;

  $options ||= +{};
  $type = delete $options->{message} if $self->i18n->is_i18n_tag($options->{message}||'');

  my $value = $attribute ne '_base' ? 
    $self->object->read_attribute_for_validation($attribute) :
    undef;

  my %options = (
    model => $self->object->human,
    attribute => $self->object->human_attribute_name($attribute, $options),
    value => $value,
    object => $self->object,
    %{$options||+{}},
  );

  my @defaults = ();
  if($self->object->can('i18n_scope') and ) {
    my $i18n_scope = $self->object->i18n_scope;
    my $local_attribute = $attribute;
    $local_attribute =~s/\[\d+\]//g;

    @defaults = map {
      my $class = $_;
      "${i18n_scope}.errors.models.${\$class->i18n_key}.attributes.${local_attribute}.${$type}",
      "${i18n_scope}.errors.models.${\$class->i18n_key}.${$type}";      
    } $self->object->ancestors;
    push @defaults, "${i18n_scope}.errors.messages.${$type}";
  }

  push @defaults, "errors.attributes.${attribute}.${$type}";
  push @defaults, "errors.messages.${$type}";

  @defaults = map { $self->i18n->make_tag($_) } @defaults;

  my $key = shift(@defaults);
  if($options->{message}) {
    my $message = delete $options->{message};
    @defaults = ref($message) ? @$message : ($message);
  }
  $options{default} = \@defaults;

  return my $translated = $self->i18n->translate($key, %options);
}

sub message {

}
    def message
      case raw_type
      when Symbol
        self.class.generate_message(attribute, raw_type, @base, options.except(*CALLBACKS_OPTIONS))
      else
        raw_type
      end
    end


=head1 TITLE

Valiant::Error - A single error encountered during validation.

=head1 SYNOPSIS

  
=head1 DESCRIPTION

A Single Error.

This is generally an internal class and you are unlikely to use it directly.  For
the most part its used by L<Valiant::Errors>.

=head1 ATTRIBUTES

=head1 METHODS

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Errors>.

=head1 AUTHOR
 
See L<Valiant>  
    
=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

1;
