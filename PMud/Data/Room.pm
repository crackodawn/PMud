package PMud::Data::Room;

use strict;
use warnings;

@PMud::Data::Room::ISA = ('PMud::Data');

my %OBJS = ();

sub new {
    my $class = shift;
    my $data = shift;

    return undef if (! $data or ref $data ne "HASH");

    my $self = {};

    # Store the entire data structure so we can easily dump it back to DB later
    $self->{data} = $data;
    $self->{id} = $data->{id};

    bless $self, $class;

    $OBJS{$self->{id}} = $self;

    return $self;
}

1;
