package PMud::Data::Room;

use strict;
use warnings;

@PMud::Data::Room::ISA = ('PMud::Data');

sub new {
    my $class = shift;
    my %data = @_;

    my $self = {};

    return bless $self, $class;
}

1;
