package CatalystX::RequestModel;

use Class::Method::Modifiers;
use Scalar::Util;
use Moo::_Utils;
use Module::Pluggable::Object;
use Module::Runtime ();

require Moo::Role;
require Sub::Util;

our @DEFAULT_ROLES = (qw(Catalyst::ComponentRole::RequestModel));
our @DEFAULT_EXPORTS = (qw(property properties namespace content_type));
our %Meta_Data = ();
our %ContentBodyParsers = ();

sub default_roles { return @DEFAULT_ROLES }
sub default_exports { return @DEFAULT_EXPORTS }
sub request_model_metadata { return %Meta_Data }
sub request_model_metadata_for { return $Meta_Data{shift} }
sub content_body_parsers { return %ContentBodyParsers }

sub content_body_parser_for {
  my $ct = shift;
  return $ContentBodyParsers{$ct} || die "No content body parser for '$ct'";
}

sub load_content_body_parsers {
  my $class = shift;
  my @packages = Module::Pluggable::Object->new(
      search_path => "${class}::ContentBodyParser"
    )->plugins;

  %ContentBodyParsers = map {
    $_->content_type => $_;
  } map {
    Module::Runtime::use_module $_;
  } @packages;
}

sub import {
  my $class = shift;
  my $target = caller;

  $class->load_content_body_parsers;

  unless (Moo::Role->is_role($target)) {
    my $orig = $target->can('with');
    Moo::_Utils::_install_tracked($target, 'with', sub {
      unless ($target->can('request_metadata')) {
        $Meta_Data{$target}{'request'} = \my @data;
        my $method = Sub::Util::set_subname "${target}::request_metadata" => sub { @data };
        no strict 'refs';
        *{"${target}::request_metadata"} = $method;
      }
      &$orig;
    });
  } 

  foreach my $default_role ($class->default_roles) {
    next if Role::Tiny::does_role($target, $default_role);
    Moo::Role->apply_roles_to_package($target, $default_role);
    foreach my $export ($class->default_exports) {
      Moo::_Utils::_install_tracked($target, "__${export}_for_exporter", \&{"${target}::${export}"});
    }
  }

  my %cb = map {
    $_ => $target->can("__${_}_for_exporter");
  } $class->default_exports;

  foreach my $exported_method (keys %cb) {
    my $sub = sub {
      if(Scalar::Util::blessed($_[0])) {
        return $cb{$exported_method}->(@_);
      } else {
        return $cb{$exported_method}->($target, @_);
      }
    };
    Moo::_Utils::_install_tracked($target, $exported_method, $sub);
  }

  Class::Method::Modifiers::install_modifier $target, 'around', 'has', sub {
    my $orig = shift;
    my ($attr, %opts) = @_;

    my $predicate;
    unless($opts{required}) {
      $predicate = $opts{predicate} = "has_${attr}" unless exists($opts{predicate});
    }

    if(my $info = delete $opts{property}) {
      $info = +{ name=>$attr } unless (ref($info)||'') eq 'HASH';
      $info->{attr_predicate} = $predicate if defined($predicate);
      $info->{omit_empty} = 1 unless exists($info->{omit_empty});
      my $method = \&{"${target}::property"};
      $method->($attr, $info, \%opts);
    }

    return $orig->($attr, %opts);
  } if $target->can('has');
} 

sub _add_metadata {
  my ($target, $type, @add) = @_;
  my $store = $Meta_Data{$target}{$type} ||= do {
    my @data;
    if (Moo::Role->is_role($target) or $target->can("${type}_metadata")) {
      $target->can('around')->("${type}_metadata", sub {
        my ($orig, $self) = (shift, shift);
        ($self->$orig(@_), @data);
      });
    } else {
      require Sub::Util;
      my $method = Sub::Util::set_subname "${target}::${type}_metadata" => sub { @data };
      no strict 'refs';
      *{"${target}::${type}_metadata"} = $method;
    }
    \@data;
  };

  push @$store, @add;
  return;
}
package Catalyst::ComponentRole::RequestModel;

use Moo::Role;
use Scalar::Util;

has ctx => (is=>'ro');
has current_namespace => (is=>'ro', predicate=>'has_current_namespace');
has current_parser => (is=>'ro', predicate=>'has_current_parser');
has catalyst_component_name => (is=>'ro');

