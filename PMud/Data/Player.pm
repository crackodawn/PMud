package PMud::Data::Player;

use strict;
use warnings;
use Data::Dumper;

@PMud::Data::Player::ISA = ('PMud::Data');

my @CMDDISPATCH = (
    'north',        \&north,
    'ne',           \&northeast,
    'northeast',    \&northeast,
    'nw',           \&northwest,
    'northwest',    \&northwest,
    'east',         \&east,
    'south',        \&south,
    'se',           \&southeast,
    'southeast',    \&southeast,
    'sw',           \&southwest,
    'southwest',    \&southwest,
    'west',         \&west,
    'move',         \&move,
    'look',         \&look
);

=head1 Synopsis

  PMud::Data::Player - one instance of a player object. This object contains
  all of the data about the player and the methods necessary to make the player
  do things such as move around or interact with the world

=head1 Functions

=head2 add_command($command, \&function, $where)

  Call this function directly to extend the possible player commands.
  $cmdname is the command that a player types, and \&function is a reference
  to the function that will be called when the player types this command.
  $where is either 'pre' or 'post' and determines in which order this command
  will be added to the existing dispatch table for command lookups.  Example:
  there is already a command called 'north', and you want to add a new command
  called 'nag'.  If you make $where 'post', if someone types the command 'n' it
  will execute the function for 'north'.  If you use 'pre' for $where, then
  a player typing the command 'n' will execute 'nag' instead.

  The command dispatch will provide the current PMud::Data::Player object as
  the first argument, and the remainder of the arguments the player typed after
  the command will be provided as an array. In the below example, we're adding
  the command 'nag' which will be prepended to the command dispatch table.

  sub nag {
    my $player = shift;
    my @args = @_;

    $player->send("You nag everyone.\n\r");
  }

  PMud::Data::Player::add_command("nag", \&nag, 'pre');

=cut

sub add_command {
    my $command = shift;
    my $function = shift;
    my $where = shift;

    die "Function not provided or not a code block" if (! $function or ref $function ne "CODE");

    if ($where and $where eq "pre") {
        push @CMDDISPATCH, $command, $function;
    } else {
        unshift @CMDDISPATCH, $command, $function;
    }

    return 1;
}

=head1 Methods

=head2 new($parent, $data)

  Create a new PMud::Data::Player object. $parent is a reference to the the 
  PMud::Data object creating this Player object. $data is a hashref of the database
  table row for this player which we use to actually construct the object.

=cut

sub new {
    my $class = shift;
    my $parent = shift;
    my $data = shift;

    return undef if (! $parent or ref $parent ne "PMud::Data");

    return undef if (! $data or ref $data ne "HASH");

    my $self = {};

    $self->{parent} = $parent;

    if ($data) {
        # Store the entire data structure so we can easily dump it back to DB later
        $self->{data} = $data;

        # Separate out the stats into individual variables
        ($self->{deity}, $self->{class}, $self->{level}, $self->{sex}, $self->{position},
        $self->{str}, $self->{dex}, $self->{con}, $self->{int}, $self->{wis},
        $self->{luc}, $self->{currhp}, $self->{maxhp}, $self->{currmana},
        $self->{maxmana}, $self->{currstam}, $self->{maxstam}) = split(/ /, $self->{data}->{stats});
    } else {
        $self->{create} = 1;
    }

    bless $self, $class;

    return $self;
}

=head2 $self->create

  Create a new character - returns 1 with no arguments if the character is in
  the creation process.  With arguments, tries to continue to the next step
  of the creation process.

=cut 

sub create {
    my $self = shift;
}

=head2 $self->id

  Returns the ID of this Player (Name)

=cut

sub id {
    my $self = shift;

    return $self->{data}->{id};
}

=head2 $self->location

    Returns the saved location ID of this player (Room ID)

=cut

sub location {
    my $self = shift;

    return $self->{data}->{location};
}

=head2 $self->room

  Returns the PMud::Data::Room object this player is in.

=cut

sub room {
    my $self = shift;

    return $self->{room};
}

=head2 $self->from_room

  Remove the current player from the current room

=cut

sub from_room {
    my $self = shift;

    if (! $self->room) {
        return 0;
    }

    $self->{room}->removeplayer($self);
    $self->{room} = undef;
    return 1;
}

=head2 $self->to_room

  $self->to_room($roomid)

  $self->to_room($roomobj)

  Puts the player object inside the room specified by the room id number or 
  a room object

