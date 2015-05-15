package PMud::Data::Player;

use strict;
use warnings;

@PMud::Data::Player::ISA = ('PMud::Data');

=head1 Synopsis

  PMud::Data::Player - one instance of a player object. This object contains
  all of the data about the player and the methods necessary to make the player
  do things such as move around or interact with the world

=head1 Methods

=head2 new($parent, $data)

  Create a new PMud::Data::Player object. $parent is a reference to the the 
  PMud::Data object creating this Player object. $data is a hashref to the database
  table row for this player which we use to actually construct the object.

=cut

sub new {
    my $class = shift;
    my $parent = shift;
    my $data = shift;

    return undef if (! $data or ref $data ne "HASH");

    my $self = {};

    $self->{parent} = $parent;

    # Store the entire data structure so we can easily dump it back to DB later
    $self->{data} = $data;

    # Separate out the stats into individual variables
    ($self->{class}, $self->{level}, $self->{sex}, $self->{position},
    $self->{str}, $self->{dex}, $self->{con}, $self->{int}, $self->{wis},
    $self->{luc}, $self->{currhp}, $self->{maxhp}, $self->{currmana},
    $self->{maxmana}, $self->{currstam}, $self->{maxstam}) = split(/ /, $self->{data}->{stats});

    $self->{room} = $self->{parent}->getObject(type => "room", id => $self->{data}->{location});
    if (! ref $self->{room}) {
        $self->{room} = $self->{parent}->getObject(type => "room", id => 0);
    }

    bless $self, $class;

    return $self;
}

=head2 $self->room

  Returns the PMud::Data::Room object this player is in.

=cut

sub room {
    my $self = shift;

    return $self->{room};
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

    if ($self->{id} eq "admin") { return 1; }
    if (exists $self->{data}->{admin} and $self->{data}->{admin}) {
        return 1;
    }

    return 0;
}

=head2 $self->do($command)

  Make this player do something.

=cut

sub do {
    my $self = shift;
    my $command = shift;

    $self->send("Trying to do $command\n\r");
}

################################################
# All the commands that can be performed by 'do'

sub look {
    my $self = shift;

    $self->send($self->room->name."\n\r".$self->room->description."\n\r");

    return 1;
}

1;
