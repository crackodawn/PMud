package PMud::Socket;

use strict;
use warnings;
use IO::Socket;
use PMud::Socket::Client;

@PMud::Socket::ISA = ('PMud');

=head1 Synopsis

  PMud::Socket handles new client connections

=cut

my %defaults = (
    port => 9999
);

=head1 Methods

=head2 new

  Create a new listening socket.  Port may be specified otherwise the default
  will be used.

=cut

sub new {
    my $class = shift;
    my %opts = @_;

    my $self = {};

    my $port = $opts{port} // $defaults{port};

    $self->{socket} = IO::Socket::INET->new(
        Listen      => SOMAXCONN,
        LocalPort   => $port,
        Blocking    => 0,
        ReuseAddr   => 1,
        Proto       => 'tcp'
    );

    die "Unable to listen on port $port: $!\n" if (! $self->{socket});

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
