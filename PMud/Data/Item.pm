package PMud::Data::Item;

use strict;
use warnings;

@PMud::Data::Item::ISA = ('PMud::Data');

my $SID = 0;

sub new {
    my $class = shift;
    my $parent = shift;
    my $data = shift;

    return undef if (! $data or ref $data ne "HASH");

    my $self = {};

    $self->{parent} = $parent;

    # Store the entire data structure so we can easily dump it back to DB later
    $self->{data} = $data;
    $self->{sid} = $SID;
    $SID++;

    bless $self, $class;

    return $self;
}

sub sid {
    my $self = shift;

    return $self->{sid};
}

1;

