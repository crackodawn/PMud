package PMud::Data::Room;

use strict;
use warnings;

@PMud::Data::Room::ISA = ('PMud::Data');

sub new {
    my $class = shift;
    my $parent = shift;
    my $data = shift;

    return undef if (! $data or ref $data ne "HASH" or ! exists $data->{id});

    my $self = {};

    $self->{parent} = $parent;

    # Store the entire data structure so we can easily dump it back to DB later
    $self->{data} = $data;

    # We've been given an empty data structure so create a new one
    if (! $self->{data}->{name}) {
        $self->{data}->{name} = "Room $self->{data}->{id}";
        $self->{data}->{description} = "Room $self->{data}->{id}";
        $self->{data}->{terrain} = 0;
        $self->{data}->{flags} = 0;
        $self->{data}->{exits} = "";
        $self->{data}->{resets} = "";
    }

    bless $self, $class;

    return $self;
}

sub name {
    my $self = shift;

    return $self->{data}->{name};
}

sub description {
    my $self = shift;

    return $self->{data}->{description};
}

sub terrain {
    my $self = shift;

    return $self->{data}->{terrain};
}

sub set {
    my $self = shift;
    my $var = shift;
    my $value = shift;

    if (! exists $self->{data}->{var}) {
        return undef;
    }
}

1;
