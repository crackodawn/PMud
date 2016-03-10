package PMud::Data::Room;

use strict;
use warnings;
use Data::Dumper;

@PMud::Data::Room::ISA = ('PMud::Data');

=head1 Synopsis

  PMud::Data::Room - a room object and the associated methods.

=head1 Methods

=head2 new($parent, $data)

  Create a new PMud::Data::Room object.  $parent is a reference to the
  PMud::Data object used to create this child object, and $data is a database
  row hashref of the room information.  If the only information contained in
  $data is a room ID, then a new blank room will be created with that ID.

=cut

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
    } else {
        if (exists $self->{data}->{exits} and $self->{data}->{exits}) {
            foreach my $exit (split(/ /, $self->{data}->{exits})) {
                my ($dir, $id) = $exit =~ /^(\w+)(\d+)$/;
    
                if ($dir and defined $id) {
                    $self->{exit}->{lc($dir)} = $id;
                }
            }
        }
    }

    $self->{players} = {};

    bless $self, $class;

    return $self;
}

=head2 $self->name

  Returns the name of the room.

=cut

sub name {
    my $self = shift;

    return $self->{data}->{name};
}

=head2 $self->description

  Returns the description of the room.

=cut

sub description {
    my $self = shift;

    return $self->{data}->{description};
}

=head2 $self->terrain

  Returns the terrain type of the room.

=cut

sub terrain {
    my $self = shift;

    return $self->{data}->{terrain};
}

=head2 $self->exit($dir)

  Returns the room object that this room is connected to in the provided
  direction.  If no room exists in that direction, returns undef.

=cut

sub exit {
    my $self = shift;
    my $dir = lc(shift);

    if (exists $self->{exit}->{$dir}) {
        return $self->{parent}->getObject(type => 'room', id => $self->{exit}->{$dir});
    }

    return undef;
}

=head2 $self->send($text, @exceptions)

  Sends the specified text to all PMud::Data::Player objects in the room, except
  any PMud::Data::Player objects in the @exceptions list.

=cut

sub send {
    my $self = shift;
    my $text = shift;
    my @exceptions = @_;

    foreach my $id (keys %{$self->{players}}) {
        $self->{players}->{$id}->send($text) unless (grep { $_ == $self->{players}->{$id} } @exceptions);
    }
}

=head2 $self->addplayer($player)

  Adds the provided PMud::Data::Player object to the room.

=cut

sub addplayer {
    my $self = shift;
    my $player = shift;

    $self->{players}->{$player->id} = $player;

    return 1;
}

=head2 $self->removeplayer($player)

  Removes the provided PMud::Data::Player object from the room

=cut

sub removeplayer {
    my $self = shift;
    my $player = shift;

    delete $self->{players}->{$player->id};

    return 1;
}

=head2 $self->set($var, $value)

  Set the specified variable in the room data to the specified value.

=cut

sub set {
    my $self = shift;
    my $var = shift;
    my $value = shift;

    if (! exists $self->{data}->{var}) {
        return undef;
    }
}

1;
