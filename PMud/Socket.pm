package PMud::Socket;

use strict;
use warnings;
use IO::Socket;
use PMud::Socket::Client;

@PMud::Socket::ISA = ('PMud');

=head1 Synopsis

  PMud::Socket handles new client connections

=cut

=head1 Methods

=head2 new

  Create a new listening socket.  Port may be specified otherwise the default
  will be used.

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

=head2 getNewClients

  Check for any new connections and process them.

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
