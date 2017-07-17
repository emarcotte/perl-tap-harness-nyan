package TAP::Nyan;

use strict;
use warnings;

use parent qw(TAP::Harness);
use Data::Dumper;
use Term::ANSIColor qw();
use Math::Trig;
use Term::ReadKey;

sub new {
	my ($class, $args) = @_;

	my $self = $class->SUPER::new({
		%{$args || {}},
		verbosity => -3,
	});

	$self->parser_class('TAP::Nyan::Parser');
	$self->{total} = 0;
	$self->{pass} = 0;
	$self->{fail} = 0;
	$self->{skip} = 0;
	$self->{color_index} = 0;
	$self->{results} = {};
	$self->{trail} = [];
	$self->{parserjobs} = {};
	return $self;
}

sub make_parser {
	my ($self, $job) = @_;
	my ($parser, $session) = $self->SUPER::make_parser($job);
	$self->{parserjobs}{$parser} = $job->filename;

	$parser->callback(
		plan => sub {
			my ($plan) = @_;
			$self->{total} += $plan->tests_planned;
			$self->print_status;
		}
	);

	$parser->callback(
		test => sub {
			my ($result) = @_;

			if($result->has_skip) {
				$self->{skip}++;
			}
			elsif($result->is_ok) {
				$self->{pass}++;
			}
			else {
				$self->{fail}++;
			}

			push(
				@{$self->{results}{$self->{parserjobs}{$parser}}},
				$result
			);
			push(@{$self->{trail}}, $self->rainbow_txt($self->mark($result)));

			$self->print_status;
		},
	);

	$parser->callback(
		ALL => sub {
			my ($result) = @_;
		}
	);

	$parser->callback(
		unknown => sub {
			my ($result) = @_;
		},
	);
	return ($parser, $session);
}

sub _get_parser_args {
	my ($self, $job) = @_;
	my $args = $self->SUPER::_get_parser_args($job);
	$args->{merge} = 1;
		return $args;
}

sub summary {
	my ($self, @args) = @_;
	$self->{finished} = [@args];
	print $self->print_status();
}

sub mark {
	my ($self, $result) = @_;
	if($result->has_skip) {
		return 'o';
	}
	elsif($result->is_ok) {
		return $self->{color_index} % 2 ? '_' : '-'; #'‾';
	}
	else {
		return '+';
	}
}

sub print_status {
	my ($self, $args) = @_;
	$args ||= {};

	my @cat = @{$self->nyan_cat};
	my $lines = scalar(@cat);
	my $nr = $self->{total};
	my $nr_l = length($nr);
	my $pass = $self->{pass};
	my $skip = $self->{skip};
	my $fail = $self->{fail};
	my $reset = Term::ANSIColor::color('reset');

	my @measures = (
		sprintf("%s%*s", $reset, $nr_l, $pass+$skip+$fail),
		sprintf("%s%*s", Term::ANSIColor::color('green'), $nr_l, $pass),
		sprintf("%s%*s", Term::ANSIColor::color('yellow'), $nr_l, $skip),
		sprintf("%s%*s", Term::ANSIColor::color('red'), $nr_l, $fail),
	);

	my @trail = @{$self->{trail}};

	my ($remaining_width) = Term::ReadKey::GetTerminalSize();
	$remaining_width -= ($nr_l * 2) + 17;

	my $str = join
		'',
		map {
			sprintf(
				"%s%s/%d: %s %s\n",
				$measures[$_],
				$reset,
				$nr,
				join('', ($remaining_width >= @trail) ? @trail: @trail[-$remaining_width..-1]),
				$cat[$_]
			)
		} (0..3);
	print $str;

	if( my ($aggregation, $interupted) = @{$self->{finished} || []} ) {
		my @parsers = $aggregation->parsers;
		foreach my $parser (@parsers) {
			my $file = $self->{parserjobs}{$parser};
			if( $parser->exit || grep { ! $_->is_ok } @{$self->{results}{$file}}) {
				print "**** $file\n";
				foreach my $result (@{$parser->{__results}}) {
					print "  ", $result->raw(), "\n";
				}
			}
		}
	}
	else {
		print "\e[1A" x $lines . "\r";
	}
}

sub nyan_cat {
	my ($self) = @_;

	my $cat_index = $self->{color_index} % 2;
	my $cat = ascii_cat('^');

	if($self->{fail} && $self->{finished}) {
		$cat = ascii_cat('x');
	}
	elsif($self->{fail}) {
		$cat = ascii_cat('o');
	}
	elsif($self->{finished}) {
		$cat = ascii_cat('-');
	}

	return $cat->[$cat_index];
}

sub ascii_cat {
	my ($o) = @_;
	$o ||= '^';

	return [
		[
			"_,------,   ",
			"_|  /\\_/\\ ",
			"~|_( $o .$o)  ",
			" \"\"  \"\" "
		],
		[
			"_,------,   ",
			"_|   /\\_/\\",
			"^|__( $o .$o) ",
			" \" \"  \" \""
		],
	]
}

my @colors = map {
	my $pi_3 = pi / 3;
	my $n = $_ * 1.0 / 6;
	my $r  = (3 * sin($n            ) + 3);
	my $g  = (3 * sin($n + 2 * $pi_3) + 3);
	my $b  = (3 * sin($n + 4 * $pi_3) + 3);
    36 * int($r) + 6 * int($g) + int($b) + 16;
	} (0...(6 * 7));

sub rainbow_txt {
	my ($self, $s) = @_;
	return sprintf("\e[38;5;%sm%s\e[0m", $colors[$self->{color_index}++ % scalar(@colors)], $s);
}

1;

