package Leyland::Logger::LogHandler;

use Moose;
use namespace::autoclean;
use Log::Handler;

with 'Leyland::Logger';

sub init_logger {
	my ($self, $config) = @_;

	my $log = Log::Handler->new();

	if ($config && exists $config->{logger} && exists $config->{logger}->{outputs}) {
		foreach (@{$config->{logger}->{outputs}}) {
			my $type = delete $_->{type};
			$log->add($type => $_);
		}
	} else {
		$log->add(file => { filename => 'output.log', minlevel => 'notice', maxlevel => 'debug' });
		$log->add(screen => { log_to => 'STDOUT', minlevel => 'notice', maxlevel => 'debug' });
	}

	return $log;
}

sub new_request_log {
	$_[0]->logger;
}

__PACKAGE__->meta->make_immutable;
