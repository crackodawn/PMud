package PMud::Data;

use strict;
use warnings;
use DBI;
use PMud::Data::Player;
use PMud::Data::Room;
use PMud::Data::NPC;

@PMud::Data::ISA = ('PMud');

=head1 Synopsis

  Data management - SQLITE database functions for Data objects

=head1 Methods

=head2 new

  Create a new Data connection to the database

=cut

my %defaults = (
    dbfile => 'PMud.db'
);

sub new {
    my $class = shift;
    my %opts = @_;

    my $dbfile = $opts{dbfile} // $defaults{dbfile};

    my $self = {};

    my $create = 0;
    if (! -e $dbfile) { $create = 1; }

    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");

    die "Could not open DB file $dbfile: $!" if (! $dbh);

    $dbh->{FetchHashKeyName} = "NAME_lc";

    $self->{dbh} = $dbh;

    bless $self, $class;

    if ($create) {
        $self->_createDb or die "Could not create new database $dbfile";
    }

    # Now preload the entire DB one section at a time
    $self->loadPlayers or die "Unable to load players from database";
    $self->loadNPCs or die "Unable to load NPCs from database";
    $self->loadRooms or die "Unable to load rooms from database";

    return $self;
}

# If a DB file doesn't exist or is empty, create a new one with one user
# and room
sub _createDb {
    my $self = shift;

    # Create the 3 tables
    $self->{dbh}->do("CREATE TABLE players (id INT PRIMARY KEY, name VARCHAR(255), password VARCHAR(14))");
    $self->{dbh}->do("CREATE TABLE npcs (id INT PRIMARY KEY, name VARCHAR(255), description TEXT)");
    $self->{dbh}->do("CREATE TABLE rooms (id INT PRIMARY KEY, name VARCHAR(255), description TEXT)");


    my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    my $passwd = crypt('admin', $salt);

    # Create a single admin user and a basic room, both required to actually
    # login to the MUD
    $self->{dbh}->do("INSERT INTO players VALUES (0, 'admin', '$passwd')") or return 0;
    $self->{dbh}->do("INSERT INTO rooms VALUES (0, 'The Void', 'The empty void of space')") or return 0;

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

# Load all player table data into the data object
sub loadPlayers {
    my $self = shift;

    my $hr = $self->_getTable("players");

    if (ref $hr eq "HASH") {
        $self->{players} = $hr;
        return 1;
    }

    return 0;
}

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

# Load all room table data into the data object
sub loadRooms {
    my $self = shift;

    my $hr = $self->_getTable("rooms");

    if (ref $hr eq "HASH") {
        $self->{rooms} = $hr;
        return 1;
    }

    return 0;
}

=head2 getObject

  Query for an object of a specific type and return a constructed object

=cut

sub getObject {
    my $self = shift;
    my %opts = @_;

    if (! $opts{type}) {
        $self->errstr("No type specified in getObject");
        return undef;
    }

    if (! $opts{id}) {
        $self->errstr("No ID specified in getObject");
        return undef;
    }

    my $obj;
    my $data;
    if ($opts{type} eq "player") {
        if (exists $self->{players}->{$opts{id}}) {
            $data = $self->{players}->{$opts{id}};
        } else {
            $self->errstr("No player with ID $opts{id} exists");
            return undef;
        }
        $obj = PMud::Data::Player->new($data);
    } elsif ($opts{type} eq "room") {
        if (exists $self->{rooms}->{$opts{id}}) {
            $data = $self->{rooms}->{$opts{id}};
        } else {
            $self->errstr("No room with ID $opts{id} exists");
            return undef;
        }
        $obj = PMud::Data::Room->new($data);
    } elsif ($opts{type} eq "npc") {
        if (exists $self->{npcs}->{$opts{id}}) {
            $data = $self->{npcs}->{$opts{id}};
        } else {
            $self->errstr("No npc with ID $opts{id} exists");
            return undef;
        }
        $obj = PMud::Data::NPC->new($data);
    } else {
        $self->errstr("Invalid type specified in getObject");
        return undef;
    }

    return $obj;
}

=head2 save

  Save the Data object (which can be a Player, Room or NPC) back into the DB

=cut

sub save {
    my $self = shift;

    my $objtype = ref $self;

    my $table;
    if ($objtype eq "PMud::Data::Player") {
        $table = "players";
    } elsif ($objtype eq "PMud::Data::Room") {
        $table = "rooms";
    } elsif ($objtype eq "PMud::Data::NPC") {
        $table = "npcs";
    } else {
        return 0;
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
    my $sth = $self->{dbh}->prepare_cached($query);
    if ($sth->execute(@columns, @values)) {
        $sth->finish();
        return 1;
    } else {
        return 0;
    }
}

1;
