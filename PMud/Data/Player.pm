package PMud::Data::Player;

use strict;
use warnings;

@PMud::Data::Player::ISA = ('PMud::Data');

sub new {
    my $class = shift;
    my $data = shift;

    return undef if (! $data or ref $data ne "HASH");

    my $self = {};

    # Store the entire data structure so we can easily dump it back to DB later
    $self->{data} = $data;

    bless $self, $class;

    return $self;
}

1;
