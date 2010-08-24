package Leyland::Logger::LogShutton;

use lib '/home/ido/hub/Log-Shutton/lib', '/home/ido/git/Log-Shutton/lib';

use Moose;
use namespace::autoclean;
use Log::Shutton;

with 'Leyland::Logger';

sub init_logger {
	my ($self, $config) = @_;

	my $s = Log::Shutton->new(app => $config->{app}, env => $config->{env});

	if ($config->{logger}->{outputs}) {
		foreach (@{$config->{logger}->{outputs}}) {
			$s->add_output($_);
		}
	} else {
		$s->add_output({ output => 'File', filename => 'output.log' });
		$s->add_output({ output => 'Screen', log_to => 'STDOUT' });
	}

	if ($config->{logger}->{stores}) {
		foreach (@{$config->{logger}->{stores}}) {
			$s->add_store($_);
		}
	}

	return $s;
}

sub new_request_log {
	my ($self, $req) = @_;

	$self->logger->new_request($req);
}

__PACKAGE__->meta->make_immutable;
