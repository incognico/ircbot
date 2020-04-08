package antiascii;

use utf8;
use strict;
use warnings;

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   return $self;
}

### hooks

sub on_join {
   my ($self, $chan, $nick, undef, undef, undef) = @_;

   if ($nick eq 'ascii' || $nick eq 'ascii-') {
         main::raw('MODE %s +b %s!*@*', $chan, $nick);
         printf("[%s] === modules::%s: Removed [%s] from %s\n", scalar localtime, __PACKAGE__, $nick, $chan);
         main::kick($chan, $nick, 'I hate you! T_T');
   }
}

1;
