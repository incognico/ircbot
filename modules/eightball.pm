package eightball;

use utf8;
use strict;
use warnings;

my $mychannels;

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);
   
   $mychannels = $self->{mychannels};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;
  
   # cmds
   if ($msg =~ /^((?:\[\s\]\s[^\[\]]+\s?)+)/) {
      if ($ischan) {
         return if (exists $mychannels->{rizon}{$target}{Cherry});
      }
      else {
         return;
      }

      my @x;

      $msg =~ s/(\[\s\]\s[^\[\]]+)+?\s?/push @x,$1/eg;
      $x[int(rand(@x))] =~ s/\[\s\]/[x]/;

      main::msg($target, "@x");
   }
}

1;