=cut

sub to_room {
    my $self = shift;
    my $room = shift;

    if ($self->room) {
        $self->errstr("Player $self->{data}->{id} is already in a room");
        0;
    }

    if (ref $room) {
        $self->{room} = $room;
    } else {
        $self->{room} = $self->{parent}->getObject(type => "room", id => $room);
        if (! $self->{room}) {
            $self->{room} = $self->{parent}->getObject(type => "room", id => 0);
        }
    }

    $self->{room}->addplayer($self);
    return 1;
}

=head2 $self->save

  Compile the data back into DB writable form and then save it back to the DB

=cut

sub save {
    my $self = shift;

    $self->{data}->{stats} = "$self->{class} $self->{level} $self->{sex} $self->{position} $self->{str} $self->{dex} $self->{con} $self->{int} $self->{wis} $self->{luc} $self->{currhp} $self->{maxhp} $self->{currmana} $self->{maxmana} $self->{currstam} $self->{maxstam}";

    $self->writeToDb;
}

=head2 $self->password($password)

  Returns the encrypted stored password for the player if no arguments are
  given, otherwise encrypts and stores the provided password for the player.

=cut

sub password {
    my $self = shift;
    my $password = shift;

    if (! $password) {
        return $self->{data}->{password};
    } else {
        my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
        my $encpass = crypt($password, $salt) or do {
            $self->errstr("Unable to change password, error with crypt");
            return undef;
        };
        $self->{data}->{password} = $encpass;
    }

    return $self->{data}->{password};
}

=head2 $self->client

  Returns the PMud::Socket::Client object attached to this player.

=cut

sub client {
    my $self = shift;
    my $client = shift;

    if ($client and ref $client) {
        $self->{client} = $client;
    }

    return $self->{client};
}

=head2 $self->send($text)

  Sends the provided text to the client attached to this player object.

=cut

# Send text to the client attached to this player
sub send {
    my $self = shift;
    my $text = shift;

    if ($self->client and $text) {
        $self->client->send($text);
        return 1;
    }

    return 0;
}

=head2 $self->is_admin

  Returns true if this player has admin privileges or false otherwise.

=cut

sub is_admin {
    my $self = shift;

    if ($self->{deity} >= 10) { return 1; }

    return 0;
}

=head2 $self->do($command)

  Make this player do something.

=cut

sub do {
    my $self = shift;
    my $command = shift;
    my @args = @_;

    return 0 if (! $command);
    my $i = 0;
    while ($i <= $#CMDDISPATCH) {
        if ($CMDDISPATCH[$i] =~ /^$command/i) {
            $i++;
            return $CMDDISPATCH[$i]->($self, @args);
        }

        $i += 2;
    }

    return 0;
    #if (my $method = $self->can("cmd$command")) {
        #return $self->$method(@args);
    #} else {
        #$self->send("You can't do that!\n\r");
        #return 0;
    #}
}

################################################
# All the commands that can be performed by 'do'

sub bug {
    my $self = shift;
    my $message = join(' ', @_);

    if (! $message) {
        $self->send("A description of the bug must be supplied");
        return 0;
    }

    PMud::Data::log_bug($message);

    return 1;
}

sub look {
    my $self = shift;

    $self->send($self->room->name."\n\r".$self->room->description."\n\r");

    return 1;
}

sub northwest {
    my $self = shift;

    return $self->move("nw");
}

sub north {
    my $self = shift;

    return $self->move("n");
}

sub northeast {
    my $self = shift;

    return $self->move("ne");
}

sub east {
    my $self = shift;

    return $self->move("e");
}

sub southeast {
    my $self = shift;

    return $self->move("se");
}

sub south {
    my $self = shift;

    return $self->move("s");
}

sub southwest {
    my $self = shift;

    return $self->move("sw");
}

sub west {
    my $self = shift;

    return $self->move("w");
}

sub move {
    my $self = shift;
    my $dir = lc(shift);

    if ($self->room) {
        my $newroom = $self->room->exit($dir);

        if ($newroom) {
            $self->room->send($self->id." has left the room.", $self);
            $self->from_room;
            $self->to_room($newroom);
            $self->room->send($self->id." has entered the room.", $self);
            $self->look;
            return 1;
        }
    }

    $self->send("No exit exists in that direction.\n\r");
    return 0;
}

1;
