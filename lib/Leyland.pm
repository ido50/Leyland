use MooseX::Declare;

class Leyland {
	use Leyland::Context;
	use Plack::Response;
	use Data::Dumper;

	has 'routes' => (is => 'ro', isa => 'HashRef', predicate => 'has_routes', writer => '_set_routes');
	
	method BUILD {
		# get all routes
		my $routes = {};

		foreach ($self->controllers) {
			$routes->{$_->prefix} = $_->routes;
		}

		$self->_set_routes($routes);
	}

	method handle (HashRef $env) {
		# create the context object
		my $c = Leyland::Context->new(env => $env);

		# find the first matching route
		my $route = $self->find_route($c);

		# invoke it
		my $res = Plack::Response->new(200);
		$res->content_type('text/html');
		$res->body($route->{code}->($c));

		return $res->finalize;
	}

	method find_route (Leyland::Context $c) {
		my $path = $c->req->path;
		# add a trailing slash to the path unless there is one
		$path .= '/' unless $path =~ m!/$!;

		my ($prefix) = ($path =~ m!^/([^/]*)?!);
		$prefix = 'root' unless $prefix;

		my $route = $' || '/';

		# do we have an exact route?
		my $code = $self->routes->{$prefix}->{$route}->{lc($c->req->method)};

		# do we have an exact 'any' route?
		$code ||= $self->routes->{$prefix}->{$route}->{any};

		return { prefix => $prefix, method => $c->req->method, code => $code };
	}
}

=head1 NAME

Leyland - The great new Leyland!

=head1 SYNOPSIS

	use Leyland;

	my $foo = Leyland->new();
	...

=head1 METHODS

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Leyland>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Leyland>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Leyland>

=item * Search CPAN

L<http://search.cpan.org/dist/Leyland/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
