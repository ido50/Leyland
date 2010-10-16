package Leyland::Negotiator;

use Moose;
use namespace::autoclean;
use Carp;

sub find_options {
	my ($self, $c, $app_routes) = @_;

	my @pref_routes = $self->prefs_and_routes($c->req->path);

	my @routes = $self->matching_routes($app_routes, @pref_routes);

	# have we found any matching routes?
	$c->exception({ code => 404 }) unless scalar @routes;

	# okay, we have, let's see which HTTP methods are supported by
	# these routes
	my %meths = ( 'OPTIONS' => 1 );
	foreach (@routes) {
		$meths{$self->method_name($_->{method})} = 1;
	}

	return sort keys %meths;
}

sub find_routes {
	my ($self, $c, $app_routes, $path) = @_;

	$path ||= $c->req->path;

	# let's find all possible prefix/route combinations
	# from the request path
	my @pref_routes = $self->prefs_and_routes($path);

	# find all routes matching the request path
	my @routes = $self->matching_routes($app_routes, @pref_routes);

	$c->log->info('Found '.scalar(@routes).' routes matching '.$path);

	# weed out routes that do not match request method
	$c->log->info('Negotiating request method.');
	@routes = $self->negotiate_method($c->req->method, @routes);

	# have we found anything? if not, return 404 error
	$c->exception({ code => 404 }) unless scalar @routes;

	# weed out all routes that do not accept the media type that the
	# client used for the request
	$c->log->info('Negotiating media type received.');
	@routes = $self->negotiate_receive_media($c, @routes);

	$c->exception({ code => 415 }) unless scalar @routes;

	# weed out all routes that do not return any media type
	# the client accepts
	$c->log->info('Negotiating media type returned.');
	@routes = $self->negotiate_return_media($c, @routes);

	# do we have anything left? if not, return 406 error
	$c->exception({ code => 406 }) unless scalar @routes;

	return @routes;
}

sub prefs_and_routes {
	my ($self, $path) = @_;

	my @pref_routes = ({ prefix => '', route => $path });
	my ($prefix) = ($path =~ m!^(/[^/]+)!);
	my $route = $' || '/';
	my $i = 0; # counter to prevent infinite loops, probably should removed
	while ($prefix && $i < 100) {
		push(@pref_routes, { prefix => $prefix, route => $route });
		
		my ($suffix) = ($route =~ m!^(/[^/]+)!);
		last unless $suffix;
		$prefix .= $suffix;
		$route = $' || '/';
		$i++;
	}

	return @pref_routes;
}

sub matching_routes {
	my ($self, $app_routes, @pref_routes) = @_;

	my @routes;
	foreach (@pref_routes) {		
		my $pref_name = $_->{prefix} || '_root_';

		next unless $app_routes->EXISTS($pref_name);

		my $pref_routes = $app_routes->FETCH($pref_name);
		
		next unless $pref_routes;
		
		# find matching routes in this prefix
		foreach my $r ($pref_routes->Keys) {
			# does the requested route match the current route?
			next unless my @captures = ($_->{route} =~ m/$r/);
			
			shift @captures if scalar @captures == 1 && $captures[0] eq '1';

			my $route_meths = $pref_routes->FETCH($r);

			# find all routes that support the request method (i.e. GET, POST, etc.)
			foreach my $m (sort { $a eq 'any' || $b eq 'any' } keys %$route_meths) {
				# it does, but is there a subroutine for the exact request method?
				push(@routes, { method => $m, class => $route_meths->{$m}->{class}, prefix => $_->{prefix}, route => $r, code => $route_meths->{$m}->{code}, rules => $route_meths->{$m}->{rules}, captures => \@captures });
			}
		}
	}

	return @routes;
}

sub negotiate_method {
	my ($self, $method, @all_routes) = @_;

	my @routes;
	foreach (@all_routes) {
		next unless $self->method_name($_->{method}) eq $method || $_->{method} eq 'any';
		push(@routes, $_);
	}

	return @routes;
}

sub negotiate_receive_media {
	my ($self, $c, @all_routes) = @_;

	return @all_routes unless my $ct = $c->req->content_type;

	# will hold all routes with acceptable receive types
	my @routes;

	# remove charset from content-type
	if ($ct =~ m/^([^;]+)/) {
		$ct = $1;
	}

	$c->log->info("I have received $ct");

	ROUTE: foreach (@all_routes) {
		# does this route accept all media types?
		unless (exists $_->{rules}->{accepts}) {
			push(@routes, $_);
			next ROUTE;
		}

		# okay, it has, what are we accepting?
		foreach my $accept (@{$_->{rules}->{accepts}}) {
			if ($accept eq $ct) {
				push(@routes, $_);
				next ROUTE;
			}
		}
	}

	return @routes;
}

sub negotiate_return_media {
	my ($self, $c, @all_routes) = @_;

	my @mimes;
	foreach (@{$c->wanted_mimes}) {
		push(@mimes, $_->{mime});
	}
	$c->log->info('Remote address wants '.join(', ', @mimes));

	# will hold all routes with acceptable return types
	my @routes;
	
	ROUTE: foreach (@all_routes) {
		# what media types does this route return?
		my @have = exists $_->{rules}->{returns} ? 
			@{$_->{rules}->{returns}} :
			('text/html');

		# what routes do the client want?
		if (@{$c->wanted_mimes}) {
			foreach my $want (@{$c->wanted_mimes}) {
				# does the client accept _everything_?
				# if so, just return the first type we support.
				# this will happen only in the end of the
				# wanted_mimes list, so if the client explicitely
				# accepts a type we support, it will have
				# preference over this
				if ($want->{mime} eq '*/*' && $want->{q} > 0) {
					push(@routes, { media => $have[0], route => $_ });
					next ROUTE;
				}
				
				# okay, the client doesn't support */*, let's see what we have
				foreach my $have (@have) {
					if ($want->{mime} eq $have) {
						# we return a MIME type the client wants
						push(@routes, { media => $want->{mime}, route => $_ });
						next ROUTE;
					}
				}
			}
		} else {
			push(@routes, { media => $have[0], route => $_ });
			next ROUTE;
		}
	}
	
	return @routes;
}

sub negotiate_charset {
	my ($self, $c) = @_;

	if ($c->req->header('Accept-Charset')) {
		my @chars = split(/,/, $c->req->header('Accept-Charset'));
		foreach (@chars) {
			my ($charset, $pref) = split(/;q=/, $_);
			next unless defined $pref;
			if ($charset =~ m/utf-?8/i && $pref == 0) {
				croak "This server only supports the UTF-8 character set, unfortunately we are unable to fulfil your request.";
			}
		}
	}

	return 1;
}

sub method_name {
	my ($self, $meth) = @_;

	# replace 'del' with 'delete'
	$meth = 'delete' if $meth eq 'del';

	# return this in uppercase
	return uc($meth);
}

__PACKAGE__->meta->make_immutable;
