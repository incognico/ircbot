package urban;

use utf8;
use strict;
use warnings;

my $mytrigger;

use JSON;
use LWP::Simple;
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

      $target = $nick unless $ischan;

      # cmds 
      if ($cmd =~ /UD?|URBAN|DEFINE|DICT/) {
         if ($args[0]) {
            my $query = uri_escape("@args");
            my $json  = get('http://api.urbandictionary.com/v0/define?term=' . $query);
            my $ud    = decode_json($json);

            unless ($ud) {
               main::err($target, 'api failure');
            }
            elsif (defined $$ud{list}[0]{definition}) {
               for (0..2) {
                  $$ud{list}[$_]{definition} =~ s/[\r\n]+/ /g;
                  $$ud{list}[$_]{definition} =~ s/\s+/ /g;

                  ::msg($target, '%d/%d %s :: %s', $_+1, $#{$$ud{list}}+1, $$ud{list}[$_]{word}, length($$ud{list}[$_]{definition}) > 199 ? substr($$ud{list}[$_]{definition}, 0, 200) . '...' : $$ud{list}[$_]{definition});

                  last unless (defined $$ud{list}[$_+1]{definition});
               }
            }
            else {
                main::msg($target, 'no match');
            }
         }
         else {
            main::hlp($target, 'syntax: U|UD|URBAN|DEFINE|DICT <term>');
         }
      }
   }
}

1;
