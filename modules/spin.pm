package spin;
require modules::utils;

use utf8;
use strict;
use warnings;

my $mychannels;
my $mynick;
my $myprofile;
my $mytrigger;

my @words1;
my @words2;
my %spinner;

### start config ###

my $file1 = sprintf("$ENV{HOME}/.bot/%s/words1.txt", __PACKAGE__);
my $file2 = sprintf("$ENV{HOME}/.bot/%s/words2.txt", __PACKAGE__);

### end config ###

if (-e $file1) {
   open my $fh1, '<:encoding(UTF-8)', $file1 || die $!;
   while(my $line = <$fh1>) {
      chomp $line;
      push @words1, $line;
   }
   close $fh1;
}

if (-e $file2) {
   open my $fh2, '<:encoding(UTF-8)', $file2 || die $!;
   while(my $line = <$fh2>) {
      chomp $line;
      push @words2, $line;
   }
   close $fh2;
}

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mychannels = $self->{mychannels};
   $mynick     = $self->{mynick};
   $myprofile  = $self->{myprofile};
   $mytrigger  = $self->{mytrigger};

   return $self;
}

### hooks

sub on_ping {
   delete $spinner{$$myprofile};
}

sub on_privmsg {
   my ($self, $chan, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      return unless $ischan;

      # cmds
      if ($cmd eq 'SPIN') {
         my $word1 = $words1[int(rand(@words1))];
         my $word2 = $words2[int(rand(@words2))];

         unless (exists $spinner{$$myprofile}{$nick}) {
            my $user = (keys $mychannels->{$$myprofile}{$chan})[int rand keys $mychannels->{$$myprofile}{$chan}];

            $user = $nick if ($user eq $$mynick);
            utils->msg($chan, '%s is a %s %s', $user, $word1, $word2);
            $spinner{$$myprofile}{$nick}++;
         }
         else {
            utils->ntc($nick, 'You are a really %s but nice human being. Wait some minutes before you try again.', $word1, $word2);
         }
      }
   }
}

1;