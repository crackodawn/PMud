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
    $self->{authstep} = 0;
    $self->{authentic} = 0;
    $self->{connected} = 1;

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
        # Remove carriage returns as we never keep these
        $self->{bufferin} =~ s/\r//g;
        $self->{lastrecv} = time;
    } elsif ((time - $self->{lastrecv}) > $TIMEOUT) {
        close $self->{socket};
    }

    my $buffer;
    # If we have a newline, then take everything up to the newline and return
    # it, and remove it from the buffer
    if ($self->{bufferin} =~ /\n/) {
        chomp($buffer = substr($self->{bufferin}, 0, index($self->{bufferin}, "\n")+1));
        $self->{bufferin} = substr($self->{bufferin}, index($self->{bufferin}, "\n")+1);
    }
    return $buffer;
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

# Handle the authentication process for the client
sub authenticate {
    my $self = shift;
    my $pmdata = shift;
    my $input = shift;

    if (! $self->{authstep}) {
        $self->send("login: ");
        $self->{authstep} = 1;
    } elsif ($self->{authstep} == 1) {
        my $player = $pmdata->getObject(type => "player", id => $input);
        if (! $player) {
            $self->{authstep} = 0;
            return 0;
        } else {
            $self->{player} = $player;
            $self->{authstep} = 2;
            $self->send("password: ");
        }
    } elsif ($self->{authstep} == 2) {
        if (! $self->player) {
            $self->send("login: ");
            $self->{authstep} = 1;
            return 0;
        }

        my $checkpass = crypt($input, $self->player->password);
        if ($checkpass eq $self->player->password) {
            $self->{authentic} = 1;
            $self->{connected} = 1;
            # Set the client in the player object
            $self->{player}->client($self);
            $self->send("Welcome to the MUD, ".$self->player->id."!\n\r");
            return 1;
        } else {
            delete $self->{player};
            $self->send("invalid password\n\rlogin: ");
            $self->{authstep} = 1;
            return 0;
        }
    } else {
        return 0;
    }
}

sub authentic {
    my $self = shift;

    if ($self->{authentic}) { return 1; }

    return 0;
}

sub connected {
    my $self = shift;

    return $self->{connected};
}

sub disconnect {
    my $self = shift;

    if (my $pObj = $self->player) {
        $pObj->save;
    }

    $self->{connected} = 0;
}

sub DESTROY {
    print "Destroying client\n";
}

1;
