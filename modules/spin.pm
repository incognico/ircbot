package spin;
require modules::utils;

use utf8;
use strict;
use warnings;

my $mychannels;
my $myprofile;
my $mytrigger;
my $rawlog;

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mychannels = $self->{mychannels};
   $myprofile  = $self->{myprofile};
   $mytrigger  = $self->{mytrigger};
   $rawlog     = $self->{rawlog};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $chan, $msg, $ischan, undef, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      return unless $ischan;

      # cmds
      if ($cmd eq 'SPIN') {
         utils->act($chan, 'points at %s', (keys $mychannels->{$$myprofile}{$chan})[int rand keys $mychannels->{$$myprofile}{$chan}]);
      }
   }
}

1;
