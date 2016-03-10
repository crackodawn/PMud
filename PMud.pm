package PMud;

use strict;
use warnings;
use Time::HiRes qw(usleep);
use PMud::Socket;
use PMud::Data;

our $VERSION = '0.01';

=head1 Synopsis

  PMud - The PMud event system.  With this module you can create a PMud object
  and then call the run method to start up the system.  The system will continue
  running until it is shut down by someone connected.

  use PMud;

  my $mud = PMud->new(
                db => '/path/to/file.db',
                port => 9999,
                motd => '/path/to/motd.txt'
            );

  $mud->run or exit 1;

  exit 0;

=cut

=head1 Methods

=cut

=head2 new(%args)

  Create a new PMud object - this is the main object that runs the entire
  MUD system.

  Possible arguments are:
    db => 'file',
    port => ####,
    motd => 'file',
    adminchar => 'c'

  db and port are required arguments where db is the full path to the SQLITE3
  database (if it doesn't exist, it will be created), and port is an integer 
  of the port that the server should listen on.

  If motd is specified as a full path to a file that exists, then the text in
  this file will be sent to each client as they connect.

  adminchar specifies a single character that administrator clients can use to
  specify that they are trying to execute an administrative command.  The
  default is '.' but it can be set to any character.

=cut

sub new {
    my $class = shift;
    my %opts = @_;

    my $self = {};

    die "No db filename provided" if (! $opts{db});
    die "No port specified" if (! $opts{port});

    $self->{dbfile} = $opts{db};
    $self->{port} = $opts{port};

    if ($opts{motd} and -r $opts{motd}) {
        open my $motd, '<', $opts{motd} or die "Can't open $opts{motd}: $!";
        while (<$motd>) {
            $self->{motd} .= $_;
        }
        close $motd;
    } else {
        $self->{motd} = "";
    }

    if ($opts{adminchar}) {
        $self->{adminchar} = substr($opts{adminchar},0,1);
    } else {
        $self->{adminchar} = ".";
    }

    return bless $self, $class;
}

=head2 $self->run

  The run method actually starts the MUD process.  It reads the database
  (creating one if it doesn't exist), opens the listening socket, and then
  starts the control loop.

=cut

sub run {
    my $self = shift;

    my @clients = ();

    # Open the database
    $self->{data} = PMud::Data->new(dbfile => $self->{dbfile});
    # Open the server socket
    $self->{server} = PMud::Socket->new(port => $self->{port});

    my $cinput;
    my $cnum;
    $self->{up} = 1;
    # Run the loop
    while ($self->{up}) {
        # Get new clients
        foreach my $client ($self->{server}->getNewClients) {
            push @clients, $client;
            $client->send($self->{motd});
            $client->authenticate;
        }

        $cnum = 0;
        # Process output/input for all clients
        while ($clients[$cnum]) {
            if (! $clients[$cnum]->connected or ! $clients[$cnum]->writebuffer) {
                $clients[$cnum]->disconnect;
                splice(@clients, $cnum, 1);
                next;
            }

            $cinput = $clients[$cnum]->get;

            if (defined $cinput) {
                # Process player input if the client has authenticated
                if ($clients[$cnum]->authentic) {
                    if ($cinput) {
                        my ($cmd, @args) = split(/\s+/, $cinput);
                        # If input starts with the admin character and the player
                        # is an admin, process admin input
                        if (substr($cmd,0,1) eq $self->{adminchar} and $clients[$cnum]->player->is_admin) {
                            $self->admin_do(lc(substr($cmd,1)), @args);
                        } else {
                            $clients[$cnum]->player->do(lc($cmd), @args);
                        }
                    }
                    $clients[$cnum]->player->send_prompt;
                # Otherwise try to continue client authentication
                } elsif ($cinput) {
                    $clients[$cnum]->authenticate($self->{data}, $cinput);
                }
            }

            $cnum++;
        }

        $self->{data}->cleanup;

        usleep(1000);
    }
}

=head2 $self->admin_do($command)

   Process an administrative command.  This method is called when a connected
   client with administrative permissions tries to run a command starting with
   the defined admin character (default '.').

=cut

sub admin_do {
    my $self = shift;
    my $command = shift;

    return undef if (! $self->isa("PMud"));

    if ($command =~ /^die$/) {
        $self->{up} = 0;
    }
}

=head2 $self->errstr

  Returns the last error string set for the object

=cut

sub errstr {
    my $self = shift;
    my $err = shift;

    if ($err) { $self->{errstr} = $err; }

    return undef if (! exists $self->{errstr});

    return $self->{errstr};
}

1;
