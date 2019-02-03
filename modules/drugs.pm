package drugs;

use utf8;
use strict;
use warnings;

my $mytrigger;

use JSON;
use LWP::UserAgent;
use URI::Escape;

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

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      #$target = $nick unless ($ischan);
      return unless ($ischan);

      # cmds 
      if ($cmd eq 'DRUG') {
         if ($args[0]) {
            printf("[%s] === modules::%s: Drugs [%s] on %s by %s\n", scalar localtime, __PACKAGE__, "@args", $target, $nick);

            my $query    = uri_escape("@args");
            my $ua       = LWP::UserAgent->new;
            my $response = $ua->get('http://tripbot.tripsit.me/api/tripsit/getDrug?name=' . $query);
            
            if ($response->is_success) {
               my $drg = decode_json($response->decoded_content);

               if (defined $$drg{data}[0]{properties}{summary}) {
                     main::msg($target, '%s', (length($$drg{data}[0]{properties}{summary}) > 399) ? substr($$drg{data}[0]{properties}{summary}, 0, 400) . '...' : $$drg{data}[0]{properties}{summary});

               }
               else {
                   main::msg($target, 'no match');
               }
            }
            else {
               main::err($target, 'api failure');
            }
         }
         else {
            main::hlp($target, 'syntax: DRUG <term>');
         }
      }
   }
}

1;
