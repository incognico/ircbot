package namen;

use utf8;
use strict;
use warnings;

my $mychannels;
my $mynick;
my $myprofile;
my $mytrigger;

my @namenm;
my @namenw;
my @namenn;

### start config

my $filem = sprintf("$ENV{HOME}/.bot/%s/m.txt", __PACKAGE__);
my $filew = sprintf("$ENV{HOME}/.bot/%s/w.txt", __PACKAGE__);
my $filen = sprintf("$ENV{HOME}/.bot/%s/n.txt", __PACKAGE__);

my @titel = qw(Dr. Prof.);
my @adel  = qw(von zu);

### end config

unless(open my $fhm, '<', $filem) {
   return;
}
else {
   while(my $line = <$fhm>) {
      chomp $line;
      push @namenm, $line;
   }
   close $fhm;
}

unless(open my $fhw, '<', $filew) {
   return;
}
else {
   while(my $line = <$fhw>) {
      chomp $line;
      push @namenw, $line;
   }
   close $fhw;
}

unless(open my $fhn, '<', $filen) {
   return;
}
else {
   while(my $line = <$fhn>) {
      chomp $line;
      push @namenn, $line;
   }
   close $fhn;
}

### functions

sub getname {
   my ($mumu, $drprof, $name);

   if (rand(1) <= 0.15) {
      $name .= $titel[int(rand(@titel))] . ' ';
      $drprof = 1;
   }

   if (rand(1) <= 0.5) {
      $name .= $namenm[int(rand(@namenm))];
   }
   else {
      $name .= $namenw[int(rand(@namenw))];
      $mumu = 1;
   }

   unless ($name =~ /-/) {
      if (rand(1) <= 0.2) {
         unless ($mumu) {
            $name .= '-' . $namenm[int(rand(@namenm))];
         }
         else {
            $name .= '-' . $namenw[int(rand(@namenw))];
         }
      }
   }

   my $drprofp = 0.1;

   if ($drprof) {
      $drprofp = 0.01;
   }


   if (rand(1) <= $drprofp) {
      $name .= ' ' . $adel[int(rand(@adel))];
   }

   $name .= ' ' . $namenn[int(rand(~~@namenn))];

   return $name;
}

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

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      #$target = $nick unless ($ischan);
      return unless ($ischan);

      # cmds
      if ($cmd eq 'NAME') {
         main::msg($target, getname());
      }
   }
}

1;
