package Leyland::Cmd::Command::app;

# ABSTRACT: Logic for the 'app' command of the 'leyland' command line app, creates a new Leyland-based application

use Leyland::Cmd -command;
use strict;
use warnings;

use Carp;
use Cwd;
use File::Path qw/make_path/;
use Tenjin;

=head1 NAME

Leyland::Cmd::Command::app - Logic for the 'app' command of the 'leyland' command line app, creates a new Leyland-based application

=head1 METHODS

=head2 usage_desc()

=cut

sub usage_desc { "leyland app %o app_name" }

=head2 opt_spec()

=cut

sub opt_spec {
	return (
		[ 'author|a=s', 'name of the application\'s author' ],
		[ 'email|e=s', 'email address of the application\'s author' ],
	);
}

=head2 validate_args()

=cut

sub validate_args {
	my ($self, $opt, $args) = @_;

	$self->usage_error("You must provide the name of the application to create")
		unless scalar @$args && $args->[0];
}

=head2 execute()

=cut

sub execute {
	my ($self, $opt, $args) = @_;

	my %data = do { local $/; "", split /_____\[ (\S+) \]_+\n/, <DATA> };
	for (values %data) {
		s/^!=([a-z])/=$1/gxms;
	}

	my $ctx = {};
	$ctx->{package_name} = $args->[0];
	$ctx->{app_name} = $args->[0];
	$ctx->{app_name} =~ s/::/-/g;
	$ctx->{package_path} = $args->[0];
	$ctx->{package_path} =~ s!::!/!g;
	$ctx->{author} = $opt->{author} || 'Some Guy';
	$ctx->{email} = $opt->{email} || 'some_guy@email.com';

	make_path(fp($ctx->{app_name}.'/lib/'.$ctx->{package_path}.'/Controller'));
	make_path(fp($ctx->{app_name}.'/views/layouts'));
	make_path(fp($ctx->{app_name}.'/public/css'));
	make_path(fp($ctx->{app_name}.'/public/images'));
	make_path(fp($ctx->{app_name}.'/public/js'));
	make_path(fp($ctx->{app_name}.'/i18n'));

	my $t = Tenjin->new({ cache => 0 });
	foreach (keys %data) {
		next unless $_;
		my $tmpl = Tenjin::Template->new;
		$tmpl->convert($data{$_});
		$tmpl->compile;
		$t->register_template($_, $tmpl);
	}

	# create app.psgi
	cf($t, $ctx, $ctx->{app_name}.'/app.psgi', 'app.psgi');
	# create MANIFEST.SKIP
	cf($t, $ctx, $ctx->{app_name}.'/MANIFEST.SKIP', 'MANIFEST.SKIP');
	# create Changes
	cf($t, $ctx, $ctx->{app_name}.'/Changes', 'Changes');
	# create the app class
	cf($t, $ctx, $ctx->{app_name}.'/lib/'.$ctx->{package_path}.'.pm', 'App.pm');
	# create the root controller
	cf($t, $ctx, $ctx->{app_name}.'/lib/'.$ctx->{package_path}.'/Controller/Root.pm', 'Root.pm');
	# create the basic views
	cf($t, $ctx, $ctx->{app_name}.'/views/index.html', 'index.html');
	cf($t, $ctx, $ctx->{app_name}.'/views/layouts/main.html', 'main.html');
	# create the localization file, if we're localizting
	cf($t, $ctx, $ctx->{app_name}.'/i18n/es.json', 'es.json');
}

=head1 FUNCTIONS

=head2 fp( $filename )

=cut

sub fp {
	getcwd.'/'.shift;
}

=head2 cf( $t, $opt, $p, $n )

=cut

sub cf {
	my ($t, $opt, $p, $n) = @_;

	print STDERR "Trying to create ", fp($p), " from $n\n";

	open(FILE, '>:utf8', fp($p))
		|| croak "Can't open ".fp($p)." for writing: $!";
	print FILE $t->render($n, $opt);
	close FILE
		|| carp "Can't close ".fp($p).": $!";
}

