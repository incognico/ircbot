package flood;

use utf8;
use strict;
use warnings;

use threads;

my $mytrigger;

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mytrigger = $self->{mytrigger};

   return $self;
}

### hooks

sub doflood {
   my $target = shift;
  (my $file   = shift) =~ y/A-Za-z0-9\-_//cd;;

   for (`cat /usr/home/k/ascii/$file.txt 2>&1`) {
      $_ =~ s/\t/ /g;
      $_ =~ s/_\x8//g;
      main::raw('PRIVMSG %s :%s', $target, $_);
   }
   
   if ($? == -1 ) {
      main::err($target, 'no such file');
   }
   elsif ($? >> 8 != 0) {
      main::err($target, 'returned: %d', $? >> 8);
   }
}

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, $who) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      # admin cmds
      return unless (main::isadmin($who));

      $target = $nick unless ($ischan);

      if ($cmd eq 'FLOOD') {
         if ($args[1]) {
            threads->create(\&doflood, $args[0], $args[1])->detach();
         }
         else {
            main::hlp($target, 'syntax: FLOOD <target> <filename>');
         }
      }
   }
}

1;
