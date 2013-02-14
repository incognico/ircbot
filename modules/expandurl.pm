package expandurl;

use utf8;
use strict;
use warnings;

use JSON;
use LWP::UserAgent;
use URI::Escape;

my $mytrigger;

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mytrigger = $self->{mytrigger};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   $target = $nick unless ($ischan);

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      # cmds 
      if ($cmd eq 'EXPAND') {
         if ($args[0]) {
            unless ("@args" =~ m!^https?://!) {
               main::msg($target, 'invalid url');
            }
            else {
               printf("[%s] === modules::%s: Expand [%s] on %s by %s\n", scalar localtime, __PACKAGE__, "@args", $target, $nick);

               my $query    = uri_escape("@args");
               my $ua       = LWP::UserAgent->new(agent => 'bot.pl-expand.pm/1');
               my $response = $ua->get('http://api.longurl.org/v2/expand?format=json&url=' . $query);

               if ($response->code == 200) {
                  my $expand = decode_json($response->decoded_content);

                  if (uri_escape($$expand{'long-url'}) eq $query) {
                     main::msg($target, 'invalid url');
                  }
                  else {
                     main::msg($target, $$expand{'long-url'});
                  }
               }
               elsif ($response->code == 400) {
                  main::msg($target, 'invalid url');
               }
               else {
                  main::msg($target, 'api failure');
               }
            }
         }
         else {
            main::hlp($target, 'syntax: EXPAND <short url>');
         }
      }
   }
}

1;
