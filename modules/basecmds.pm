package basecmds;

use utf8;
use strict;
use warnings;

use Data::Dumper;

my $channels;
my $logtodb;
my $myadmins;
my $mychannels;
my $myhelptext;
my $mynick;
my $myprofile;
my $mytrigger;
my $public;
my $rawlog;
my $silent;

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $channels   = $self->{channels};
   $logtodb    = $self->{logtodb};
   $myadmins   = $self->{myadmins};
   $mychannels = $self->{mychannels};
   $myhelptext = $self->{myhelptext};
   $myprofile  = $self->{myprofile};
   $mytrigger  = $self->{mytrigger};
   $mynick     = $self->{mynick};
   $public     = $self->{public};
   $rawlog     = $self->{rawlog};
   $silent     = $self->{silent};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, $who) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my @cargs = map { uc } @args;
      my $cmd = substr(shift(@cargs), 1);
      shift(@args);

      $target = $nick unless ($ischan);

      # cmds
      if ($cmd eq 'HELP') {
         main::msg($target, $$myhelptext) if ($$myhelptext);
      }

      # admin cmds
      return unless main::isadmin($who);

      if ($cmd eq 'SET') {
         my $syntax = 'syntax: SET RAWLOG|SILENT [ON|OFF]';

         if ($args[0]) {
            if ($cargs[0] eq 'RAWLOG') {
               if ($args[1]) {
                  if ($cargs[1] eq 'ON') {
                     $$rawlog = 1;
                     main::ack($target);
                  }
                  elsif ($cargs[1] eq 'OFF') {
                     $$rawlog = 0;
                     main::ack($target);
                  }
               }
               elsif (!$args[1]) {
                  main::msg($target, 'RAWLOG: %s', $$rawlog ? 'ON' : 'OFF');
               }
               else {
                  main::hlp($target, 'syntax: SET RAWLOG [ON|OFF]');
               }
            }
            elsif ($cargs[0] eq 'SILENT') {
               if ($args[1]) {
                  if ($cargs[1] eq 'ON') {
                     $$silent = 1;
                     main::ack($target);
                  }
                  elsif ($cargs[1] eq 'OFF') {
                     $$silent = 0;
                     main::ack($target);
                  }
               }
               elsif (!$args[1]) {
                  main::msg($target, 'SILENT: %s', $$silent ? 'ON' : 'OFF');
               }
               else {
                  main::hlp($target, 'syntax: SET SILENT [ON|OFF]');
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
      elsif ($cmd eq 'RAW') {
         if ($args[0]) {
            main::raw("%s", "@args");
            main::ack($target);
         }
         else {
            main::hlp($target, 'syntax: RAW <input>');
         }
      }
      elsif ($cmd eq 'EVAL') {
         if ($args[0]) {
            eval("@args");
            main::msg($target, $@) if ($@);
         }
         else {
            main::hlp($target, 'syntax: EVAL <perl code>');
         }
      }
      elsif ($cmd eq 'SHELL') {
         if ($args[0]) {
            for (`@args 2>&1`) {
               $_ =~ s/\t/ /g;
               $_ =~ s/_\x8//g;
               main::msg($target, $_);
            }

            if ($? == -1 ) {
               main::err($target, 'command not found');
            }
            elsif ($? >> 8 != 0) {
               main::err($target, 'returned: %d', $? >> 8);
            }
         }
         else {
            main::hlp($target, 'syntax: SHELL <command>');
         }
      }
      elsif ($cmd eq 'JOIN') {
         if ($args[0]) {
            my $joined = 0;

            for (split(' ', main::chantrim("@args"))) {
               if (main::ischan($_)) {
                  main::joinchan($_);
                  $channels->{$$myprofile}{$_} = '';
                  $joined = 1;
               }
               else {
                  main::err($target, '%s is not a valid channel', $_);
               }
            }

            main::ack($target) if ($joined);
         }
         else {
            main::hlp($target, 'syntax: JOIN <channel> [,<channel>]...');
         }
      }
      elsif ($cmd eq 'PART') {
         if ($args[0]) {
            my $parted = 0;

            for (split(' ', main::chantrim("@args"))) {
               if (main::ischan($_)) {
                  main::partchan($_);
                  delete $channels->{$$myprofile}{$_};
                  $parted = 1;
               }
               else {
                  main::err($target, '%s is not a valid channel', $_);
               }
            }

            main::ack($target) if ($parted);
         }
         else {
            if (main::ischan($target)) {
               main::partchan($target);
            }
            else {
               main::hlp($target, 'syntax: PART <channel> [,<channel>]...');
            }
         }
      }
      elsif ($cmd eq 'LIST' || $cmd eq 'LS') {
         if ($args[0]) {
            if ($cargs[0] eq 'CHANNELS' || $cargs[0] eq 'CHANS') {
               my $chans;
               my $count = 0;

               for (sort(keys(%{$mychannels->{$$myprofile}}))) {
                  $count++;
                  $chans .= $_ . ', ';
               }

               if ($count > 0) {
                  main::msg($target, substr($chans, 0, -2));
                  main::msg($target, 'total: %s', $count);
               }
               else {
                  main::msg($target, 'no channels joined');
               }
            }
            elsif ($cargs[0] eq 'NAMES') {
               if ($args[1]) {
                  if (main::ischan($args[1])) {
                     if (exists $mychannels->{$$myprofile}{$args[1]}) {
                        my $names;
                        my $count = 0;

                        for (sort {lc $a cmp lc $b} (keys(%{$mychannels->{$$myprofile}{$args[1]}}))) {
                           $count++;
                           $names .= $_ . ', ';
                        }

                        if ($count > 0) {
                           main::msg($target, substr($names, 0, -2));
                           main::msg($target, 'total: %s', $count);
                        }
                     }
                     else {
                        main::msg($target, 'not on %s', $args[1]);
                     }
                  }
                  else {
                     main::msg($target, '%s is not a valid channel', $args[1]);
                  }
               }
               else {
                  main::hlp($target, 'syntax: LIST(LS) NAMES <channel>');
               }
            }
            elsif (!$args[0]){
               main::hlp($target, 'syntax: LIST(LS) CHANNELS(CHANS) | LIST(LS) NAMES <channel>');
            }
         }
         else {
            main::hlp($target, 'syntax: LIST(LS) CHANNELS(CHANS) | LIST(LS) NAMES <channel>');
         }
      }
      elsif ($cmd eq 'USERINFO' || $cmd eq 'UI') {
         if ($args[0]) {
            my $count = 0;
            my $userchans;

            for my $chans (keys(%{$mychannels->{$$myprofile}})) {
               for (keys(%{$mychannels->{$$myprofile}{$chans}})) {
                  if (lc($_) eq lc($args[0])) {
                     $userchans .= $chans . ', ';
                     $count++;
                  }
               }
            }

            if ($count > 0) {
               main::msg($target, '%s is in %d common channel(s): %s', $args[0], $count, substr($userchans, 0, -2));
            }
            else {
               main::msg($target, 'no result');
            }
         }
      }
      elsif ($cmd eq 'MSG') {
         if ($args[1]) {
            main::msg($args[0], join(' ', @args[1..$#args]));
            main::ack($target) unless ($args[0] eq $target);
         }
         else {
            main::hlp($target, 'syntax: MSG <target> <text>');
         }
      }
      elsif ($cmd eq 'ACT') {
         if ($args[1]) {
            main::act($args[0], join(' ', @args[1..$#args]));
            main::ack($target) unless ($args[0] eq $target);
         }
         else {
            main::hlp($target, 'syntax: ACT <target> <text>');
         }
      }
      elsif ($cmd eq 'NTC') {
         if ($args[1]) {
            main::ntc($args[0], join(' ', @args[1..$#args]));
            main::ack($target) unless ($args[0] eq $target);
         }
         else {
            main::hlp($target, 'syntax: NTC <target> <text>');
         }
      }
      elsif ($cmd eq 'ACK') {
         main::ack($target);
      }
   }
}

1;
