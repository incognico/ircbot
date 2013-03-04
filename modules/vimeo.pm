package vimeo;

use utf8;
use strict;
use warnings;

use JSON;
use LWP::UserAgent;
use Number::Format ':subs';

my $myprofile;

### functions

sub duration {
   my $sec = shift;

   return '?' unless ($sec);

   my @gmt = gmtime($sec);

   return ($gmt[7] ?  $gmt[7]                                          .'d' : '').
          ($gmt[2] ? ($gmt[7]                       ? ' ' : '').$gmt[2].'h' : '').
          ($gmt[1] ? ($gmt[7] || $gmt[2]            ? ' ' : '').$gmt[1].'m' : '').                                                                        ($gmt[0] ? ($gmt[7] || $gmt[2] || $gmt[1] ? ' ' : '').$gmt[0].'s' : '');
}

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $myprofile = $self->{myprofile};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   return unless ($ischan);

   if ($msg =~ m!vimeo\.com/([0-9]{1,10})!) {
      printf("[%s] === modules::%s: Vimeo video posted [%s] on %s by %s\n", scalar localtime, __PACKAGE__, $1, $target, $nick);

      my $id       = $1;
      my $ua       = LWP::UserAgent->new;
      my $response = $ua->get("http://vimeo.com/api/v2/video/$id.json");

      if ($response->is_success) {
         my $vimeo = decode_json($response->decoded_content);

         if (@$vimeo[0]->{id} == $id) {
            main::msg($target, 'Title: %s :: Duration: %s :: Views: %s :: Likes: %s', @$vimeo[0]->{title}, duration(@$vimeo[0]->{duration}), format_number(@$vimeo[0]->{stats_number_of_plays}), format_number(@$vimeo[0]->{stats_number_of_likes}));
         }
      }
   }
}

1;
