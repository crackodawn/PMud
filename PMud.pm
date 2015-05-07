package PMud;

use strict;
use warnings;
use Time::HiRes qw(usleep);
use PMud::Socket;
use PMud::Data;

=head1 Synopsis

  PMud - The entire PMud event system

=cut

=head1 Methods

=cut

=head2 new

  Create a new PMud object - this is the main object that runs the entire
  MUD system.

=cut

my %defaults = (
    motd => 'motd'
);

sub new {
    my $class = shift;
    my %opts = @_;

    my $self = {};

    my $motdfile = $opts{motd} // $defaults{motd};
    if ($motdfile and -r $motdfile) {
        open my $motd, '<', $motdfile;
        while (<$motd>) {
            $self->{motd} .= $_;
        }
        close $motd;
    }

    return bless $self, $class;
}

=head2 run

  Start the MUD - runs in a continuous loop until an exit code is received
  (from someone connected)

=cut

sub run {
    my $self = shift;

    my @clients = ();

    my $data = PMud::Data->new();
    my $server = PMud::Socket->new();

    my $up = 1;
    my $cinput;
    my $cnum;
    while ($up) {
        foreach my $client ($server->getNewClients) {
            push @clients, $client;
            $client->send($self->{motd});
        }

        $cnum = 0;
        while ($clients[$cnum]) {
            $clients[$cnum]->writebuffer or do {
                $clients[$cnum]->disconnect;
                splice(@clients, $cnum, 1);
                next;
            };

            $cinput = $clients[$cnum]->get;

            if ($cinput =~ /die/) {
                $up = 0;
            }

            $cnum++;
        }

        usleep(1000);
    }
}

=head2 errstr

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
