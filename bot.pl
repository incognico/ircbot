#!/usr/bin/env perl

# ./bot.pl -p <profile name>
# 
# Copyright 2012, Nico R. Wohlgemuth <nico@lifeisabug.com>

use utf8;
use strict;
use warnings;

use feature 'switch';
use sigtrap 'handler', \&quit, 'INT';

use threads;
use threads::shared;

no warnings 'qw';

use FindBin '$RealBin';
use Carp;
use Getopt::Std;
use Module::Refresh;
use File::Tail;

our $opt_p;
getopt('p');
my $myprofile; # -p overrides

### start config

# settings (defaults)
my $rawlog       = 0;
my $silent       = 0; 
my $public       = 1;
my $rejoinonkick = 1;
my $splitlen     = 400;
my $ircgatedir   = '/usr/home/k/ircgate_nico'; # no tailing /
my $useoident    = 1;
my $mytrigger    = '!';
my $myaddr4      = '127.0.0.1';
my $myaddr6      = '::1';
my $adminpass    = 'secret';
my @myadmins     = qw(nico!nico@lifeisabug.com other!mask@of.some.admin);
my @mymodules    = qw(basecmds invitejoin tlds);
my $myhelptext   = 'Help yourself.';

# profiles (networks)
my %profiles = (
   example => {
      ipv6              => 1,
      ssl               => 1,
      server6           => 'irc.example.net',
      portssl           => 9999,
      auth              => 1,
      authcmd           => 'IDENTIFY',
      authserv          => 'NickServ@services.example.net',
      authservackwho    => 'NickServ!service@example.net',
      authservackstring => 'Password accepted - you are now recognized.',
      nick              => 'IamAbot',
      pass              => 'secret',
      umode             => '+gp',
      public            => 0,
   },
   yiff => {
      server4           => 'irc.example.com'
      port              => 6667
      nick              => 'YiffServ',
      user              => 'ohai',
      userinfo          => 'yiffin\'',
      trigger           => '.',
      helptext          => '',
      silent            => 1,
      admins            => [qw(the!yiff@admin.only)],
      adminpass         => 'specialsecret',
      modules           => [qw(basecmds yiff)],
   },
);

# channels
my %channels = (
   example => {
      '#channel' => '',
   },
);

### end config

checkparams();

 my $mynick            = $profiles{$myprofile}{nick};
(my $defaultuser       = $mynick) =~ s/[^A-Za-z0-9-_]//g;
 my $authcmd           = $profiles{$myprofile}{authcmd};
 my $authserv          = $profiles{$myprofile}{authserv};
 my $authservackwho    = $profiles{$myprofile}{authservackwho};
 my $authservackstring = $profiles{$myprofile}{authservackstring};
 my $mypass            = $profiles{$myprofile}{pass};

