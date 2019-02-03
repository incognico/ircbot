package operit;

use utf8;
use strict;
use warnings;

use experimental 'smartmatch';

no warnings 'qw';

my $mytrigger;

my %operitqueue;

### start config

my @operitchans = qw(
#example
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
   my ($self, $target, $msg, $ischan, $nick, undef, undef, $who) = @_;

   return unless ($ischan && $target ~~ @operitchans);

   # cmds 
   if ($msg eq 'operit') {
      $operitqueue{$who} = $target;
      main::raw('USERHOST %s', $nick);
   }
}

sub on_userhost {
   my ($self, $oper, $nick, undef, undef, $who) = @_;

   if ($oper && $operitqueue{$who}) {
      main::raw('MODE %s +o %s', $operitqueue{$who}, $nick);
   }

   delete $operitqueue{$who};
}

1;
