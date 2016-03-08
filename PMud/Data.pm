package PMud::Data;

use strict;
use warnings;
use DBI;
use PMud::Data::Player;
use PMud::Data::Room;
use PMud::Data::NPC;

@PMud::Data::ISA = ('PMud');

=head1 Synopsis

  PMud::Data - PMud data storage and manipulation.

  Primarily handles the connectivity to the PMud database, but also creates
  new Room, Player and NPC objects from that data.

=head1 Methods

=head2 new(%opts)

  Create a new object which contains a connection to the SQLite database, and
  all of the DB data preloaded into memory.

  %opts must at least contain dbfile => '/path/to/file.db'

=cut

sub new {
    my $class = shift;
    my %opts = @_;

    die "No dbfile specified" if (! $opts{dbfile});

    my $self = {};

    my $create = 0;
    if (! -e $opts{dbfile}) { $create = 1; }

    my $dbh = DBI->connect("dbi:SQLite:dbname=$opts{dbfile}","","");

    die "Could not open DB file $opts{dbfile}: $!" if (! $dbh);

    $dbh->{FetchHashKeyName} = "NAME_lc";

    $self->{dbh} = $dbh;

    bless $self, $class;

    if ($create) {
        $self->_createDb or die "Could not create new database $opts{dbfile}";
    }

    # Now preload the entire DB one section at a time
    $self->loadRooms or die "Unable to load rooms from database";
    $self->loadNPCs or die "Unable to load NPCs from database";
    $self->loadItems or die "Unable to load items from database";

    return $self;
}

# If a DB file doesn't exist or is empty, create a new one with one user
# and room
sub _createDb {
    my $self = shift;

    # Create the 5 tables
    # Stats include location, level, class, sex, position, all current stats, all true stats, curr/max hp/mana/stam
    $self->_do("CREATE TABLE players (id VARCHAR(255) PRIMARY KEY, password VARCHAR(14), flags INT, comms INT, location INT, stats VARCHAR(100), channels INT, skills INT)") or return 0;
    $self->_do("CREATE TABLE npcs (id INT PRIMARY KEY, name VARCHAR(255), short TEXT, description TEXT, stats VARCHAR(100), flags INT)") or return 0;
    $self->_do("CREATE TABLE rooms (id INT PRIMARY KEY, name VARCHAR(255), description TEXT, terrain INT, flags INT, exits VARCHAR(255), resets TEXT)") or return 0;
    # defs will be things like type, size, weight, wearloc
    # typedefs are definitions specific to that item type like armor info, weapon info, or container info
    $self->_do("CREATE TABLE items (id INT PRIMARY KEY, name VARCHAR(255), short TEXT, description TEXT, defs VARCHAR(64), typedefs VARCHAR(64), flags INT, mods INT)") or return 0;
    $self->_do("CREATE TABLE bug (id INT PRIMARY KEY, message TEXT");

    my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    my $passwd = crypt('admin', $salt);

    # Create a single admin user and a basic room, both required to actually
    # login to the MUD
    $self->_do("INSERT INTO players VALUES ('admin', '$passwd', 0, 0, 0, '10 0 1 M 0 1 1 1 1 1 1 1 1 1 1 1 1', 0, 0)") or return 0;
    $self->_do("INSERT INTO rooms VALUES (0, 'The Void', 'The empty void of space', 0, 0, 'N1 E2 W3', NULL)") or return 0;
    $self->_do("INSERT INTO rooms VALUES (1, 'Room 1', 'A new room 1', 0, 0, 'S0', NULL)") or return 0;
    $self->_do("INSERT INTO rooms VALUES (2, 'Room 2', 'A new room 2', 0, 0, 'W0', NULL)") or return 0;
    $self->_do("INSERT INTO rooms VALUES (3, 'Room 3', 'A new room 3', 0, 0, 'E0 S4', NULL)") or return 0;
    $self->_do("INSERT INTO rooms VALUES (4, 'Room 4', 'A new room 4', 0, 0, 'N3', NULL)") or return 0;

    return 1;
}

sub _do {
    my $self = shift;
    my $query = shift;

    return $self->{dbh}->do($query);
}

# Fetch a table as a hashref to store in our object for reference
# later in getObject
sub _getTable {
    my $self = shift;
    my $table = shift;

    my $sth = $self->{dbh}->prepare_cached("SELECT * FROM $table");
    $sth->execute();

    my $hashref = $sth->fetchall_hashref('id');

    $sth->finish();

    return $hashref;
}

sub _getRow {
    my $self = shift;
    my $table = shift;
    my $id = shift;

    my $sth = $self->{dbh}->prepare_cached("SELECT * FROM $table WHERE id = ?");
    $sth->execute($id);
    my $hashref = $sth->fetchrow_hashref();
    $sth->finish();

    return $hashref;
}

=head2 $self->loadNPCs

  Retrieve all data from the npcs table in the DB and store it into a
  hashref in the object.

=cut

# Load all NPC table data into the data object
sub loadNPCs {
    my $self = shift;

    my $hr = $self->_getTable("npcs");

    if (ref $hr eq "HASH") {
        $self->{npcs} = $hr;
        return 1;
    }

    return 0;
}

=head2 $self->loadRooms

  Retrieve all data from the rooms table in the DB and store it into a
  hashref in the object.

=cut

