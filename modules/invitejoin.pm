# TODO:
# - Save less :D
# - Make even more complicated

package invitejoin;
require modules::utils;

use utf8;
use strict;
use warnings;

# https://rt.cpan.org/Public/Bug/Display.html?id=54790
#use YAML::Tiny qw(LoadFile DumpFile);
use YAML qw(LoadFile DumpFile);

my $channels;
my $myprofile;
my $mytrigger;
my $public;

my $cfg;
my %invitechannels;

### start config ###

my $cfgname = "$ENV{HOME}/.bot/%s/%s.yml"; # package name, profile name

### end config ###

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $channels      = $self->{channels};
   $myprofile     = $self->{myprofile};
   $mytrigger     = $self->{mytrigger};
   $public        = $self->{public};

   $cfg = sprintf($cfgname, __PACKAGE__, $$myprofile);

   loadcfg() if -e $cfg;

   return $self;
}

sub autojoin {
   my $deleted = 0;

   for (keys(%{$invitechannels{joinlist}{$$myprofile}})) {
      unless (exists $invitechannels{blacklist}{$$myprofile}{$_} || exists $channels->{$$myprofile}{$_}) {
         utils->joinchan($_);
      }
      else {
         delete $invitechannels{joinlist}{$$myprofile}{$_};
         $deleted = 1;
      }
   }

   savecfg() if $deleted;
}

sub loadcfg {
   printf("[%s] === modules::%s: Loading config: %s\n", scalar localtime, __PACKAGE__, $cfg);

   %invitechannels = LoadFile($cfg);
}

sub savecfg {
   printf("[%s] === modules::%s: Saving config: %s\n", scalar localtime, __PACKAGE__, $cfg);

   DumpFile($cfg, %invitechannels);
}

### hooks

sub on_autojoin {
   autojoin();
}

sub on_invite {
   my ($self, $nick, $chan, $who) = @_;
   my $joined = 0;

   printf("[%s] *** Invited to %s by %s\n", scalar localtime, $chan, $nick);

   if (exists $channels->{$$myprofile}{$chan}) {
      utils->joinchan($chan);
   }
   elsif (main::isadmin($who)) {
      utils->joinchan($chan);
      $channels->{$$myprofile}{$chan} = '';
      $joined = 1;
   }
   elsif ($$public) {
      unless (exists $invitechannels{blacklist}{$$myprofile}{$chan}) {
         utils->joinchan($chan);
         $invitechannels{joinlist}{$$myprofile}{$chan} = $who;
         $joined = 1;
      }
   }

   savecfg() if $joined;
}

sub on_ownkick {
   my ($self, $chan) = @_;

   if (exists $invitechannels{joinlist}{$$myprofile}{$chan}) {
      delete $invitechannels{joinlist}{$$myprofile}{$chan};
      savecfg();
   }
}

sub on_ownquit {
   savecfg();
}

