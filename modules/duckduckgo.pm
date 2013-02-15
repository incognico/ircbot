package duckduckgo;

use utf8;
use strict;
use warnings;

use feature 'switch';

my $mytrigger;

use Encode;
use HTML::Entities;
use JSON;
use LWP::UserAgent;
use URI::Escape;
use WWW::Shorten 'TinyURL';

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mytrigger = $self->{mytrigger};

   return $self;
}

sub shorten {
   my $url = shift;

   if ($url && length($url) > 100) {
      my $short;
      eval { $short = makeashorterlink($url) };
      
      $url = $short if ($short && $short =~ /^http/);
   }

   return $url;
}

sub trunc {
   my $var = shift;

   $var = substr($var, 0, 333) . '...' if (length($var) > 333);

   return $var;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      $target = $nick unless ($ischan);

      # cmds 
      if ($cmd eq 'DDG' || $cmd eq 'D') {
         if ($args[0]) {
            printf("[%s] === modules::%s: DDG [%s] on %s by %s\n", scalar localtime, __PACKAGE__, "@args", $target, $nick);

            my $query    = uri_escape("@args");
            my $ua       = LWP::UserAgent->new;
            my $response = $ua->get('http://api.duckduckgo.com/?format=json&no_html=1&no_redirect=1&kp=-1&q=' . $query);

            if ($response->is_success) {
               my $ddg = decode_json($response->decoded_content);  
               my $ans = $$ddg{Answer};
               my $def = $$ddg{Definition};
               my $rdr = decode('UTF-8', uri_unescape($$ddg{Redirect}));
               my $src = $$ddg{AbstractSource};
               my $tpe = $$ddg{Type};
               my $txt = decode_entities($$ddg{AbstractText});
               my $url = decode('UTF-8', uri_unescape($$ddg{AbstractURL}));

               map { s/<[^>]*>//g; s/\s+/ /g; s/%/%%/g } ($ans, $def, $txt);
               $_ = shorten($_) for ($rdr, $url);
               $_ = trunc($_)   for ($ans, $def, $txt);

               given ($tpe) {
                  when ('A') {
                     main::msg($target, '%s :: %s', $url, $txt);
                  }
                  when ('D') {
                     if ($def) {
                        main::msg($target, '%s (%s: %s)', $def, $src, $url);
                     }
                     else {
                        main::msg($target, '%s: %s', $src, $url);
                     }
                  }
                  default {
                     if ($ans) {
                        main::msg($target, $ans);
                     }
                     elsif ($rdr) {
                        if ($rdr eq '/bang.html') {
                           main::msg($target, '!bang: https://duckduckgo.com/bang.html');
                        }
                        else {
                           main::msg($target, '!bang: %s', $rdr);
                        }
                     }
                     else {
                        main::msg($target, 'no result');
                     }
                  }
               }
            }
            else {
               main::err($target, 'api error');
            }
         }
         else {
            main::hlp($target, 'syntax: DDG|D <query>');
         }
      }
   }
}

1;
