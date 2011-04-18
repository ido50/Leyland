package Leyland::View;

# ABSTRACT: Leyland view base class

use Moose::Role;
use namespace::autoclean;

=head1 NAME

Leyland::View - Leyland view base class

=head1 SYNOPSIS

	# if you're planning on creating a new Leyland view class,
	# then do something like this:

	package Leyland::View::SomeEngine;

	use Moose;
	use namespace::autoclean;
	use SomeEngine;

	with 'Leyland::View';

	has 'engine' => (is => 'ro', isa => 'SomeEngine', default => sub { SomeEngine->new });

	sub render {
		my ($self, $view, $context, $use_layout) = @_;

		$use_layout = 1 unless defined $use_layout;

		return $self->engine->render($view, $context, $use_layout);
	}

	__PACKAGE__->meta->make_immutable;

=head1 DESCRIPTION

This L<Moose role|Moose::Role> describes how Leyland view classes, mostly
used to render HTML responses (but can be used for pretty much anything),
are to be built. A view class uses a template engine (such as L<Template::Toolkit> or
<Tenjin>) to render responses.

Leyland's default view class is L<Leyland::View::Tenjin>, which, as you
may have guesses, uses the L<Tenjin> template engine.

=head1 REQUIRED METHOSD

Consuming classes are required to implement the following methods:

=head2 render( $view_name, [ \%context, $use_layout ] )

This method receives the name of a view (or "template" if you will, such
as 'index.html' or 'resource.json'), and a hash-ref of variables to be
available for the template (known as the "context"). Leyland will automatically
include 'c' for the request's context object (most probably a L<Leyland::Context>
object) and 'l' for the application object. C<$use_layout>, if provided,
will be a boolean value indicating whether the view should be rendered
inside a layout view (not relevant for every template engine). Expected
to be true by default.

Returns the rendered output.

=cut

requires 'render';

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland::View

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

Copyright 2010-2011 Ido Perlmuter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
