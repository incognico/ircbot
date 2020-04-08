package antigreentext;

use utf8;
use strict;
use warnings;

my %greentexters;

### start config

my $timestoban = 3;

### end config

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, $user, $host, undef) = @_;

   return unless ($target eq '#idletalk');

   if (main::stripcodes($msg) =~ /^\s?>/) {
      my $mask = $user . '@' . $host;

      $greentexters{$mask}++;

      if ($greentexters{$mask} > $timestoban - 1) {
         main::raw('MODE %s +b *!%s', $target, $mask);
         delete $greentexters{$mask};
         printf("[%s] === modules::%s: Banned greentexter [%s] from %s\n", scalar localtime, __PACKAGE__, $nick, $target);
      }

      main::kick($target, $nick, 'Please do not write like this on IRC.');
      printf("[%s] === modules::%s: Kicked greentexter [%s] from %s\n", scalar localtime, __PACKAGE__, $nick, $target);
   }
}

1;
