package Example::Model::PostsQuery;

use Moo;
use Example::Syntax;
use CatalystX::QueryModel;

extends 'Example::PagedQueryModel';
namespace 'post';

1;
