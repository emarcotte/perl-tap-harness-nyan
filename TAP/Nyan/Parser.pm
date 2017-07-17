package TAP::Nyan::Parser;

use parent qw(TAP::Parser);

sub next {
	my ($self, @args) = @_;
	my $result = $self->SUPER::next (@args);

	if($result) {
		push @{$self->{__results}}, $result;
	}

	return $result;
}

1;
