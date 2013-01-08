package eightball;

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

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;
  
   if ($msg =~ /^((?:\[\s\]\s[^\[\]]+\s?)+)/) {
      my (@x, $y);

      $msg =~ s/(\[\s\]\s[^\[\]]+)+?\s?/push @x,$1/eg;
      $x[int(rand($#x+1))] =~ s/\[\s\]/[x]/;

      if ($ischan) {
         main::msg($target, "$nick: @x");
      }
      else {
         main::msg($nick, "@x");
      }
   }
}

1;
