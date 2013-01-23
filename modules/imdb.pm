package imdb;

use utf8;
use strict;
use warnings;

use IMDB::Film;

my $mytrigger;

### start config

my $cacheroot = '/tmp/imdb_cache';

### end config

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
      if ($cmd eq 'IMDB') {
         if ($args[0]) {
            printf("[%s] === modules::%s: IMDB [%s] on %s by %s\n", scalar localtime, __PACKAGE__, "@args", $target, $nick) unless main::israwlog();

            my $imdb;

            eval {
               $imdb = IMDB::Film->new(crit => "@args", search => 'find?s=tt&exact=false&q=', host => 'akas.imdb.com', cache => 1, cache_root => $cacheroot, cache_exp => '1 d');

               if ($imdb->status) {
                  my ($ratingorig, my $votesorig) = $imdb->rating;
                  my $rating = $ratingorig ? $ratingorig : '-';
                  my $votes = $votesorig ? $votesorig : '<10';
                  my $plot = $imdb->plot ? $imdb->plot : '-';
                  $plot =~ s/ See full summary.+//;
                  my $imdbres = $imdb->title . ' (' . $imdb->year . ')' . ' :: http://imdb.com/title/tt' . $imdb->id . ' :: Rating: ' . $rating . ' (' . $votes . ' votes) :: Plot: ' . $plot;

                  if (length($imdbres) > 385) {
                     main::msg($target, '%s...', substr($imdbres, 0, 384));
                  }
                  else {
                     main::msg($target, $imdbres);
                  }
               }
               else {
                  main::msg($target, 'no match');
               }
            };
         }
         else {
            main::err($target, 'syntax: IMDB <search string>');
         }
      }
   }
}

1;
