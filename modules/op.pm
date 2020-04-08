package op;

use utf8;
use strict;
use warnings;

use experimental 'smartmatch';

no warnings 'qw';

my $mytrigger;

### start config

my $autoop = 1;

my @opchans = qw(
);

my @ophosts = qw(
);

### end config

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mytrigger = $self->{mytrigger};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, $host, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      return unless ($ischan && $target ~~ @opchans && $host ~~ @ophosts);

      # cmds 
      if ($cmd eq 'OP') {
         main::raw('MODE %s +o %s', $target, $nick);
      }
   }
}

sub on_join {
   my ($self, $chan, $nick, undef, $host, undef) = @_;

   main::raw('MODE %s +o %s', $chan, $nick) if ($autoop && $chan ~~ @opchans && $host ~~ @ophosts);
}

1;