sub on_ownpart {
   my ($self, $chan) = @_;

   if (exists $invitechannels{joinlist}{$$myprofile}{$chan}) {
      delete $invitechannels{joinlist}{$$myprofile}{$chan};
      savecfg();
   }
}

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, $who) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my @cargs = map { uc } @args;
      my $cmd = substr(shift(@cargs), 1);
      shift(@args);

      # admin cmds
      return unless main::isadmin($who);

      $target = $nick unless $ischan;

      if ($cmd eq 'SET' || $cmd eq 'S') {
         my $syntax = 'syntax: SET PUBLIC [ON|OFF]';

         if ($args[0]) {
            if ($cargs[0] eq 'PUBLIC') {
               if ($args[1]) {
                  if ($cargs[1] eq 'ON') {
                     $$public = 1;
                     utils->ack($target);
                  }
                  elsif ($cargs[1] eq 'OFF') {
                     $$public = 0;
                     utils->ack($target);
                  }
               }
               elsif (!$args[1]) {
                  utils->msg($target, sprintf("PUBLIC: %s", $$public ? 'ON' : 'OFF'));
               }
               else {
                  utils->err($target, 'syntax: SET PUBLIC [ON|OFF]');
               }
            }
            elsif ($cargs[0] eq 'HELP') {
               utils->hlp($target, $syntax);
            }
         }
         else {
            utils->err($target, $syntax);
         }
      }
      elsif ($cmd eq 'LIST' || $cmd eq 'LS') {
         if ($args[0]) {
            if ($cargs[0] eq 'INVITECHANNELS' || $cargs[0] eq 'INVCHANS') {
               my $chans;
               my $count = 0;

               if ($args[1]) {
                  if ($cargs[1] eq 'VERBOSE' || $cargs[1] eq 'V') {
                     for (keys($invitechannels{joinlist}{$$myprofile})) {
                        $count++;
                        $chans .= sprintf("%s (%s)\n", $_, $invitechannels{joinlist}{$$myprofile}{$_});
                     }
                  }
               }
               elsif (!$args[1]) {
                  for (keys($invitechannels{joinlist}{$$myprofile})) {
                     $count++;
                     $chans .= sprintf("%s, ", $_);
                  }
               }
               else {
                  utils->err($target, 'syntax: LIST(LS) INVITECHANNELS(INVCHANS) [VERBOSE(V)]');
               }

               if ($chans) {
                  utils->msg($target, substr($chans, 0, -2));
                  utils->msg($target, sprintf('total: %s', $count));
               }
               else {
                  utils->msg($target, "no invite-channels joined");
               }
            }
            elsif ($cargs[0] eq 'HELP') {
               utils->hlp($target, 'syntax: LIST(LS) INVITECHANNELS(INVCHANS) [VERBOSE(V)]');
            }
         }
         else {
            utils->err($target, 'syntax: LIST(LS) INVITECHANNELS(INVCHANS) [VERBOSE(V)]');
         }
      }
      elsif ($cmd eq 'BLACKLIST' || $cmd eq 'BL') {
         my @syntax = ('syntax: BLACKLIST(BL) LIST(LS)', 'syntax: BLACKLIST(BL) ADD|DELETE(DEL)|CHECK(CHK) <channel> [,<channel>]...');

         if ($args[0]) {
            if ($cargs[0] eq 'ADD') {
               if ($args[1]) {
                  my $added = 0;

                  for (split(' ', utils->chantrim("@args[1..$#args]"))) {
                     if (main::ischan($_)) {
                        utils->partchan($_);
                        $invitechannels{blacklist}{$$myprofile}{$_}++;
                        delete $invitechannels{joinlist}{$$myprofile}{$_};
                        $added = 1;
                     }
                     else {
                        utils->err($target, sprintf("%s is not a valid channel", $_));
                     }
                  }

                  if ($added) {
                     savecfg();
                     utils->ack($target);
                  }
               }
               else {
                  utils->err($target, 'syntax: BLACKLIST(BL) ADD <channel> [,<channel>]...');
               }
            }
            elsif ($cargs[0] eq 'DELETE' || $cargs[0] eq 'DEL') {
               if ($args[1]) {
                  my $deleted = 0;

                  for (split(' ', utils->chantrim("@args[1..$#args]"))) {
                     if (main::ischan($_)) {
                        if (exists $invitechannels{blacklist}{$$myprofile}{$_}) {
                           delete $invitechannels{blacklist}{$$myprofile}{$_};
                           $deleted = 1;
                        }
                        else {
                           utils->err($target, sprintf("%s is not blacklisted", $_));
                        }
                     }
                     else {
                        utils->err($target, sprintf("%s is not a valid channel", $_));
                     }
                  }

                  if ($deleted) {
                     savecfg();
                     utils->ack($target);
                  }
               }
               else {
                  utils->err($target, 'syntax: BLACKLIST(BL) DELETE(DEL) <channel> [,<channel>]...');
               }
            }
            elsif ($cargs[0] eq 'CHECK' || $cargs[0] eq 'CHK') {
               if ($cargs[1]) {
                  my $blacklisted;

                  for (split(' ', utils->chantrim("@args[1..$#args]"))) {
                     $blacklisted .= sprintf("%s ,", $_) if exists $invitechannels{blacklist}{$$myprofile}{$_};
                  }

                  if ($blacklisted) {
                     utils->msg($target, sprintf("blacklisted: %s", substr($blacklisted, 0, -2)));
                  }
                  else {
                     utils->msg($target, "channel(s) not blacklisted");
                  }
               }
               else {
                  utils->err($target, 'syntax: BLACKLIST(BL) CHECK(CHK) <channel> [,<channel>]...');
               }
            }
            elsif ($cargs[0] eq 'HELP') {
               utils->hlp($target, $_) for (@syntax);
            }
         }
         elsif (!$args[0]) {
            utils->err($target, $_) for (@syntax);
         }
      }
   }
}

1;
