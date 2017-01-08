package Convos::Command::set_password;
use Mojo::Base 'Mojolicious::Command';
use Convos::Core::User;

has description => 'Change the password for a user';
has usage       => "\$ convos set_password <email> [password]\n";

sub run {
  my ($self, $email, $password) = @_;
  my $core = $self->app->core;
  die $self->usage unless $email;

  my ($user) = grep { $_->{email} eq $email } @{$core->backend->users};
  die qq(No account with email "$email".\n) unless $user;

  $self->_print(<<"HERE");
Changing password for $email...

Note that Convos must be stopped before running this command,
and started again after.

HERE

  $password ||= $self->_read_password unless $password;
  $user = $core->user($user);
  $user->set_password($password)->save;
  $self->_print(qq(Password changed for "$email".\n));
}

# used for testing
sub _print { shift; print @_; }

sub _read_password {
  my $self = shift;
  my @password;

  require Term::ReadKey;
  Term::ReadKey::ReadMode('noecho');

  until ($password[0]) {
    $self->_print(qq(\nNew login password: ));
    my $pw = STDIN->getline;
    next unless $pw =~ /\S/;
    push @password, $pw;
    last;
  }

  $self->_print(qq(\nRetype password: ));
  push @password, STDIN->getline;
  $self->_print(qq(\n"));

  Term::ReadKey::ReadMode(0);
  chomp for @password;
  die qq(\nPasswords do not match!\n) unless $password[0] eq $password[1];
  return $password[0];
}

1;

END {
  Term::ReadKey::ReadMode(0) if $INC{'Term/ReadKey.pm'};
}
