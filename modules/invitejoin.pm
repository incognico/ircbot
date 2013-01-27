package invitejoin;

use utf8;
use strict;
use warnings;

# https://rt.cpan.org/Public/Bug/Display.html?id=54790
#use YAML::Tiny qw(LoadFile DumpFile);
use YAML qw(LoadFile DumpFile);

my $channels;
my $mychannels;
my $myhelptext;
my $myprofile;
my $mytrigger;
my $public;

my $cfg;
my $changed = 0;
my $count = 0;
my %antiflood;
my %invitechannels;
my %recentkickchannels;

### start config

my $cfgname  = "$ENV{HOME}/.bot/%s/%s.yml"; # package name, profile name
my $minusers = 10;

### end config

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $channels   = $self->{channels};
   $mychannels = $self->{mychannels};
   $myhelptext = $self->{myhelptext};
   $myprofile  = $self->{myprofile};
   $mytrigger  = $self->{mytrigger};
   $public     = $self->{public};

   $cfg = sprintf($cfgname, __PACKAGE__, $$myprofile);

   loadcfg() if -e $cfg;

   return $self;
}

sub autojoin {
   for (keys(%{$invitechannels{joinlist}{$$myprofile}})) {
      unless (exists $invitechannels{blacklist}{$$myprofile}{$_} || exists $channels->{$$myprofile}{$_}) {
         main::joinchan($_);
      }
      else {
         delete $invitechannels{joinlist}{$$myprofile}{$_};
         $changed = 1;
      }
   }
}

sub checksize {
   my $chan = shift || return;

   if (exists $invitechannels{joinlist}{$$myprofile}{$chan} && exists $mychannels->{$$myprofile}{$chan}) {
      if (scalar keys %{$mychannels->{$$myprofile}{$chan}} < $minusers) {
         printf("[%s] === modules::%s: Channel [%s] does not qualify\n", scalar localtime, __PACKAGE__, $chan);
         main::partchan($chan, 'channel does not qualify');
         $recentkickchannels{$$myprofile}{$chan} = 'myself (channel does not qualify)';
         delete $invitechannels{joinlist}{$$myprofile}{$chan};
         $changed = 1;
      }
   }
}

sub loadcfg {
   printf("[%s] === modules::%s: Loading config: %s\n", scalar localtime, __PACKAGE__, $cfg);
   %invitechannels = LoadFile($cfg);
}

sub savecfg {
   if ($changed) {
      printf("[%s] === modules::%s: Saving config: %s\n", scalar localtime, __PACKAGE__, $cfg);
      DumpFile($cfg, %invitechannels);
      $changed = 0;
   }
}

### hooks

sub on_autojoin {
   autojoin();
}

sub on_invite {
   my ($self, $nick, $chan, $who) = @_;

   printf("[%s] *** Invited to %s by %s\n", scalar localtime, $chan, $nick);
   
   if (main::isadmin($who)) {
      main::joinchan($chan);
      $channels->{$$myprofile}{$chan} = '';
   }
   elsif ($$public) {
      unless (exists $channels->{$$myprofile}{$chan}) {
         unless (exists $invitechannels{blacklist}{$$myprofile}{$chan}) {
            unless (exists $recentkickchannels{$$myprofile}{$chan}) {
               main::joinchan($chan);

               if ($$myhelptext) {
                  main::msg($chan, q{Hello there! I was invited by %s. My trigger is '%s', more info is available by using '%shelp'. Most commands work in private too.}, $nick, $$mytrigger, $$mytrigger);
               }
               else {
                  main::msg($chan, 'Hello there! I was invited by %s.', $nick);
               }

               $invitechannels{joinlist}{$$myprofile}{$chan} = $who;
               $changed = 1;
            }
            else {
               unless (exists $antiflood{$$myprofile}{$nick}) {
                  main::ntc($nick, 'I was just removed from %s by %s, please try again later.', $chan, $recentkickchannels{$$myprofile}{$chan});
                  $antiflood{$$myprofile}{$nick}++;
               }
               else {
                  return;
               }
            }
         }
         else {
            unless (exists $antiflood{$$myprofile}{$nick}) {
               main::ntc($nick, '%s is blacklisted.', $chan);
               $antiflood{$$myprofile}{$nick}++;
            }
            else {
               return;
            }
         }
      }
      else {
         main::joinchan($chan);
      }
   }
}

sub on_ownkick {
   my ($self, $chan, $nick) = @_;

   if (exists $invitechannels{joinlist}{$$myprofile}{$chan}) {
      delete $invitechannels{joinlist}{$$myprofile}{$chan};
      $recentkickchannels{$$myprofile}{$chan} = $nick;
      $changed = 1;
   }
}

sub on_ownquit {
   savecfg();
}

sub on_ownpart {
   my ($self, $chan) = @_;

   if (exists $invitechannels{joinlist}{$$myprofile}{$chan}) {
      delete $invitechannels{joinlist}{$$myprofile}{$chan};
      $changed = 1;
   }
}

