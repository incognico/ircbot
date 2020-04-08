package omdb;

use utf8;
use strict;
use warnings;

use JSON;
use LWP::UserAgent;
use URI::Escape;
use Encode;

my $mytrigger;

my $apikey = '';

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
      if ($cmd =~ /^([IO]MDB|FILM|FLICK|MOVIE|RT)$/) {
         if ($args[0]) {
            printf("[%s] === modules::%s: OMDB [%s] on %s by %s\n", scalar localtime, __PACKAGE__, "@args", $target, $nick);

            my $year;
            $year  = pop(@args) if ($args[-1] =~ /^\d{4}$/);
            my $title = uri_escape("@args");

            my $type = 't';
            $type = 'i' if ($title =~ /((?:tt)?\d{7,8})/);

            my $url = 'http://www.omdbapi.com/?apikey=' . $apikey;
            $url .= '&' . $type . '=' . $title;
            $url .= '&y=' . $year if ($year);

            my $ua = LWP::UserAgent->new;
            $ua->timeout(5);
            my $response = $ua->get($url);

            if ($response->is_success) {
               my $omdb = from_json ( Encode::decode_utf8( $response->decoded_content ) );

               if ($$omdb{Response} eq 'True') {
                  $$omdb{Plot} = substr($$omdb{Plot}, 0, 178) . '..' if (length($$omdb{Plot}) > 180);

                  #for (qw(imdbRating imdbVotes tomatoMeter tomatoRating tomatoFresh tomatoRotten tomatoUserRating tomatoUserReviews)) {
                  for (qw(imdbRating imdbVotes Metascore)) {
                     $$omdb{$_} = '?' if ($$omdb{$_} eq 'N/A');
                  }

                  main::msg($target, '%s (%s) :: https://imdb.com/title/%s :: %s :: Genre: %s :: %s, %s %s:: IMDb: %s/10 (%s votes)', $$omdb{Title}, $$omdb{Year}, $$omdb{imdbID}, $$omdb{Plot}, $$omdb{Genre}, $$omdb{Runtime}, $$omdb{Country}, $$omdb{Metascore} ne '?' ? sprintf(':: Metascore: %s/100 ', $$omdb{Metascore}) : '', $$omdb{imdbRating}, $$omdb{imdbVotes});
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
