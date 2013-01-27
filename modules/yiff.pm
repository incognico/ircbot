# ported (lol) from https://github.com/derpcat/YiffServ/blob/master/YiffServ.pl

package yiff;

use utf8;
use strict;
use warnings;

my $mychannels;
my $mynick;
my $myprofile;
my $rawlog;

my @yiffs;

### start config

my $file       = sprintf("$ENV{HOME}/.bot/%s/%ss.txt", __PACKAGE__, __PACKAGE__);
my $percentage = 0.2; # 0.25 = 25%

### end config

unless(open my $fh, '<', $file) {
   return;
}
else {
   while(my $line = <$fh>) {
      chomp $line;
      push @yiffs, $line;
   }
   close $fh;
}

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mychannels = $self->{mychannels};
   $mynick     = $self->{mynick};
   $myprofile  = $self->{myprofile};
   $rawlog     = $self->{rawlog};

   return $self;
}

### hooks

sub on_join {
   my ($self, $nick, $chan) = @_;

   unless ($nick eq $$mynick) {
      my $user = $mychannels->{$$myprofile}{$chan}{(keys $mychannels->{$$myprofile}{$chan})[int rand keys $mychannels->{$$myprofile}{$chan}]};
      my $yiff;

      $yiff = $yiffs[int(rand(@yiffs))];
      $yiff =~ s/\$nick/$$mynick/g;
      $yiff =~ s/\$target/$nick/g;
      $yiff =~ s/\$user/$user/g;
      $yiff =~ s/\$channel/$chan/g;

      if (rand(1) <= $percentage) {
         main::act($chan, $yiff);
         printf("[%s] === modules::%s: Yiffed [%s] on %s\n", scalar localtime, __PACKAGE__, $nick, $chan) unless $$rawlog;
      }
   }
}

1;