# Load all room table data into a hash of PMud::Data::Room objects
sub loadRooms {
    my $self = shift;

    my $hr = $self->_getTable("rooms");

    if (ref $hr eq "HASH") {
        foreach my $roomid (keys %$hr) {
            my $obj = PMud::Data::Room->new($self, $hr->{$roomid});
            $self->{roomobjs}->{$roomid} = $obj;
        }

        if (! $self->{roomobjs}->{0}) {
            # If no room 0 exists we need to create a blank one, as many things
            # depend on this room existing
            $self->{roomobjs}->{0} = PMud::Data::Room->new($self, { id => 0 });
        }

        return 1;
    }

    return 0;
}

=head2 $self->loadItems

  Retrieve all data from the items table in the DB and store it into a
  hashref in the object.

=cut

# Load all item table data into the data object
sub loadItems {
    my $self = shift;

    my $hr = $self->_getTable("items");

    if (ref $hr eq "HASH") {
        $self->{items} = $hr;
        return 1;
    }

    return 0;
}

=head2 $self->getObject(%opts)

  Query for an object of a specific type and return a constructed PMud::Data::*
  object. Opts:

    type => 'player|room|npc|item',
    id => 'id' # Player name, or room/npc id number

  Once a player or room object is constructed for the first time, it will be 
  statically saved for return later without having to create a new object.

  NPC and Item objects can be duplicates (as there could be more than one of
  a specific item or NPC) and are stored with a sub UID so different copies
  of the same item/npc can be differentiated.

=cut

sub getObject {
    my $self = shift;
    my %opts = @_;

    if (! $opts{type}) {
        $self->errstr("No type specified in getObject");
        return undef;
    }

    if (! exists $opts{id}) {
        $self->errstr("No ID specified in getObject");
        return undef;
    }

    my $obj;
    my $data;
    if ($opts{type} eq "player") {
        if (exists $self->{playerobjs}->{$opts{id}}) {
            $obj = $self->{playerobjs}->{$opts{id}};
        } else {
            my $data = $self->_getRow("players", $opts{id});
            if (! $data) {
                $self->errstr("No player with ID $opts{id} exists");
            }
            $obj = PMud::Data::Player->new($self, $data);
            $self->{playerobjs}->{$opts{id}} = $obj;
        }
    } elsif ($opts{type} eq "room") {
        if (exists $self->{roomobjs}->{$opts{id}}) {
            $obj = $self->{roomobjs}->{$opts{id}};
        } else {
            $self->errstr("No room with ID $opts{id} exists");
            return undef;
        }
    } elsif ($opts{type} eq "npc") {
        if (exists $self->{npcs}->{$opts{id}}) {
            $data = $self->{npcs}->{$opts{id}};
        } else {
            $self->errstr("No npc with ID $opts{id} exists");
            return undef;
        }
        $obj = PMud::Data::NPC->new($self, $data);
        $self->{npcobjs}->{$opts{id}}->{$obj->sid} = $obj;
    } elsif ($opts{type} eq "item") {
        if (exists $self->{items}->{$opts{id}}) {
            $data = $self->{items}->{$opts{id}};
        } else {
            $self->errstr("No item with ID $opts{id} exists");
            return undef;
        }
        $obj = PMud::Data::Item->new($self, $data);
        $self->{itemobjs}->{$opts{id}}->{$obj->sid} = $obj;
    } else {
        $self->errstr("Invalid type specified in getObject");
        return undef;
    }

    return $obj;
}

=head2 $self->id

  Returns the id of the object.

=cut

sub id {
    my $self = shift;

    return $self->{data}->{id};
}

=head2 $self->writeToDb

  Save the Data object (which can be a Player, Room or NPC) back into the DB

=cut

sub writeToDb {
    my $self = shift;

    my $table;
    if ($self->isa("PMud::Data::Player")) {
        $table = "players";
    } elsif ($self->isa("PMud::Data::Room")) {
        $table = "rooms";
    } elsif ($self->isa("PMud::Data::NPC")) {
        $table = "npcs";
    } elsif ($self->isa("PMud::Data::Item")) {
        $table = "items";
    } else {
        return 1;
    }

    my @columns = ();
    my @values = ();
    my @marks = ();
    foreach my $key (keys %{$self->{data}}) {
        push @columns, $key;
        push @values, $self->{data}->{$key};
        push @marks, "?";
    }

    my $query = "INSERT OR REPLACE INTO $table (".join(', ', @marks).") VALUES (".join(', ', @marks).")";
    my $sth = $self->{parent}->{dbh}->prepare_cached($query);
    if ($sth->execute(@columns, @values)) {
        $sth->finish();
        return 1;
    } else {
        return 0;
    }
}

=head2 $self->log_bug

  Log the provided message into the bug table

=cut

sub log_bug {
    my $self = shift;
    my $message = shift;

    return 0 if (! $message);

    my $sth = $self->{parent}->{dbh}->prepare_cached("INSERT INTO bug (message) VALUES (?)");
    if ($sth->execute($message)) {
        $sth->finish();
        return 1;
    } else {
        return 0;
    }
}

=head2 $self->cleanup

  Clean up all objects that are no longer needed (NPC or Item objects that
  should no longer exist because they're dead or have been destroyed)

=cut

sub cleanup {
    my $self = shift;
}

1;
