package TAP::Nyan::Parser;

use parent qw(TAP::Parser);
use Time::HiRes qw(time);

sub next {
	my ($self, @args) = @_;
	my $result = $self->SUPER::next (@args);
	return $result unless $result; # last call

	# First assert
	unless ($self->{__results}) {
		$self->{__last_assert} = $self->start_time;
		$self->{__results} = []
	}

	# Account for time taken
	$result->{__start_time} = $self->{__last_assert};
	$result->{__end_time} = $self->{__last_assert} = time;

	# Remember for the aggregator
	push @{$self->{__results}}, $result;

	return $result;
}


1;
