package Leyland::Parser;

# ABSTRACT: Provides the sweet REST syntax for Leyland controller routes

use strict;
use warnings;
use Exporter::Declare '-magic';

=head1 NAME

Leyland::Parser - Provides the sweet REST syntax for Leyland controller routes

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CLASS METHODS

=head1 OBJECT ATTRIBUTES

=head1 OBJECT METHODS

=cut

default_export get Leyland::Parser::Route { caller->add_route('get',  @_) }
default_export put Leyland::Parser::Route { caller->add_route('put',  @_) }
default_export del Leyland::Parser::Route { caller->add_route('del',  @_) }
default_export any Leyland::Parser::Route { caller->add_route('any',  @_) }
default_export post Leyland::Parser::Route { caller->add_route('post', @_) }
default_export prefix codeblock { caller->set_prefix(@_) }

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland::Parser

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
