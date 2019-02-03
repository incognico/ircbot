package spast;

use utf8;
use strict;
use warnings;

my $mytrigger;

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mytrigger = $self->{mytrigger};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      $target = $nick unless ($ischan);

      # cmds 
      if ($cmd eq 'SPAST') {
         main::msg($target, 'Die Spastizität von %s beträgt %s%%.', $nick, int(rand(101)));
      }
   }
}

1;
