package cvoice;

use utf8;
use strict;
use warnings;

use threads;
use threads::shared;

my $mychannels;
my $myprofile;

my %captacha_keys :shared;
my %captacha_nicks :shared;

### start config

my $cvoicechannel = '';
my $cvoiceurl     = '';

### end config

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mychannels = $self->{mychannels};
   $myprofile  = $self->{myprofile};

   return $self;
}

sub voice1 {
   my $nick = shift;

#   unless (exists %{$mychannels->{$$myprofile}{$cvoicechannel}{$nick}}) {
#      main::ntc($nick, 'Join %s first.', $cvoicechannel);
#      return;
#   }

   unless (exists $captacha_nicks{$nick}) {
      my $key;
      my @x = (48..57, 65..90, 97..122);

      $key .= chr($x[rand($#x)]) for 1..10;
      $captacha_nicks{$nick} = $key;
      $captacha_keys{$key}   = $nick;
   }

   main::ntc($nick, 'IF YOU WANT TO TALK IN HERE USE %s?key=%s TO GET VOICE', $cvoiceurl, $captacha_nicks{$nick});
}

sub voice2 {
   my ($self, $valid, $key) = @_;

   return unless (exists $captacha_keys{$key});

   my $nick = $captacha_keys{$key};
   
#   unless (exists %{$mychannels->{$$myprofile}{$cvoicechannel}{$nick}}) {
#      main::ntc($nick, 'Join %s first.', $cvoicechannel);
#      return;
#    }

   if ($valid) {
      main::raw('MODE %s +v %s', $cvoicechannel, $nick);
      main::ntc($nick, 'Voiced. Please be polite and enjoy the chat!');

      delete $captacha_keys{$key};
      delete $captacha_nicks{$nick};

      printf("[%s] === modules::%s: Voiced [%s] on %s\n", scalar localtime, __PACKAGE__, $nick, $cvoicechannel);
   }
   else {
      main::kick($cvoicechannel, $nick, 'Wrong captcha. Try again.');
      #main::ntc($nick, 'Wrong captcha. Please try again: %s?key=%s', $cvoiceurl, $captacha_nicks{$nick});
   }
}

### hooks

sub on_join {
      my ($self, undef, $nick, undef, undef, undef) = @_;

      voice1($nick);
}

1;
