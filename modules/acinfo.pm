package acinfo;

use utf8;
use strict;
use warnings;

use LWP::UserAgent;
use XML::Simple ':strict';

my $mytrigger;

my @online;
my @failed;

### start config

my %streams = (
   Herp => {
      host => '',
      port => '',
      user => '',
      pass => '',
   },
   Derp => {
      host => '',
      port => '',
      user => '',
      pass => '',
   },
);

### end config

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mytrigger = $self->{mytrigger};

   return $self;
}

sub fetchinfo {
   foreach (keys %streams) {
      my $url = "http://$streams{$_}{host}:$streams{$_}{port}/admin.cgi?mode=viewxml&amp;page=1&amp;sid=1";

      my $ua = LWP::UserAgent->new;
      $ua->credentials($streams{$_}{host} . ':' . $streams{$_}{port}, 'Shoutcast Server', $streams{$_}{user}, $streams{$_}{pass});
      $ua->agent('Mozilla, Stream Info Bot');
      $ua->timeout(8);

      my $response = $ua->get($url);

      if ($response->is_success) {
         my $xml = XML::Simple->new();
         $streams{$_}{data} = $xml->XMLin($response->decoded_content, KeyAttr => 'SHOUTCASTSERVER', ForceArray => 0);
         push(@online, $_) if ($streams{$_}{data}{STREAMSTATUS});
      }
      else {
         push(@failed, $_);
      }
   }
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      #$target = $nick unless ($ischan);
      return unless ($ischan && $target eq '#awesomecougars');

      # cmds
      if ($cmd eq 'AC') {
         fetchinfo();

         if (@online) {
            foreach (@online) {
               main::msg($target, "%s: %s | Track: %s | Fags: %s/%s | Peak: %s", $_, $streams{$_}{data}{SERVERTITLE}, $streams{$_}{data}{SONGTITLE}, $streams{$_}{data}{CURRENTLISTENERS}, $streams{$_}{data}{MAXLISTENERS}, $streams{$_}{data}{PEAKLISTENERS});
            }
         }
         else {
            main::msg($target, 'All streams are offline. Go to http://awesomecougars.co/ and start streaming.');
         }

         if (@failed) {
            main::msg($target, 'Failed to get info for stream(s): %s', "@failed");
         }
      }
   }
}

1;
