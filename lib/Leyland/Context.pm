use MooseX::Declare;

class Leyland::Context {
	use Plack::Request;

	has 'env' => (is => 'ro', isa => 'HashRef', required => 1);

	has 'req' => (is => 'ro', isa => 'Plack::Request', lazy_build => 1);

	method _build_req {
		Plack::Request->new($self->env);
	}

}

1;