=head1 AUTHOR

Ido Perlmuter, C<< <ido at ido50.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-Leyland at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Leyland>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc Leyland::Cmd::Command::app

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

__DATA__

_____[ app.psgi ]_______________________________________________________
#!/usr/bin/perl -w

use lib './lib';
use strict;
use warnings;
use [== $package_name =];
use Plack::Builder;

my $config = {
	app => '[== $package_name =]',
	views => ['Tenjin'],
	locales => './i18n',
	environments => {
		development => {
			# options in here will override top level options when running in the development environment
		},
		deployment => {
			# options in here will override top level options when running in the deployment environment
		},
	}
};

my $a = [== $package_name =]->new(config => $config);

my $app = sub {
	$a->handle(shift);
};

builder {
	# enable whatever Plack middlewares you wish here, a good example
	# would be the Session middleware.
	# --------------------------------------------------------------
	# the Static middleware will serve static files from the app's
	# public directory, remove it (or comment it) if your web server
	# is serving those files
	enable 'Static',
		path => qr{^/((images|js|css|fonts)/|favicon\.ico$|apple-touch-icon\.png$)},
		root => './public/';

	$app;
};
_____[ Changes ]________________________________________________________
Revision history for [== $app_name =]

[== localtime =]
	- Initial release
_____[ MANIFEST.SKIP ]__________________________________________________
^\.gitignore$
^blib/.*$
^inc/.*$
^Makefile$
^Makefile\.old$
^pm_to_blib$
^Build$
^Build\.bat$
^_build\.*$
^pm_to_blib.+$
^.+\.tar\.gz$
^\.lwpcookies$
^cover_db$
^pod2htm.*\.tmp$
^[== $app_name =]-.*$
^\.build.*$
_____[ App.pm ]_________________________________________________________
package [== $package_name =];

our $VERSION = "0.001";
$VERSION = eval $VERSION;

use Moose;
use namespace::autoclean;

extends 'Leyland';

!=head1 NAME

[== $package_name =] - RESTful web application based on Leyland

!=head1 SYNOPSIS

!=head1 DESCRIPTION

!=head1 EXTENDS

L<Leyland>

!=head1 METHODS

!=head2 setup()

!=cut

sub setup {
	my $self = shift;
	
	# this method is automatically called after the application has
	# been initialized. you can perform some necessary initializations
	# (like database connections perhaps) and other operations that
	# are only needed to be performed once when starting the application.
	# you can remove it completely if you don't use it.
}

!=head1 AUTHOR

[== $author =], C<< <[== $email =]> >>

!=head1 BUGS

Please report any bugs or feature requests to C<bug-[== $app_name =] at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=[== $app_name =]>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

!=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc [== $package_name =]

You can also look for information at:

!=over 4

!=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=[== $app_name =]>

!=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/[== $app_name =]>

!=item * CPAN Ratings

L<http://cpanratings.perl.org/d/[== $app_name =]>

!=item * Search CPAN

L<http://search.cpan.org/dist/[== $app_name =]/>

!=back

!=head1 LICENSE AND COPYRIGHT

Copyright [== (localtime)[5]+1900 =] [== $author =].

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

!=cut

__PACKAGE__->meta->make_immutable;
_____[ Root.pm ]________________________________________________________
package [== $package_name =]::Controller::Root;

use Moose;
use Leyland::Parser;
use namespace::autoclean;

with 'Leyland::Controller';

!=head1 NAME

[== $package_name =]::Controller::Root - Top level controller of [== $app_name =]

!=head1 SYNOPSIS

!=head1 DESCRIPTION

!=head1 PREFIX

I<none, this is the root controller>

!=cut

# the root controller has no prefix, other controllers will have something
# like '/blog' (i.e. something with a starting slash)
prefix { '' }

!=head1 ROUTES

!=head2 GET /

