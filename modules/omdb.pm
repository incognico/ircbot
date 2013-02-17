package omdb;

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

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));
      
      $target = $nick unless ($ischan);

      # cmds
      if ($cmd =~ /^([IO]MDB|FILM|FLICK|MOVIE|RT)$/) {
         if ($args[0]) {
            printf("[%s] === modules::%s: OMDB [%s] on %s by %s\n", scalar localtime, __PACKAGE__, "@args", $target, $nick);

            my $year  = pop(@args) if ($args[$#args] =~ /^\d{4}$/);
            my $title = uri_escape("@args");

            my $type = 't';
            $type = 'i' if ($title =~ /((?:tt)?\d{7})/);

            my $url = 'http://www.omdbapi.com/?tomatoes=true';
            $url .= '&' . $type . '=' . $title;
            $url .= '&y=' . $year if ($year);

            my $ua       = LWP::UserAgent->new;
            my $response = $ua->get($url);

            if ($response->is_success) {
               my $omdb = decode_json($response->decoded_content);

               if ($$omdb{Response} eq 'True') {
                  $$omdb{Plot} = substr($$omdb{Plot}, 0, 148) . '...' if (length($$omdb{Plot}) > 150);

                  for (qw(imdbRating imdbVotes tomatoMeter tomatoRating tomatoFresh tomatoRotten tomatoUserRating tomatoUserReviews)) {
                     $$omdb{$_} = '?' if ($$omdb{$_} eq 'N/A');
                  }

                  main::msg($target, '%s (%s) :: http://imdb.com/title/%s :: Plot: %s :: Genre: %s :: IMDB: %s/10 (%s) RT: %s%%, %s/10 (+%s/-%s) User: %s/5 (%s)', $$omdb{Title}, $$omdb{Year}, $$omdb{imdbID}, $$omdb{Plot}, $$omdb{Genre}, $$omdb{imdbRating}, $$omdb{imdbVotes}, $$omdb{tomatoMeter}, $$omdb{tomatoRating}, $$omdb{tomatoFresh}, $$omdb{tomatoRotten}, $$omdb{tomatoUserRating}, $$omdb{tomatoUserReviews});
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
            main::hlp($target, 'syntax: OMDB(IMDB|FILM|FLICK|MOVIE|RT) <title> [year]');
         }
      }
   }
}

1;