my $myuser      = $profiles{$myprofile}{user}        || $defaultuser;
my $myuserinfo  = $profiles{$myprofile}{userinfo}    || $mynick;
my $myaltnick   = $profiles{$myprofile}{altnick}     || "[$mynick]";
my $authaltnick = $profiles{$myprofile}{authaltnick} || 0;
my $mydefumode  = $profiles{$myprofile}{umode}       || 0;
my $ipv6        = $profiles{$myprofile}{ipv6}        || 0;
my $ssl         = $profiles{$myprofile}{ssl}         || 0;
my $auth        = $profiles{$myprofile}{auth}        || 0;
my @mychantypes = defined @{$profiles{$myprofile}{chantypes}} ? @{$profiles{$myprofile}{chantypes}} : qw(# &);

$myaddr4      = $profiles{$myprofile}{addr4}        if defined $profiles{$myprofile}{addr4};
$myaddr6      = $profiles{$myprofile}{addr6}        if defined $profiles{$myprofile}{addr6};
@myadmins     = @{$profiles{$myprofile}{admins}}    if defined @{$profiles{$myprofile}{admins}};
$myadminpass  = $profiles{$myprofile}{adminpass}    if defined $profiles{$myprofile}{adminpass};
$myhelptext   = $profiles{$myprofile}{helptext}     if defined $profiles{$myprofile}{helptext};
@mymodules    = @{$profiles{$myprofile}{modules}}   if defined @{$profiles{$myprofile}{modules}};
$mytrigger    = $profiles{$myprofile}{trigger}      if defined $profiles{$myprofile}{trigger};
$public       = $profiles{$myprofile}{public}       if defined $profiles{$myprofile}{public};
$rawlog       = $profiles{$myprofile}{rawlog}       if defined $profiles{$myprofile}{rawlog};
$rejoinonkick = $profiles{$myprofile}{rejoinonkick} if defined $profiles{$myprofile}{rejoinonkick};
$silent       = $profiles{$myprofile}{silent}       if defined $profiles{$myprofile}{silent};

my %authedadmins;
my %mychannels;
my %myumodes;

my $myaddr;
my $port;
my $server;

if ($ipv6) {
   $myaddr = $myaddr6;
   $server = $profiles{$myprofile}{server6};

   if ($ssl) {
      use IO::Socket::SSL 'inet6';

   }
   else {
      use IO::Socket::INET6;
   }
}
else {
   $myaddr = $myaddr4;
   $server = $profiles{$myprofile}{server4};

   if ($ssl) {
      use IO::Socket::SSL;
   }
   else {
      use IO::Socket::INET;
   }
}

if ($ssl) {
   IO::Socket::SSL::set_defaults(SSL_verify_mode => SSL_VERIFY_NONE);
   $port = $profiles{$myprofile}{portssl};
}
else {
   $port = $profiles{$myprofile}{portnonssl};
}

### modules

my %modules;
my $refresher = Module::Refresh->new;

loadmodules(\@mymodules);

### connection

my @lastraw;
my $connected :shared = 0;
my $nicktries = 0;

if ($useoident) {
   open my $oident, '>', "$ENV{HOME}/.oidentd.conf" || croak $!;
   printf $oident 'global { reply "%s" }', $myuser;
   close $oident;
}

my $socket = ($ssl ? 'IO::Socket::SSL' : ($ipv6 ? 'IO::Socket::INET6' : 'IO::Socket::INET'))->new(
   LocalAddr => $myaddr,
   PeerAddr  => $server,
   PeerPort  => $port,
) or croak $!;

raw('NICK %s', $mynick);
raw('USER %s 8 * :%s', $myuser, $myuserinfo);

threads->create(\&ircgate)->detach();

### main loop

while (my @raw = split(' ', <$socket>)) {
   local $/ = "\r\n";

   chomp(@raw);
   print("<- @raw\n") if $rawlog;

   local $/ = "\n";

   if ($raw[0] eq 'PING') {
      raw('PONG %s', $raw[1]);
      callhook('on_ping');
   }

   ### handle events

   given ($raw[1]) {
      when ([qw(PRIVMSG NOTICE)]) {
         my ($target, $msg, $ischan) = ($raw[2], substr(join(' ', @raw[3..$#raw]), 1), ischan(substr($raw[2], 0, 1)));
         my $who = substr($raw[0], 1);
         my ($nick, $user, $host) = split(/[!@]/, $who);
         
         if ($raw[1] eq 'PRIVMSG') {
            callhook('on_privmsg', $ischan ? lc($target) : $target, $msg, $ischan, $nick, $user, $host, $who);
         }
         else {
            callhook('on_notice', $ischan ? lc($target) : $target, $msg, $ischan, $nick, $user, $host, $who);
         }
         # target, msg, ischan, nick, user, host, who
      }
      when ('JOIN') {
        callhook('on_join', (split('!', substr($raw[0], 1)))[0], lc((substr($raw[2], 0, 1) eq ':') ? substr($raw[2], 1) : $raw[2]));
        # nick, channel
      }
      when ('PART') {
         callhook('on_part', (split('!', substr($raw[0], 1)))[0], lc($raw[2]));
         # nick, channel
      }
      when ('QUIT') {
         callhook('on_quit', (split('!', substr($raw[0], 1)))[0], substr(join(' ', @raw[2..$#raw]), 1));
         # nick, msg
      }
      when ('MODE') {
         my $ischan = ischan(substr($raw[2], 0, 1));
         callhook('on_mode', $ischan ? lc($raw[2]) : $raw[2], $ischan, ((substr($raw[3], 0, 1) eq ':') ? substr($raw[3], 1) : $raw[3]));
         # target, ischan, mode
      }
      when ('NICK') {
         callhook('on_nick', (split('!', substr($raw[0], 1)))[0], substr($raw[2], 1));
         # oldnick, newnick
      }
      when ('INVITE') {
         my $who = substr($raw[0], 1);
         callhook('on_invite', (split('!', $who))[0], lc(((substr($raw[3], 0, 1) eq ':') ? substr($raw[3], 1) : $raw[3])), $who);
         # nick, channel, who
      }
      when ('KICK') {
         callhook('on_kick', lc($raw[2]), $raw[3], (split('!', substr($raw[0], 1)))[0], substr(join(' ', @raw[4..$#raw]), 1));
         # chan, kickee, kicker, reason
      }
      when ('353') {
         if ($raw[3] =~ /[=@*]/ && ischan($raw[4])) {
            callhook('on_names', lc($raw[4]), substr(join(' ', @raw[5..$#raw]), 1));
            # chan, names
         }
      }
      when ('366') {
         callhook('on_synced', lc($raw[3]));
         # chan
      }
      when ('718') {
         callhook('on_umodeg', (split(/\[/, $raw[3]))[0]);
         # nick
      }
      when ('554') {
         callhook('on_umodeg', substr($raw[4], 1));
         # nick
      }
      when ([qw(432 433 434)]) {
         callhook('on_nickinuse');
      }
      when ('005') {
         callhook('on_isupport', join(' ', @raw[2..$#raw]));
         # isupport
      }
      when ('001') {
         callhook('on_connected');
      }
   }

   push(@lastraw, "@raw");
   shift(@lastraw) if ($#lastraw >= 3)
}

callhook('on_ownquit');

unless ($connected) {
   printf("[%s] *** %s: clean exit\n", scalar localtime, $mynick);
}
else {
   printf("[%s] *** %s: dirty exit\n", scalar localtime, $mynick);

   unless ($rawlog) {
      print("<- $_\n") for @lastraw;
   }
}

### functions

sub acceptadmins {
   my %uniq;

   $uniq{(split('!', $_))[0]}++ for @myadmins;
   acceptuser($_) for keys(%uniq);
}

sub acceptuser {
   my $nick = shift || return;

   raw('ACCEPT %s', $nick);
   raw('ACCEPT +%s', $nick);
   printf("[%s] *** Accepted %s\n", scalar localtime, $nick);
}

sub ack {
   my $target = shift;

   msg($target, 'done {::%s}', caller) unless $silent;
}

sub act {
   my $target = shift;
   my $act    = sprintf(shift, @_);

   for (split(/\n|(.{$splitlen})/, $act)) {
      raw("PRIVMSG %s :\001ACTION %s\001", $target, $_) if (defined $_);
   }
}

sub authenticate {
   raw('PRIVMSG %s :%s %s', $authserv, $authcmd, $mypass);
}

sub autojoin {
   for (keys(%{$channels{$myprofile}})) {
      raw('JOIN %s %s', lc($_), $channels{$myprofile}{$_});
   }

   callhook('on_autojoin');
}

sub callhook {
   my ($sub, @args) = @_;

   my %subs = (
      on_autojoin  => \&on_autojoin,
      on_connected => \&on_connected,
      on_invite    => \&on_invite,
      on_isupport  => \&on_isupport,
      on_join      => \&on_join,
      on_kick      => \&on_kick,
      on_mode      => \&on_mode,
      on_names     => \&on_names,
      on_nick      => \&on_nick,
      on_nickinuse => \&on_nickinuse,
      on_notice    => \&on_notice,
      on_ownjoin   => \&on_ownjoin,
      on_ownkick   => \&on_ownkick,
      on_ownpart   => \&on_ownpart,
      on_ownquit   => \&on_ownquit,
      on_part      => \&on_part,
      on_ping      => \&on_ping,
      on_privmsg   => \&on_privmsg,
      on_quit      => \&on_quit,
      on_synced    => \&on_synced,
      on_umodeg    => \&on_umodeg,
   );

   if (exists $subs{$sub}) {
      &{$subs{$sub}}(@args) if defined &{$subs{$sub}};

      for (values(%modules)) {
         $_->$sub(@args) if $_->can($sub);
      }
   }
}

sub chantrim {
   my $string = shift;

   $string =~ s/[\s+,]/ /g;
   $string =~ s/^\s+//;
   $string =~ s/\s+$//;

   return lc($string);
}

sub checkparams {
   if ($opt_p) {
      if (defined $profiles{$opt_p}) {
         $myprofile = $opt_p;
         printf("[%s] === Starting bot [profile: %s]\n", scalar localtime, $myprofile);
      }
      else {
         croak("Invalid profile specified (-p)");
      }
   }
   else {
      croak("No profile specified (-p)");
   }
}

sub err {
   my $target = shift;
   my $string = sprintf(shift, @_);

   msg($target, 'error: %s {::%s}', $string, caller(0)) unless $silent;
}

sub hlp {
   my ($target, $string) = @_;

   msg($target, 'help: %s {::%s}', $string, caller(0)) unless $silent;
}

sub ircgate {
   my $file = "$ircgatedir/$myprofile";

   if (-e $file) {
      printf("[%s] === ircgate: available!\n", scalar localtime);

      my $tail = File::Tail->new(name => $file, maxinterval => 1);

      while (defined(my $line = $tail->read)) {
         my @data = split(' ', $line);
         my $target = $data[0];

         if (substr($target, 0, 1) eq '=') {
            my $gatemod = substr($target, 1);
            my $gatesub = $data[1];

            if ($gatesub) {
               splice(@data, 0, 2);

               if ($gatemod eq 'settopic') {
                  printf("[%s] === ircgate: [main] settopic(%s %s)\n", scalar localtime, $gatesub, join(' ', @data));
                  settopic($gatesub, "@data");
               }
               else {
                  printf("[%s] === ircgate: module [%s] %s(%s)\n", scalar localtime, $gatemod, $gatesub, join(' ', @data));
                  $gatemod->$gatesub(@data) if $gatemod->can($gatesub);
               }
            }
         }
         else {
            my $msg = join(' ', @data[1..$#data]);

            if ($msg) {
               printf("[%s] === ircgate: msg [%s] %s\n", scalar localtime, $target, $msg);
               msg($target, $msg);
            }
         }
      }
   }
   else {
      printf("[%s] === ircgate: %s does not exist! ircgate disabled.\n", scalar localtime, $file);
   }
}

sub joinchan {
   my ($chan, $key) = @_;

   $chan = lc($chan);

   if ($key) {
      raw('JOIN %s %s', $chan, $key);
   }
   else {
      raw('JOIN %s', $chan);
   }
}

sub kick {
   my ($chan, $victim, $reason) = @_;
   my %uniq;

   $uniq{(split('!', $_))[0]}++ for @myadmins;

   if (exists $uniq{$victim}) {
      printf("[%s] === Refusing to kick admin [%s] on %s\n", scalar localtime, $victim, $chan);
      return;
   }

   if ($reason) {
      raw('KICK %s %s :%s', $chan, $victim, $reason);
   }
   else {
      raw('KICK %s %s', $chan, $victim);
   }
}

sub loadmodules {
   my ($toload, $target) = @_;

   for (@$toload) {
      printf("[%s] === Loading module [%s]\n", scalar localtime, $_);

      unless (exists $modules{$_}) {
         my $module = "$RealBin/modules/$_.pm";

         if (-e $module) {
            unless (system("/usr/bin/env perl -c $module > /dev/null 2>&1")) {
               eval { require $module };

               unless ($@) {
                  $modules{$_} = $_->new(
                     channels      => \%channels,
                     myadmins      => \@myadmins,
                     mychannels    => \%mychannels,
                     myhelptext    => \$myhelptext,
                     mynick        => \$mynick,
                     myprofile     => \$myprofile,
                     mytrigger     => \$mytrigger,
                     public        => \$public,
                     rawlog        => \$rawlog,
                     silent        => \$silent,
                  );
               }
               else {
                  chomp $@;
                  carp("$@");
                  printf("[%s] === Failed to load module [%s]\n", scalar localtime, $_);
                  err($target, "[$_] was not loaded due to an unhandled exception, check log") if $target;
               }
            }
            else {
               printf("[%s] === Failed to load erroneous module [%s]\n", scalar localtime, $_);
               err($target, "[$_] was not loaded because it is erroneous") if $target;
            }
         }
         else {
            printf("[%s] === Failed to load non-existing module [%s]\n", scalar localtime, $_);
            err($target, "[$_] was not loaded because it does not exist") if $target;
         }
      }
      else {
          printf("[%s] === Failed to load already loaded module [%s]\n", scalar localtime, $_);
          err($target, "[$_] was not loaded because it is already loaded") if $target;
      }
   }
}

sub isadmin {
   my $who = shift || return;

   if ($authedadmins{$who}) {
      return 1;
   }
   else {
      return 0;
   }
}

sub ischan {
   my $tocheck = shift || return;

   if (substr($tocheck, 0, 1) ~~ @mychantypes) {
      return 1;
   }
   else {
      return 0;
   }
}

sub msg {
   my $target = shift;
   my $msg    = sprintf(shift, @_);

   for (split(/\n|(.{$splitlen})/, $msg)) {
      raw('PRIVMSG %s :%s', $target, $_) if (defined $_);
   }
}

sub ntc {
   my $target = shift;
   my $ntc    = sprintf(shift, @_);

   for (split(/\n|(.{$splitlen})/, $ntc)) {
      raw('NOTICE %s :%s', $target, $_) if (defined $_);
   }
}

sub partchan {
   my ($chan, $reason) = @_;
   
   if ($reason) {
      raw('PART %s :%s', $chan, $reason);
   }
   else {
      raw('PART %s', $chan);
   }
}

sub raw {
   my $raw = sprintf(shift, @_) || return;

   print($socket "$raw\r\n");
   print("-> $raw\n") if $rawlog;
}

sub settopic {
   my ($chan, $text) = @_;

   raw('TOPIC %s :%s', $chan, $text);
}

sub stripcodes {
   my $string = shift;

   $string =~ s/[\002\017\026\037]|\003\d?\d?(?:,\d\d?)?//g;

   return $string;
}

sub unloadmodules {
   my ($tounload, $target) = @_;

   for (@$tounload) {
      if (exists $modules{$_}) {
         printf("[%s] === Unloading module [%s]\n", scalar localtime, $_);
         $_->on_unload if $_->can('on_unload');
         $refresher->unload_module("modules/$_.pm");
         delete $modules{$_};
      }
      else {
         printf("[%s] === Can not unload inactive module [%s]\n", scalar localtime, $_);
         err($target, "[$_] was not unloaded because it was not active") if $target;
      }
   }
}

sub quit {
   $connected = 0;
   raw('QUIT :k');
}

#### main hooks

sub on_connected {
   printf("[%s] *** Connected to %s:%d [IPv6: %d, SSL: %d] as \"%s\"\n", scalar localtime, $server, $port, $ipv6, $ssl, $mynick);
   $connected = 1;
   raw('MODE %s %s', $mynick, $mydefumode) if $mydefumode;

   if ($auth) {
      authenticate();
   }
   else {
      autojoin();
   }
}

sub on_isupport {
   my $isupport = shift || return;

   acceptadmins() if ($isupport ~~ /CALLERID/);
}

sub on_join {
   my ($nick, $chan) = @_;

   if ($nick eq $mynick) {
      callhook('on_ownjoin', $chan);
      # channel
   }
   else {
      $mychannels{$myprofile}{$chan}{$nick}++;
   }
}

sub on_kick {
   my ($chan, $kickee, $kicker, $reason) = @_;

   delete $mychannels{$myprofile}{$chan}{$kickee};

   if ($kickee eq $mynick) {
      callhook('on_ownkick', $chan, $kicker, $reason);
      # channel, kicker, reason
   }
}

sub on_mode {
   my ($target, $ischan, $mode) = @_;

   unless ($ischan) {
      printf("[%s] *** Mode change [%s] for user %s\n", scalar localtime, $mode, $target);

      if ($target eq $mynick) {
         if (substr($mode, 0, 1) eq '+') {
            for (split(//, substr($mode, 1))) {
               $myumodes{$_}++;
            }
         }
         elsif (substr($mode, 0, 1) eq '-') {
            for (split(//, substr($mode, 1))) {
               delete $myumodes{$_};
            }
         }
      }
   }
}

sub on_names {
   my ($chan, $names) = @_;

   for (split(' ', $names)) {
      $_ =~ s/[+%@&~!*]//;
      $mychannels{$myprofile}{$chan}{$_}++;
   }
}

sub on_nick {
   my ($oldnick, $newnick) = @_;

   if ($oldnick eq $mynick) {
      printf("[%s] *** Renamed from %s to %s\n", scalar localtime, $oldnick, $newnick);
      $mynick = $newnick;
   }

   for (keys(%{$mychannels{$myprofile}})) {
      if (exists $mychannels{$myprofile}{$_}{$oldnick}) {
         delete $mychannels{$myprofile}{$_}{$oldnick};
         $mychannels{$myprofile}{$_}{$newnick}++;
      }
   }
}

sub on_nickinuse {
   unless ($connected) {
      printf("[%s] *** Nickname %s is already in use\n", scalar localtime, $mynick);
      $mynick = $myaltnick;
      raw('NICK %s', $mynick);
      $nicktries++;
      $auth = 0 unless $authaltnick;
      croak("All nicknames already in use") if $nicktries > 1;
   }
}

sub on_notice {
   my ($target, $msg, undef, undef, undef, undef, $who) = @_;

   $msg = stripcodes($msg);

   if ($auth && $target eq $mynick && $who eq $authservackwho) {
      if ($msg =~ /^$authservackstring/) {
         printf("[%s] *** Successfully authenticated to %s as \"%s\"\n", scalar localtime, $authserv, $1 ? $1 : $mynick);
         autojoin();
      }
   }
}

sub on_ownjoin {
   my $chan = shift || return;

   printf("[%s] *** Joined %s\n", scalar localtime, $chan);
}

sub on_ownkick {
   my ($chan, $kicker, $reason) = @_;

   printf("[%s] *** Kicked from %s by %s [%s]\n", scalar localtime, $chan, $kicker, $reason);
   delete $mychannels{$myprofile}{$chan};

   if ($rejoinonkick && exists $channels{$myprofile}{$chan}) {
      printf("[%s] *** Trying to rejoin %s because it is a main channel\n", scalar localtime, $chan);
      raw('JOIN %s %s', $chan, $channels{$myprofile}{$chan});
   }
}

sub on_ownpart {
   my $chan = shift || return;

   printf("[%s] *** Left %s\n", scalar localtime, $chan);
   delete $mychannels{$myprofile}{$chan};
}

sub on_part {
   my ($nick, $chan) = @_;

   delete $mychannels{$myprofile}{$chan}{$nick};

   if ($nick eq $mynick) {
      callhook('on_ownpart', $chan)
      # channel
   }
}

sub on_privmsg {
   my ($target, $msg, $ischan, $nick, undef, undef, $who) = @_;

   if (substr($msg, 0, 1) eq $mytrigger) {
      my @args = split(' ', $msg);
      my @cargs = map { uc } @args;
      my $cmd = substr(shift(@cargs), 1);
      shift(@args);

      $target = $nick unless $ischan;

      if ($who ~~ @myadmins) {
         if ($cmd eq 'AUTH') {
            if ($args[0]) {
               if ($args[0] eq $myadminpass) {
                  unless ($authedadmins{$who}) {
                     $authedadmins{$who}++;
                     printf("[%s] *** Admin [%s] successfully authenticated\n", scalar localtime, $who);
                     ntc($nick, 'Successfully authenticated [%s]', $who);
                  }
                  else {
                     ntc($nick, 'Already authenticated [%s]', $who);
                  }
               }
               else {
                  ntc($nick, 'Wrong password for [%s]', $who);
               }
            }
         }
      }

      # admin cmds
      return unless isadmin($who);

      if ($cmd eq 'MODULE' || $cmd eq 'MOD') {
         my @syntax = ('syntax: MODULE(MOD) LIST(LS)', 'syntax: MODULE(MOD) LOAD(L)|UNLOAD(U)|RELOAD(R) ALL|<name> [<name>]...');

         if ($args[0]) {
            if ($cargs[0] eq 'LIST' || $cargs[0] eq 'LS') {
               my $tolist;

               for (keys(%modules)) {
                  $tolist .= "$_, ";
               }

               if ($tolist) {
                  msg($target, substr($tolist, 0, -2));
               }
               else {
                  msg($target, 'no modules loaded');
               }
            }
            elsif ($cargs[0] eq 'LOAD' || $cargs[0] eq 'L') {
               if ($args[1]) {
                  my @toload = @args[1..$#args];

                  loadmodules(\@toload, $target);
                  ack($target);
               }
               else {
                  err($target, 'syntax: MODULE(MOD) LOAD(L) ALL|<name> [<name>]...');
               }
            }
            elsif ($cargs[0] eq 'UNLOAD' || $cargs[0] eq 'U') {
               if ($args[1]) {
                  my @toreload = @args[1..$#args];

                  unloadmodules(\@toreload, $target);
                  ack($target);
               }
               else {
                  err($target, 'syntax: MODULE(MOD) UNLOAD(U) ALL|<name> [<name>]...');
               }
            }
            elsif ($cargs[0] eq 'RELOAD' || $cargs[0] eq 'R') {
               if ($args[1]) {
                  if ($cargs[1] eq 'ALL') {
                     my @toreload;

                     for (keys(%modules)) {
                        push(@toreload, $_)
                     }

                     unloadmodules(\@toreload, $target);
                     loadmodules(\@toreload, $target);
                     ack($target);
                  }
                  else {
                     my @toreload = @args[1..$#args];

                     unloadmodules(\@toreload, $target);
                     loadmodules(\@toreload, $target);
                     ack($target);
                  }
               }
               else {
                  err($target, 'syntax: MODULE(MOD) RELOAD(R) ALL|<name> [<name>]...');
               }
            }
            elsif ($cargs[0] eq 'HELP') {
               hlp($target, $_) for @syntax;
            }
         }
         elsif (!$args[0]) {
            err($target, $_) for @syntax;
         }
      }
   }
}

sub on_quit {
   my ($nick, undef) = @_;

   delete $mychannels{$myprofile}{$_}{$nick} for keys(%{$mychannels{$myprofile}});
}

sub on_umodeg {
   my $nick = shift || return;
   my %uniq;

   $uniq{(split('!', $_))[0]}++ for @myadmins;
   acceptuser($nick) if (exists $uniq{$nick});
}

exit 0;
