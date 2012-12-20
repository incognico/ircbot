package basecmds;
require modules::utils;

use Data::Dumper;

use utf8;
use strict;
use warnings;

my $channels;
my $logtodb;
my $myadmins;
my $mychannels;
my $myhelptext;
my $mynick;
my $myprofile;
my $mytrigger;
my $rawlog;
my $silent;

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $channels      = $self->{channels};
   $logtodb       = $self->{logtodb};
   $myadmins      = $self->{myadmins};
   $mychannels    = $self->{mychannels};
   $myhelptext    = $self->{myhelptext};
   $myprofile     = $self->{myprofile};
   $mytrigger     = $self->{mytrigger};
   $mynick        = $self->{mynick};
   $rawlog        = $self->{rawlog};
   $silent        = $self->{silent};

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

      $target = $nick unless $ischan;

      # cmds
      if ($cmd eq 'HELP') {
         utils->msg($target, $$myhelptext) if $$myhelptext;
      }
      elsif ($cmd eq 'SPAST') {
         if ($args[0]) {
            utils->msg($target, 'http://spa.st/%s', $args[0]);
         }
         else {
            utils->msg($target, 'http://spa.st/%s', $nick);
         }
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
                     utils->ack($target);
                  }
                  elsif ($cargs[1] eq 'OFF') {
                     $$rawlog = 0;
                     utils->ack($target);
                  }
               }
               elsif (!$args[1]) {
                  utils->msg($target, 'RAWLOG: %s', $$rawlog ? 'ON' : 'OFF');
               }
               else {
                  utils->err($target, 'syntax: SET RAWLOG [ON|OFF]');
               }
            }
            elsif ($cargs[0] eq 'SILENT') {
               if ($args[1]) {
                  if ($cargs[1] eq 'ON') {
                     $$silent = 1;
                     utils->ack($target);
                  }
                  elsif ($cargs[1] eq 'OFF') {
                     $$silent = 0;
                     utils->ack($target);
                  }
               }
               elsif (!$args[1]) {
                  utils->msg($target, 'SILENT: %s', $$silent ? 'ON' : 'OFF');
               }
               else {
                  utils->err($target, 'syntax: SET SILENT [ON|OFF]');
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
      elsif ($cmd eq 'RAW') {
         if ($args[0]) {
            main::raw("%s", "@args");
            utils->ack($target);
         }
         else {
            utils->err($target, 'syntax: RAW <input>');
         }
      }
      elsif ($cmd eq 'EVAL') {
         if ($args[0]) {
            eval("@args");
            utils->msg($target, $@) if $@;
         }
         else {
            utils->err($target, 'syntax: EVAL <perl code>');
         }
      }
      elsif ($cmd eq 'SHELL') {
         if ($args[0]) {
            for (`@args 2>&1`) {
               $_ =~ s/\t/ /g;
               $_ =~ s/_\x8//g;
               utils->msg($target, $_);
            }

            if ($? >> 8 != 0) {
               utils->err($target, 'returned: %s', $? >> 8);
            }
         }
         else {
            utils->err($target, 'syntax: SHELL <command>');
         }
      }
      elsif ($cmd eq 'JOIN') {
         if ($args[0]) {
            my $joined = 0;

            for (split(' ', utils->chantrim("@args"))) {
               if (main::ischan($_)) {
                  utils->joinchan($_);
                  $channels->{$$myprofile}{$_} = $args[1] ? $args[1] : '';
                  $joined = 1;
               }
               else {
                  utils->err($target, '%s is not a valid channel', $_);
               }
            }

            utils->ack($target) if $joined;
         }
         else {
            utils->err($target, 'syntax: JOIN <channel>');
         }
      }
      elsif ($cmd eq 'PART') {
         if ($args[0]) {
            my $parted = 0;

            for (split(' ', utils->chantrim("@args"))) {
               if (main::ischan($_)) {
                  utils->partchan($_);
                  delete $channels->{$$myprofile}{$_};
                  $parted = 1;
               }
               else {
                  utils->err($target, '%s is not a valid channel', $_);
               }
            }

            utils->ack($target) if $parted;
         }
         else {
            if (main::ischan($target)) {
               utils->partchan($target);
            }
            else {
               utils->err($target, 'syntax: PART <channel> [,<channel>]...');
            }
         }
      }
      elsif ($cmd eq 'LIST' || $cmd eq 'LS') {
         if ($args[0]) {
            if ($cargs[0] eq 'CHANNELS' || $cargs[0] eq 'CHANS') {
               my $chans;
               my $count = 0;

               for (keys(%{$mychannels->{$$myprofile}})) {
                  $count++;
                  $chans .= sprintf("%s, ", $_);
               }

               if ($chans) {
                  utils->msg($target, substr($chans, 0, -2));
                  utils->msg($target, 'total: %s', $count);
               }
               else {
                  utils->msg($target, 'no channels joined');
               }
            }
            elsif ($cargs[0] eq 'HELP') {
               utils->hlp($target, 'syntax: LIST(LS) CHANNELS(CHANS)');
            }
         }
         else {
            utils->err($target, 'syntax: LIST(LS) CHANNELS(CHANS)');
         }
      }
      elsif ($cmd eq 'MSG') {
         if ($args[1]) {
            utils->msg($args[0], join(' ', @args[1..$#args]));
            utils->ack($target) unless $args[0] eq $target;
         }
         else {
            utils->err($target, 'syntax: MSG <target> <text>');
         }
      }
      elsif ($cmd eq 'ACT') {
         if ($args[1]) {
            utils->act($args[0], join(' ', @args[1..$#args]));
            utils->ack($target) unless $args[0] eq $target;
         }
         else {
            utils->err($target, 'syntax: ACT <target> <text>');
         }
      }
      elsif ($cmd eq 'NOTICE') {
         if ($args[1]) {
            utils->ntc($args[0], join(' ', @args[1..$#args]));
            utils->ack($target) unless $args[0] eq $target;
         }
         else {
            utils->err($target, 'syntax: NOTICE <target> <text>');
         }
      }
      elsif ($cmd eq 'ACK') {
         utils->ack($target);
      }
   }
}

1;
