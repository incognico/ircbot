package urban;

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

      $target = $nick unless ($ischan);

      # cmds 
      if ($cmd eq 'URBAN' || $cmd eq 'UD' || $cmd eq 'U') {
         if ($args[0]) {
            printf("[%s] === modules::%s: Urban [%s] on %s by %s\n", scalar localtime, __PACKAGE__, "@args", $target, $nick);

            my $query    = uri_escape("@args");
            my $ua       = LWP::UserAgent->new;
            my $response = $ua->get('http://api.urbandictionary.com/v0/define?term=' . $query);
            
            if ($response->is_success) {
               my $ud = decode_json($response->decoded_content);

               if (defined $$ud{list}[0]{definition}) {
                  for (0..2) {
                     $$ud{list}[$_]{definition} =~ s/\s+/ /g;

                     main::msg($target, '%d/%d %s:: %s', $_+1, $#{$$ud{list}}+1, (lc($$ud{list}[$_]{word}) ne lc("@args")) ? $$ud{list}[$_]{word} . ' ' : '', (length($$ud{list}[$_]{definition}) > 199) ? substr($$ud{list}[$_]{definition}, 0, 200) . '...' : $$ud{list}[$_]{definition});

                     last unless (defined $$ud{list}[$_+1]{definition});
                  }
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
            main::hlp($target, 'syntax: URBAN|UD|U <term>');
         }
      }
   }
}

1;
