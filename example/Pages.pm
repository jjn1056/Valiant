package Pages;

use Moo;
use Template;
use File::Spec;

has tt => (
  is=>'ro', 
  lazy=>1,
  required=>1,
  builder => '_build_tt',
  handles => [qw/process/],
);

  sub _build_tt {
    my $self = shift;
    return our $tt ||= Template->new(
      INTERPOLATE => 1,
      EVAL_PERL => 1,
      DEFAULT => 'notfound.html',
      WRAPPER => 'wrapper.html',
      STRICT => 1,
      INCLUDE_PATH => $self->path,
    )  || die $Template::ERROR, "\n";
  }

has path => (
  is => 'ro',
  lazy => 1,
  required => 1,
  builder => '_build_path',
);
 
  sub _build_path {
    my $self = shift;
    my $module_path = $self->_module_path;
    my ($vol, $dir, $file) = File::Spec->splitpath($module_path);

    $file =~ s/\.pm$//;
    return File::Spec->catdir($dir, $file),
  }

  sub _module_path {
    my @parts = split '::', ref(shift);
    my $path = File::Spec->catfile(@parts);
    return $INC{"${path}.pm"};
  }

sub signup {
  my ($self, %vars) = (shift, @_);
  $self->process('signup.html', \%vars, \my $content)
    || die $self->tt->error(), "\n";
  return $content;
}


1;