sub on_ping {
   delete $antiflood{$$myprofile};

   if ($count >= 10) {
      $count = 0;
      delete $recentkickchannels{$$myprofile};

      for (keys(%{$invitechannels{joinlist}{$$myprofile}})) {
         checksize($_);
      }
   }
   else {
      $count++;
   }

   savecfg();
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

      if ($cmd eq 'SET') {
         my $syntax = 'syntax: SET PUBLIC [ON|OFF]';

         if ($args[0]) {
            if ($cargs[0] eq 'PUBLIC') {
               if ($args[1]) {
                  if ($cargs[1] eq 'ON') {
                     $$public = 1;
                     main::ack($target);
                  }
                  elsif ($cargs[1] eq 'OFF') {
                     $$public = 0;
                     main::ack($target);
                  }
               }
               elsif (!$args[1]) {
                  main::msg($target, 'PUBLIC: %s', $$public ? 'ON' : 'OFF');
               }
               else {
                  main::hlp($target, 'syntax: SET PUBLIC [ON|OFF]');
               }
            }
            elsif ($cargs[0] eq 'HELP') {
               main::hlp($target, $syntax);
            }
         }
         else {
            main::hlp($target, $syntax);
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
                        main::msg($target, '%s - %u - %s', $_, scalar keys %{$mychannels->{$$myprofile}{$_}}, $invitechannels{joinlist}{$$myprofile}{$_});
                     }
                  }
               }
               elsif (!$args[1]) {
                  for (keys($invitechannels{joinlist}{$$myprofile})) {
                     $count++;
                     $chans .= sprintf("%s, ", $_);
                  }

                  if ($count > 0) {
                     main::msg($target, substr($chans, 0, -2));
                  }
               }
               else {
                  main::hlp($target, 'syntax: LIST(LS) INVITECHANNELS(INVCHANS) [VERBOSE(V)]');
               }

               if ($count > 0) {
                  main::msg($target, 'total: %s', $count);
               }
               else {
                  main::msg($target, "no invite-channels joined");
               }
            }
            elsif ($cargs[0] eq 'HELP') {
               main::hlp($target, 'syntax: LIST(LS) INVITECHANNELS(INVCHANS) [VERBOSE(V)]');
            }
         }
         else {
            main::hlp($target, 'syntax: LIST(LS) INVITECHANNELS(INVCHANS) [VERBOSE(V)]');
         }
      }
      elsif ($cmd eq 'BLACKLIST' || $cmd eq 'BL') {
         my @syntax = ('syntax: BLACKLIST(BL) LIST(LS)', 'syntax: BLACKLIST(BL) ADD|DELETE(DEL)|CHECK(CHK) <channel> [,<channel>]...');

         if ($args[0]) {
            if ($cargs[0] eq 'LIST' || $cargs[0] eq 'LS') {
               my $chans;
               my $count = 0;

               for (keys($invitechannels{blacklist}{$$myprofile})) {
                  $count++;
                  $chans .= sprintf("%s, ", $_);
               }

               if ($chans) {
                  main::msg($target, substr($chans, 0, -2));
                  main::msg($target, 'total: %s', $count);
               }
               else {
                  main::msg($target, "no channels blacklisted");
               }
            }
            elsif ($cargs[0] eq 'ADD') {
               if ($args[1]) {
                  my $added = 0;

                  for (split(' ', main::chantrim("@args[1..$#args]"))) {
                     if (main::ischan($_)) {
                        main::partchan($_);
                        $invitechannels{blacklist}{$$myprofile}{$_}++;
                        delete $invitechannels{joinlist}{$$myprofile}{$_};
                        $added = 1;
                     }
                     else {
                        main::err($target, '%s is not a valid channel', $_);
                     }
                  }

                  if ($added) {
                     $changed = 1;
                     main::ack($target);
                  }
               }
               else {
                  main::hlp($target, 'syntax: BLACKLIST(BL) ADD <channel> [,<channel>]...');
               }
            }
            elsif ($cargs[0] eq 'DELETE' || $cargs[0] eq 'DEL') {
               if ($args[1]) {
                  my $deleted = 0;

                  for (split(' ', main::chantrim("@args[1..$#args]"))) {
                     if (main::ischan($_)) {
                        if (exists $invitechannels{blacklist}{$$myprofile}{$_}) {
                           delete $invitechannels{blacklist}{$$myprofile}{$_};
                           $deleted = 1;
                        }
                        else {
                           main::err($target, '%s is not blacklisted', $_);
                        }
                     }
                     else {
                        main::err($target, '%s is not a valid channel', $_);
                     }
                  }

                  if ($deleted) {
                     $changed = 1;
                     main::ack($target);
                  }
               }
               else {
                  main::hlp($target, 'syntax: BLACKLIST(BL) DELETE(DEL) <channel> [,<channel>]...');
               }
            }
            elsif ($cargs[0] eq 'CHECK' || $cargs[0] eq 'CHK') {
               if ($cargs[1]) {
                  my $blacklisted;

                  for (split(' ', main::chantrim("@args[1..$#args]"))) {
                     $blacklisted .= sprintf("%s ,", $_) if exists $invitechannels{blacklist}{$$myprofile}{$_};
                  }

                  if ($blacklisted) {
                     main::msg($target, 'blacklisted: %s', substr($blacklisted, 0, -2));
                  }
                  else {
                     main::msg($target, "channel(s) not blacklisted");
                  }
               }
               else {
                  main::hlp($target, 'syntax: BLACKLIST(BL) CHECK(CHK) <channel> [,<channel>]...');
               }
            }
            elsif ($cargs[0] eq 'HELP') {
               main::hlp($target, $_) for (@syntax);
            }
         }
         elsif (!$args[0]) {
            main::hlp($target, $_) for (@syntax);
         }
      }
   }
}

sub on_synced {
   my ($self, $chan) = @_;

   checksize($chan);
}

sub on_unload {
   savecfg();
}

1;
