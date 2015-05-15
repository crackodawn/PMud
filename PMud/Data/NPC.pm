package PMud::Data::NPC;

use strict;
use warnings;

@PMud::Data::NPC::ISA = ('PMud::Data');

my $uid = 0;

sub new {
    my $class = shift;
    my $parent = shift;
    my $data = shift;

    return undef if (! $data or ref $data ne "HASH");

    my $self = {};

    $self->{parent} = $parent;

    # Store the entire data structure so we can easily dump it back to DB later
    $self->{data} = $data;
    $self->{id} = $data->{id};
    $self->{uid} = $uid;
    $uid++;

    bless $self, $class;

    return $self;
}

sub uid {
    my $self = shift;

    return $self->{uid};
}

1;
