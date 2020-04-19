package DBIx::Class::Result::Valiant;

use base qw/DBIx::Class/;

use Role::Tiny::With;
with 'Valiant::Validates';

sub register_column {
  my $self = shift;
  my ($column, $info) = @_;
  $self->next::method(@_);

  use Devel::Dwarn;
  Dwarn \@_;
}

sub inject_attribute {
  my ($class, $attribute_to_inject) = @_;
  warn "..." x 100;
  warn $attribute_to_inject;
  #eval "package $class; has $attribute_to_inject => (is=>'ro');";
}

1;
