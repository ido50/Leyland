package Leyland::Context;

use Moose;
use namespace::autoclean;
use Plack::Request;
use Plack::Response;
use Leyland::Exception;
use Encode;
use Carp;
use Module::Load;
use Data::Dumper;

has 'leyland' => (is => 'ro', isa => 'Leyland', required => 1);

has 'env' => (is => 'ro', isa => 'HashRef', required => 1);

has 'views' => (is => 'ro', isa => 'ArrayRef', default => sub { [] });

has 'config' => (is => 'ro', isa => 'HashRef', default => sub { {} });

has 'req' => (is => 'ro', isa => 'Plack::Request', lazy_build => 1);

has 'res' => (is => 'ro', isa => 'Plack::Response', default => sub { Plack::Response->new(200) });

has 'routes' => (is => 'ro', isa => 'ArrayRef[HashRef]', predicate => 'has_routes', writer => '_set_routes');

has 'log' => (is => 'ro', isa => 'Leyland::Logger', lazy_build => 1);

has 'wanted_mimes' => (is => 'ro', isa => 'ArrayRef[HashRef]', builder => '_build_mimes');

has 'want' => (is => 'ro', isa => 'Str', writer => '_set_want');

has 'lang' => (is => 'ro', isa => 'Str', writer => 'set_lang');

has 'current_route' => (is => 'rw', isa => 'Int', default => 0);

has 'pass_next' => (is => 'ro', isa => 'Bool', default => 0, writer => '_pass');

has 'stash' => (is => 'ro', isa => 'HashRef', default => sub { {} });

has 'controller' => (is => 'ro', isa => 'Str', writer => '_set_controller');

has 'session' => (is => 'ro', isa => 'HashRef', lazy_build => 1);

has 'user' => (is => 'ro', isa => 'Any', predicate => 'has_user', writer => 'set_user', clearer => 'clear_user');

has 'json' => (is => 'ro', isa => 'Object', required => 1); # 'isa' should be 'JSON::Any', but for some reason JSON::Any->new blesses an array-ref, so validation fails

has 'xml' => (is => 'ro', isa => 'XML::TreePP', required => 1);

has 'died' => (is => 'ro', isa => 'Bool', default => 0, writer => '_set_died');

sub _build_req {
	Plack::Request->new(shift->env);
}

sub _build_session {
	exists $_[0]->env->{'psgix.session'} ? $_[0]->env->{'psgix.session'} : {};
}

sub _build_log {
	$_[0]->req->logger ? Leyland::Logger->new(logger => $_[0]->req->logger) : Leyland::Logger->new;
}

sub pass {
	my $self = shift;

	if ($self->routes->[$self->current_route + 1]) {
		my $new_route = $self->current_route + 1;
		$self->current_route($new_route);
		$self->_pass(1);
		return 1;
	}

	return 0;
}

sub view {
	my ($self, $name) = @_;

	foreach (@{$self->views} || ()) {
		next unless $_->name eq $name;
		return $_;
	}

	croak "Can't find a view named $name.";
}

sub render {
	my ($self, $tmpl_name, $context, $use_layout) = @_;

	# first, run the pre_template sub
	$self->controller->pre_template($self, $tmpl_name, $context, $use_layout);

	# allow passing $use_layout but not passing $context
	if (defined $context && ref $context ne 'HASH') {
		$use_layout = $context;
		$context = {};
	}

	# default $use_layout to 1
	$use_layout = 1 unless defined $use_layout;

	$context->{c} = $self;
	$context->{l} = $self->leyland;
	foreach (keys %{$self->stash}) {
		$context->{$_} = $self->stash->{$_} unless exists $context->{$_};
	}

	return unless scalar @{$self->views};

	return $self->views->[0]->render($tmpl_name, $context, $use_layout);
}

sub template {
	Encode::encode('utf8', shift->render(@_));
}

sub structure {
	my ($self, $obj, $want) = @_;
	
	if ($want eq 'application/json') {
		return $self->json->to_json($obj);
	} elsif ($want eq 'application/atom+xml' || $want eq 'application/xml') {
		return $self->xml->write($obj);
	} else {
		# just use Data::Dumper
		return Dumper($obj);
	}
}

sub _build_mimes {
	my $self = shift;

	my @wanted_mimes;

	my $accept = $self->req->header('Accept');
	if ($accept) {
		my @mimes = split(/, ?/, $accept);
		foreach (@mimes) {
			my ($mime, $q) = split(/;q=/, $_);
			$q = 1 unless defined $q;
			push(@wanted_mimes, { mime => $mime, q => $q });
		}
		@wanted_mimes = reverse sort { $a->{q} <=> $b->{q} } @wanted_mimes;
		return \@wanted_mimes;
	} else {
		return [];
	}
}

sub forward {
	my ($self, $path) = (shift, shift);

	$self->exception({ code => 500 }) unless $path;

	$self->log->info("Attempting to forward request to $path.");

	my @routes = $self->leyland->conneg->just_routes($self, $self->leyland->routes, $path);

	$self->exception({ code => 500 }) unless scalar @routes;

	my @pass = ($self->controller, $self);
	push(@pass, @{$routes[0]->{captures}}) if scalar @{$routes[0]->{captures}};
	push(@pass, @_) if scalar @_;

	# just invoke the first matching route
	return $routes[0]->{code}->(@pass);
}

sub loc {
	my ($self, $msg, @args) = @_;

	return $self->leyland->localizer->loc($msg, $self->lang, @args);
}

sub exception {
	my $err = $_[1]->{error} || $Leyland::CODES->{$_[1]->{code}}->[0];
	$_[0]->log->debug("Exception thrown: $_[1]->{code}, message: $err");
	Leyland::Exception->throw($_[1]);
}

sub path_to {
	my ($self, @args) = @_;

	my $params = pop @args if scalar @args && ref $args[$#args] eq 'HASH';
	
	foreach (@args) {
		s!^/!!;
	}

	my $path = '';
	$path .= join('/', @args) if scalar @args;
	if ($params && ref $params eq 'HASH') {
		$path .= '?' . join('&', map($_.'='.$params->{$_}, keys %$params));
	}

	return '/'.$path;
}

sub uri_for {
	my $self = shift;

	my $path = $self->path_to(@_);
	$path =~ s!^/!!;

	return URI->new($self->req->base.$path);
}

sub pre_exception {
	1;
}

__PACKAGE__->meta->make_immutable;
