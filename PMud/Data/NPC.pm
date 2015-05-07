package PMud::Data::NPC;

use strict;
use warnings;

@PMud::Data::NPC::ISA = ('PMud::Data');

sub new {
    my $class = shift;
    my %data = @_;

    my $self = {};

    return bless $self, $class;
}

1;