Returns text/html

!=cut

get '^/$' {
	# $self and $c are automatically available for you here
	$c->template('index.html');
}

!=head1 METHODS

!=head2 auto( $c )

!=cut

sub auto {
	my ($self, $c) = @_;

	# this method is automatically called before the actual route method
	# is performed. every auto() method starting from the Root controller
	# and up to the matched route's controller are invoked in order,
	# so this auto() method (in the Root controller) will run for
	# every request, no matter what the request is for, so you can use
	# it to perform some necessary per-request operations like perhaps
	# validating a user's authorization to perform an operation
}

!=head2 pre_route( $c )

!=cut

sub pre_route {
	my ($self, $c) = @_;

	# this method is automatically called before the actual route method
	# is performed, but only for route methods in this controller, as
	# opposed to the auto() method. the pre_route() method of a controller,
	# if exists, will always be performed after all auto() methods
	# have been invoked
}

!=head2 pre_template( $c, $tmpl, [ \%context, $use_layout ] )

!=cut

sub pre_template {
	my ($self, $c, $tmpl, $context, $use_layout) = @_;

	# this method is automatically called before a view/template is
	# rendered by routes in this controller. It receives all the
	# the Leyland context object ($c), the name of the view/template
	# to be rendered ($tmpl), and possibly the context hash-ref and
	# the use_layout boolean.
}

!=head2 post_route( $c, $ret )

!=cut

sub post_route {
	my ($self, $c, $ret) = @_;

	# this method is automatically called after the actual route method
	# is performed, but only for route methods in this controller.
	# it also receives a reference to the result returned by the route
	# method after serialization (even if it's a scalar, in which case $ret will be a reference
	# to a scalar).
}

!=head1 AUTHOR

[== $author =], C<< <[== $email =]> >>

!=head1 BUGS

Please report any bugs or feature requests to C<bug-[== $app_name =] at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=[== $app_name =]>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

!=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc [== $package_name =]::Controller::Root

You can also look for information at:

!=over 4

!=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=[== $app_name =]>

!=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/[== $app_name =]>

!=item * CPAN Ratings

L<http://cpanratings.perl.org/d/[== $app_name =]>

!=item * Search CPAN

L<http://search.cpan.org/dist/[== $app_name =]/>

!=back

!=head1 LICENSE AND COPYRIGHT

Copyright [== (localtime)[5]+1900 =] [== $author =].

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

!=cut

__PACKAGE__->meta->make_immutable;
_____[ es.json ]________________________________________________________
{
	"Hello World!": "Hola a todos!"
}
_____[ index.html ]_____________________________________________________
<?pl	$h1 = '[== $c->loc(\'Hello World!\') =]';
	$p = '[== $c->loc(\'%1, running on Leyland v%2\', $c->app->name, $Leyland::VERSION) =]'; ?>
		<h1>[== $h1 =]</h1>
		<p>[== $p =]</p>
_____[ main.html ]______________________________________________________
<!doctype html>
<html lang="en" class="no-js">
	<head>
		<meta charset="utf-8" />

		<!-- Always force latest IE rendering engine (even in intranet) & Chrome Frame 
		     Remove this if you use the .htaccess -->
		<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />

		<title>[== $app_name =]</title>
		<meta name="description" content="" />
		<meta name="author" content="" />

		<!--  Mobile viewport optimized: j.mp/bplateviewport -->
		<meta name="viewport" content="width=device-width, initial-scale=1.0" />

		<!-- Place favicon.ico & apple-touch-icon.png in the root
		     of your domain and delete these references       -->
		<link rel="shortcut icon" href="/favicon.ico" />
		<link rel="apple-touch-icon" href="/apple-touch-icon.png" />

		<!-- CSS -->
		<link rel="stylesheet" href="css/style.css?v=1" media="all" />
	</head>
	<body>
<?pl	$h = '[== $_content =]'; ?>
[== $h =]
	</body>
</html>
