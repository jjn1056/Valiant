use Test::Most;

{
  package Local::Test::If;

  use Moo;
  use Valiant::Validations;

  has 'name' => (
    is => 'ro',
  );

  validates 'name' => (
    length => {
      in => [2,11],
      if => sub {
        my ($self) = @_;
        return $self->name eq 'AA';
      },
    },
    with => {
      cb => sub {
        my ($self, $attr) = @_;
        $self->errors->add($attr, 'failed');
      },
    },
    if => sub { return shift->name eq 'BB' },
  );
}

{
  ok my $object = Local::Test::If->new(name=>'CC');
  ok $object->validate->valid;
}

{
  ok my $object = Local::Test::If->new(name=>'BB');
  ok $object->validate->invalid;
  is_deeply +{ $object->errors->to_hash(full_messages=>1) },
    {
      name => [
      "Name failed",
      ],      
    };
}


done_testing;
