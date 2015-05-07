package PMud::Socket::Client;

use strict;
use warnings;

@PMud::Socket::Client::ISA = ('PMud::Socket', 'PMud');

our $TIMEOUT = 900;

=head1 Synopsis

  Objects for each connected client

=cut

=head1 Methods

=head2 new

  Create a new object, takes one mandatory argument which is an IO::Socket::INET
  connection.

=cut

sub new {
    my $class = shift;
    my $socket = shift;

    my $self = {};

    $self->{socket} = $socket;
    $self->{lastrecv} = time;

    return bless $self, $class;
}

=head2 send

  Add to the output buffer for the client.

=cut

sub send {
    my $self = shift;
    my $data = shift;

    if ($data) {
        $self->{bufferout} .= $data;
    }

    return 1;
}

=head2 writebuffer

  Write the output buffer to the client.

=cut

sub writebuffer {
    my $self = shift;

    my $rc = 1;
    if ($self->{bufferout}) {
        $rc = syswrite($self->{socket}, $self->{bufferout});
        $self->{bufferout} = "";
    }

    return $rc;
}

=head2 get

  Read the client for data to add to the input buffer

=cut

sub get {
    my $self = shift;

    my $data;
    sysread($self->{socket}, $data, 4096);

    if ($data) {
        $self->{bufferin} .= $data;
        $self->{lastrecv} = time;
    } elsif ((time - $self->{lastrecv}) > $TIMEOUT) {
        close $self->{socket};
    }

    return $self->{bufferin};
}

=head2 player

  Returns the player object attached to this client if one exists, otherwise undef

=cut

sub player {
    my $self = shift;

    if (exists $self->{player} and ref $self->{player}) {
        return $self->{player};
    }

    return undef;
}

sub disconnect {
    my $self = shift;

    if (my $pObj = $self->player) {
        $pObj->save;
    }
}

sub DESTROY {
    print "Destroying client\n";
}

1;