sub namespace {
  my ($class_or_self, @data) = @_;
  my $class = ref($class_or_self) ? ref($class_or_self) : $class_or_self;
  if(@data) {
    @data = map { split /\./, $_ } @data;
    CatalystX::RequestModel::_add_metadata($class, 'namespace', @data);
  }

  return $class_or_self->namespace_metadata if $class_or_self->can('namespace_metadata');
}

sub content_type {
  my ($class_or_self, $ct) = @_;
  my $class = ref($class_or_self) ? ref($class_or_self) : $class_or_self;
  CatalystX::RequestModel::_add_metadata($class, 'content_type', $ct) if $ct;

  if($class_or_self->can('content_type_metadata')) {
    my ($ct) = $class_or_self->content_type_metadata;  # needed because this returns an array but we only want the first one
    return $ct;
  }
}

sub property {
  my ($class_or_self, $attr, $data_proto, $options) = @_;
  my $class = ref($class_or_self) ? ref($class_or_self) : $class_or_self;
  if(defined $data_proto) {
    my $data = (ref($data_proto)||'') eq 'HASH' ? $data_proto : +{ name => $attr };
    $data->{name} = $attr unless exists($data->{name});
    CatalystX::RequestModel::_add_metadata($class, 'property_data', +{$attr => $data});
  }
}

sub properties {
  my ($class_or_self, @data) = @_;
  my $class = ref($class_or_self) ? ref($class_or_self) : $class_or_self;
  while(@data) {
    my $attr = shift(@data);
    my $data = (ref($data[0])||'') eq 'HASH' ? shift(@data) : +{ name => $attr };
    $data->{name} = $attr unless exists($data->{name});
    CatalystX::RequestModel::_add_metadata($class, 'property_data', +{$attr => $data});
  }

  return $class_or_self->property_data_metadata if $class_or_self->can('property_data_metadata');
}

sub COMPONENT {
  my ($class, $app, $args) = @_;
  $args = $class->merge_config_hashes($class->config, $args);
  return bless $args, $class;
}

sub ACCEPT_CONTEXT {
  my $self = shift;
  my $c = shift;

  my %args = (%$self, @_);  
  my %request_args = $self->parse_content_body($c, %args);
  my %init_args = (%args, %request_args, ctx=>$c);
  my $class = ref($self);

  return my $request_model = $self->build_request_model($c, $class, %init_args);
}

sub build_request_model {
  my ($self, $c, $class, %init_args) = @_;
  return $class->new(%init_args); ## TODO catch and wrap error
}

sub parse_content_body {
  my ($self, $c, %args) = @_;

  my @rules = $self->properties;
  my @ns = exists($args{current_namespace}) ? @{$args{current_namespace}} : $self->namespace;            

  my $parser_class = $self->get_content_body_parser_class($c->req->content_type)
    || die "No parser for content type";
  my $parser = exists($args{current_parser}) ? 
    $args{current_parser} :
      $parser_class->new(ctx=>$c);

  return my %request_args = $parser->parse(\@ns, \@rules);
}

sub get_content_body_parser_class {
  my ($self, $content_type) = @_;
  return my $parser_class = CatalystX::RequestModel::content_body_parser_for($content_type);
}

sub get_attribute_value_for {
  my ($self, $attr) = @_;
  return $self->$attr;
}

sub nested_params {
  my $self = shift;
  my %return;
  foreach my $p ($self->properties) {
    my ($attr, $meta) = %$p;
    if(my $predicate = $meta->{attr_predicate}) {
      if($meta->{omit_empty}) {
        next unless $self->$predicate;  # skip empties when omit_empty=>1
      }
    }

    my $value = $self->get_attribute_value_for($attr);
    if( (ref($value)||'') eq 'ARRAY') {
      my @gathered = ();
      foreach my $v (@$value) {
        if(Scalar::Util::blessed($v)) {
          my $params = $v->nested_params;
          push @gathered, $params if keys(%$params);
        } else {
          push @gathered, $v;
        }

      }
      $return{$attr} = \@gathered;
    } elsif(Scalar::Util::blessed($value) && $value->can('nested_params')) { 
      my $params = $value->nested_params;
      next unless keys(%$params);
      $return{$attr} = $params;
    } else {
      $return{$attr} = $value;
    }
  }
  return \%return;
} 

sub get {
  my ($self, @fields) = @_;
  my $p = $self->nested_params;
  my @got = @$p{@fields};
  return @got;
}

1;


__END__

flatten
omit_empty   (should also remove [] for indexed or arraryed values
indexed
model
expand (JSON, CSV
