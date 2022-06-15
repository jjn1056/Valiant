package CatalystX::RequestModel::ContentBodyParser::FormURLEncoded;

use warnings;
use strict;
use base 'CatalystX::RequestModel::ContentBodyParser';

sub content_type { 'application/x-www-form-urlencoded' }

sub new {
  my ($class, %args) = @_;
  my $self = bless \%args, $class;
  $self->{bp} ||= $self->{ctx}->req->body_parameters;

  ## TODO preaprse into hash of hashes to optimize how indexes work
  #use Devel::Dwarn;
  #Dwarn $self->{bp} ;

  return $self;
}


sub parse {
  my ($self, $ns, $rules) = @_;
  return %{ $self->handle_form_encoded($ns, undef, $rules) };
}

sub _sorted {
  return 1 if $a eq '';
  return -1 if $b eq '';
  return $a <=> $b;
}

sub handle_form_encoded {
  my ($self, $ns, $index, $rules) = @_;

  my $current = +{};
  my $body_parameters = $self->{bp};

  while(@$rules) {
    my $current_rule = shift @{$rules};
    my ($attr, $attr_rules) = %$current_rule;
    my $param_name = $attr_rules->{name};

    $attr_rules = +{ flatten=>1, %$attr_rules }; ## Set defaults

    if($attr_rules->{indexed} && !defined($index)) {
      my $body_parameter_name = join '.', @$ns, $param_name;
      my %indexes = ();
      foreach my $body_param (CORE::keys %$body_parameters) {
        my ($i, $under) = ($body_param =~m/^\Q$body_parameter_name\E\[(\d*)\]\.?(.*)$/);
        next unless defined $i;
        push @{$indexes{$i}}, $under;
      }
      my @values = ();
      foreach my $index (sort _sorted CORE::keys %indexes) {
        my $value = $self->handle_form_encoded($ns, $index, [$current_rule]);
        push @values, $value->{$attr}; #$self->normalize_value($value, $attr_rules);
      }

      if(@values) {
        $current->{$attr} = \@values;
      } elsif(!$attr_rules->{omit_empty}) {
        $current->{$attr} = [];
      }
    } elsif(my $nested_model = $attr_rules->{model}) {
      $current->{$attr} = $self->{ctx}->model(
        $nested_model, 
        current_namespace=>[@$ns, (defined($index) ? "${param_name}[$index]": $param_name)], 
        current_parser=>$self
      );
    } else {
      my $body_parameter_name = join '.', @$ns, (defined($index) ? "${param_name}[$index]": $param_name);
      next unless exists $body_parameters->{$body_parameter_name};   ## TODO needs to be a proper Bad Request Exception class
      my $value = $body_parameters->{$body_parameter_name};
      $current->{$attr} = $self->normalize_value($value, $attr_rules);
    }
  }
  return $current;
}

1;
