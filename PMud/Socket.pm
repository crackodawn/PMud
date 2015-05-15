package PMud::Socket;

use strict;
use warnings;
use IO::Socket;
use PMud::Socket::Client;

@PMud::Socket::ISA = ('PMud');

=head1 Synopsis

  PMud::Socket - The server object that handles new client connections

  PMud::Socket->new(port => ####);

=cut

=head1 Methods

=head2 new(port => ####)

  Create a new object with a listening socket.  Port is required.

=cut

sub new {
    my $class = shift;
    my %opts = @_;

    my $self = {};

    die "No port specified" if (! $opts{port});

    $self->{socket} = IO::Socket::INET->new(
        Listen      => SOMAXCONN,
        LocalPort   => $opts{port},
        Blocking    => 0,
        ReuseAddr   => 1,
        Proto       => 'tcp'
    );

    die "Unable to listen on port $opts{port}: $!\n" if (! $self->{socket});

    return bless $self, $class;
}

=head2 $self->getNewClients

  Check for new connections on the object's listening socket and create new
  client objects for each new connection. Returns an array of
  PMud::Socket::Client objects.

=cut

sub getNewClients {
    my $self = shift;

    my @newclients = ();
    while (my $client = $self->{socket}->accept()) {
        push @newclients, PMud::Socket::Client->new($client);
    }

    return @newclients;
}

1;
