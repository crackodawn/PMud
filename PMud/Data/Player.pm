package PMud::Data::Player;

use strict;
use warnings;

@PMud::Data::Player::ISA = ('PMud::Data');

my %OBJS = ();

sub new {
    my $class = shift;
    my $data = shift;

    return undef if (! $data or ref $data ne "HASH");

    my $self = {};

    # Store the entire data structure so we can easily dump it back to DB later
    $self->{data} = $data;
    $self->{id} = $data->{id};
    $self->{password} = $data->{password};

    bless $self, $class;

    $OBJS{$self->{id}} = $self;

    return $self;
}

sub password {
    my $self = shift;
    my $password = shift;

    if (! $password) {
        return $self->{password};
    } else {
        my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
        my $encpass = crypt($password, $salt) or do {
            $self->errstr("Unable to change password, error with crypt");
            return undef;
        };
        $self->{password} = $encpass;
        $self->{data}->{password} = $encpass;
    }
}

sub client {
    my $self = shift;
    my $client = shift;

    if ($client and ref $client) {
        $self->{client} = $client;
    }

    return $self->{client};
}

# Send text to the client attached to this player
sub send {
    my $self = shift;
    my $text = shift;

    if ($self->client) {
        $self->client->send($text);
        return 1;
    }

    return 0;
}

sub is_admin {
    my $self = shift;

    if ($self->{id} eq "admin") { return 1; }
    if (exists $self->{data}->{admin} and $self->{data}->{admin}) {
        return 1;
    }

    return 0;
}

sub do {
    my $self = shift;
    my $command = shift;

    $self->send("Trying to do $command\n\r");
}

1;
