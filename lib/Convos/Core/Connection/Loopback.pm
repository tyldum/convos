package Convos::Core::Connection::Loopback;
use Mojo::Base 'Convos::Core::Connection';

# keep participants and rooms stored in a global hash
has _nick         => sub { shift->user->email };
has _participants => sub { state $p = {}; };
has _rooms        => sub { state $r = {}; };

sub connect {
  my ($self, $cb) = (shift, pop);
  $self->tap($cb, '');    # always connected
}

sub disconnect {
  my ($self, $cb) = (shift, pop);

  return $self->tap($cb, 'Cannot disconnect from Loopback.');
}

sub participants {
  my ($self, $name, $cb) = @_;
  my $participants = $self->_participants->{$name} || {};
  my @list = map { {name => $_} } keys %$participants;

  return $self->tap($cb, {participants => \@list});
}

sub rooms {
  my ($self, $cb) = (shift, pop);
  my @rooms = map { {name => $_} } keys %{$self->_rooms};

  return $self->tap($cb, '', \@rooms);
}

sub send {
  my ($self, $target, $message, $cb) = @_;

  $target  //= '';
  $message //= '';
  $message =~ s![\x00-\x1f]!!g;    # remove invalid characters
  $message = Mojo::Util::trim($message);

  $message =~ s!^/([A-Za-z]+)\s*!! or return $self->_send($target, $message, $cb);
  my $cmd = uc $1;

  return $self->_send($target, $message, $cb) if $cmd eq 'SAY';
  return $self->_send(split(/\s+/, $message, 2), $cb) if $cmd eq 'MSG';
  return $self->tap($cb, '') if $cmd eq 'CONNECT';
  return $self->disconnect($cb) if $cmd eq 'DISCONNECT';
  return $self->participants($target, $cb) if $cmd eq 'NAMES';
  return $self->_join_dialog($message, $cb) if $cmd eq 'JOIN';
  return $self->_part_dialog($message || $target, $cb) if $cmd eq 'CLOSE' or $cmd eq 'PART';
  return next_tick $self, $cb => 'Unknown Loopback command.', undef;
}

sub _join_dialog {
  my ($self, $name, $cb) = @_;
  my $dialog = $self->dialog({name => $name});

  $self->_rooms->{$name} = {};
  Scalar::Util::weaken($self->_participants->{$name}{$self->_nick} = $self->user);

  return $self->save(sub { })->tap($cb, '', $dialog);
}

sub _part_dialog {
  my ($self, $name, $cb) = @_;
  delete $self->_participants->{$name}{$self->_nick};
  return $self->tap(remove_dialog => $name)->save($cb);
}

sub _send {
  my ($self, $target, $message, $cb) = @_;
  my $from = $self->_nick;
  my $user = $self->user;

  return next_tick $self, $cb => 'Cannot send empty message.'  unless $message;
  return next_tick $self, $cb => 'Cannot send without target.' unless $target;
  return next_tick $self, $cb => 'Cannot send message to target with spaces.' if $target =~ /\s/;
  return next_tick $self, $cb => 'No such room.' unless $self->_participants->{$target};

  for my $receiver (values %{$self->_participants->{$target}}) {
    next if $receiver eq $user;
    my $c = $receiver->connection('loopback');
    $c->emit(
      message => $c->dialog({name => $target}),
      {
        from      => $from,
        highlight => Mojo::JSON->false,    # TODO
        message   => $message,
        ts        => time,
        type      => 'private',
      }
    );
  }
}

1;
