package xonstat;

use utf8;
use strict;
use warnings;

use JSON 'decode_json';
use LWP::Simple;
use YAML::Tiny qw(LoadFile DumpFile);

my $myprofile;
my $mytrigger;

my $cfg;
my $changed;
my %idmap;

### start config

my $cfgname = "$ENV{HOME}/.bot/%s/%s.yml"; # package name, profile name
my $staturl = 'http://stats.xonotic.org/player/';

### end config

### functions

sub loadcfg {
   printf("[%s] === modules::%s: Loading config: %s\n", scalar localtime, __PACKAGE__, $cfg);
   %idmap = LoadFile($cfg);
}

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $myprofile = $self->{myprofile};
   $mytrigger = $self->{mytrigger};

   $cfg = sprintf($cfgname, __PACKAGE__, $$myprofile);

   loadcfg() if (-e $cfg);

   return $self;
}

sub savecfg {
   if ($changed) {
      printf("[%s] === modules::%s: Saving config: %s\n", scalar localtime, __PACKAGE__, $cfg);
      DumpFile($cfg, %idmap);
      $changed = 0;
   }
}

### hooks

sub on_ownquit {
   savecfg();
}

sub on_ping {
   savecfg();
}

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      #$target = $nick unless ($ischan);
      return unless ($ischan);

      # cmds 
      if ($cmd eq 'XONSTAT' || $cmd eq 'XS') {
         my ($qid, $stats);

         unless ($args[0]) {
            if (exists $idmap{$nick}) {
               $qid = $idmap{$nick}{id};
            }
            else {
               main::msg($target, q{you have not queried an id yet, please specify one (%sxs <player id>) and I'll remember it.}, $$mytrigger);
               return;
            }
         }
         else {
            ($qid = $args[0]) =~ s/[^0-9]//g;

            unless ($qid) {
               main::msg($target, 'invalid player id');
               return;
            }
         }

         my $json = get($staturl . $qid . '.json');

         if ($json) {
            eval { $stats = decode_json($json) };
         }
         else {
            main::msg($target, 'no response from server');
            return
         }

         $idmap{$nick}{id} = $qid;
         $changed = 1;

         printf("[%s] === modules::%s: xonstat [%d] on %s by %s\n", scalar localtime, __PACKAGE__, $qid, $target, $nick);

         my $snick   = $stats->[0]->{player}->{stripped_nick};
         my $games   = $stats->[0]->{games_played}->{overall}->{games};
         my $win     = $stats->[0]->{games_played}->{overall}->{wins};
         my $loss    = $stats->[0]->{games_played}->{overall}->{losses};
         my $pct     = $stats->[0]->{games_played}->{overall}->{win_pct};
         my $kills   = $stats->[0]->{overall_stats}->{overall}->{total_kills};
         my $deaths  = $stats->[0]->{overall_stats}->{overall}->{total_deaths};
         my $ratio   = $stats->[0]->{overall_stats}->{overall}->{k_d_ratio};
         my $elo     = $stats->[0]->{elos}->{overall}->{elo} ? $stats->[0]->{elos}->{overall}->{elo}          : 0;
         my $elot    = $stats->[0]->{elos}->{overall}->{elo} ? $stats->[0]->{elos}->{overall}->{game_type_cd} : 0;
         my $elog    = $stats->[0]->{elos}->{overall}->{elo} ? $stats->[0]->{elos}->{overall}->{games}        : 0;
         my $capr    = $stats->[0]->{overall_stats}->{ctf}->{cap_ratio} ? $stats->[0]->{overall_stats}->{ctf}->{cap_ratio} : 0;
         my $favmap  = $stats->[0]->{fav_maps}->{overall}->{map_name};
         my $favmapt = $stats->[0]->{fav_maps}->{overall}->{game_type_cd};
        (my $last    = $stats->[0]->{overall_stats}->{overall}->{last_played_fuzzy}) =~ s/about /~/;

         main::msg($target, "%s :: games: %d/%d/%d (%.2f%% win) :: k/d: %.2f (%d/%d)%s :: fav map: %s (%s) :: last played %s", $snick, $games, $win, $loss, $pct, $ratio, $kills, $deaths, ($elo && $elo ne 100) ? sprintf(' :: %s elo: %.2f (%d games%s)', $elot, $elo, $elog, $elot eq 'ctf' ? sprintf(', %.2f cr', $capr) : '' ) : '', $favmap, $favmapt, $last);
      }
   }
}

sub on_unload {
   savecfg();
}

1;
