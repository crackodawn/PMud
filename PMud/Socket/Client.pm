package PMud::Socket::Client;

use strict;
use warnings;
use Term::ANSIColor;

@PMud::Socket::Client::ISA = ('PMud::Socket', 'PMud');

our $TIMEOUT = 900;

=head1 Synopsis

  PMud::Socket::Client - Connected client objects.

=cut

=head1 Methods

=head2 new($socket)

  Create a new object, takes one mandatory argument which is an IO::Socket::INET
  object.

=cut

sub new {
    my $class = shift;
    my $socket = shift;

    my $self = {};

    if (! $socket or ! ref $socket) {
        die "No socket provided or socket provided is not a reference";
    }

    $self->{socket} = $socket;
    $self->{socket}->blocking(0);
    $self->{lastrecv} = time;
    $self->{authstep} = 0;
    $self->{authentic} = 0;
    $self->{connected} = 1;

    return bless $self, $class;
}

=head2 $self->send($data)

  Add $data to the output buffer to send to the client.

=cut

sub send {
    my $self = shift;
    my $data = shift;

    if ($data) {
        $self->{bufferout} .= $data;
    }

    return 1;
}

=head2 $self->writebuffer

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

=head2 $self->get

  Read the client for input to add to the input buffer.

  Returns one line of input from the input buffer.

=cut

sub get {
    my $self = shift;

    my $data;
    my $bytes = sysread($self->{socket}, $data, 4096);

    if (defined $bytes and $bytes > 0) {
        $self->{bufferin} .= $data;
        # Remove carriage returns as we never keep these
        $self->{bufferin} =~ s/\r//g;
        $self->{lastrecv} = time;
    } elsif ((time - $self->{lastrecv}) > $TIMEOUT) {
        close $self->{socket};
    }

    my $buffer = undef;
    # If we have a newline, then take everything up to the newline and return
    # it, and remove it from the buffer
    if ($self->{bufferin} and $self->{bufferin} =~ /\n/) {
        chomp($buffer = substr($self->{bufferin}, 0, index($self->{bufferin}, "\n")+1));
        $self->{bufferin} = substr($self->{bufferin}, index($self->{bufferin}, "\n")+1);
    }
    return $buffer;
}

=head2 $self->player

  Returns the PMud::Data::Player object attached to this client if the client
  has one associated with it, otherwise returns undef.

=cut

sub player {
    my $self = shift;

    if (exists $self->{player} and ref $self->{player}) {
        return $self->{player};
    }

    return undef;
}

=head2 $self->authenticate($dataobj, $input)

  Process the authentication of a client.  The first argument is a PMud::Data
  object that can be used to look up a player during authentication.  The
  second argument is some text that will be used to authenticate the player.

  Authentication happens in multiple steps and therefore this method is called
  multiple times, each successful call moves the object's authentication status
  to the next step.

=cut

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
            $self->send("Welcome to the MUD, ".$self->player->id."!\n\r\n\r");
            $self->{player}->to_room($self->{player}->location);
            $self->{player}->room->send($self->{player}->id." appears out of thin air.", $self->{player});
            $self->{player}->do('look');
            $self->{player}->send_prompt;
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

=head2 $self->authentic

  Returns a true value if the client has authenticated, or a false value
  otherwise.

=cut

sub authentic {
    my $self = shift;

    if ($self->{authentic}) { return 1; }

    return 0;
}

=head2 $self->connected

  Returns a true value if the client is thought to still be connected, or a
  false or undefined value if the client is known to no longer be connected.

=cut

sub connected {
    my $self = shift;

    return $self->{connected};
}

=head2 $self->disconnect

  Save any PMud::Data::Player object attached to this client and then close
  the socket and mark it as no longer connected.

=cut

sub disconnect {
    my $self = shift;

    if (my $pObj = $self->player) {
        $pObj->save;
    }

    close $self->{socket};
    $self->{connected} = 0;
}

sub DESTROY {
    print "Destroying client\n";
}

1;
