=head1 NAME

Leyland::Manual::FAQ - Frequently asked questions about Leyland

=head1 HOW CAN I MAKE MY APP ANSWER "OPTIONS" REQUESTS?

The HTTP "OPTIONS" request method is used by clients to ask a server what
are the HTTP methods they can perform on a certain resource. The server
is supposed to answer with the response header "Allow", containing a list
of valid methods, like "GET, POST, PUT".

The good news for you is that L<Leyland> already does this automatically for
you. When it receives an OPTIONS request to a certain resource, it finds
out all methods supported by it, and returns a proper answer to the client.

=head1 HOW CAN I MAKE MY APP ANSWER "HEAD" REQUESTS?

The HTTP "HEAD" request method is exactly similar to "GET", except only
the response headers are returned, without the response body. If you want
to add support for HEAD requests in your Leyland applications, add the
L<Head|Plack::Middleware::Head> Plack middleware to C<app.psgi>.

=head1 WHY AREN'T YOU USING PLACK'S LOGGING MIDDLEWARE?

As you may know, L<Plack> has some logging middlewares, like L<Plack::Middleware::LogDispatch>,
which provide PSGI applications with a logger. I really wanted to transfer
logging resposibilities to these middlewares, but unfortunately they only
provide a logger on a per-request basis, meaning the application itself
will not have a logger, while the context object (which is request-specific)
will. Granted, the request object is where the logger is most used, but
I didn't want to leave the application without a logger, and decided Leyland
will provide a logging mechanism of its own. Maybe I'll find a better solution
in the future, we'll see.

=head1 WHAT'S NEXT?

This is the last stop of the Leyland manual. You can L<return to the table of contents|Leyland::Manual/"TABLE OF CONTENTS">
if you wish or start writing your applications.

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland::Manual::FAQ

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
