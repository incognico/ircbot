#!/usr/bin/env perl

# TODO:
# - Reduce complexity (rewrite this piece of crap lol)
# - Track usermodes
# - Use Carp in modules
# - Fix require utils in modules

# ./bot.pl -p <profile name>
# 
# Copyright 2012, Nico R. Wohlgemuth <nico@lifeisabug.com>

use utf8;
use strict;
use warnings;
use feature 'switch';
use sigtrap 'handler', \&quit, 'INT';

no warnings 'qw';

use Carp;
use Getopt::Std;
use Module::Refresh;

our $opt_p;
getopt('p');
my $myprofile; # -p overrides

### start config ###

# settings (defaults)
my $rawlog       = 0;
my $silent       = 0; 
my $public       = 1;
my $rejoinonkick = 1;
my $useoident    = 1;
my $mytrigger    = '!';
my $myaddr4      = '127.0.0.1';
my $myaddr6      = '::1';
my $adminpass    = 'secret';
my @myadmins     = qw(nico!nico@lifeisabug.com other!mask@of.some.admin);
my @mymodules    = qw(utils basecmds invitejoin tlds);
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
      modules           => [qw(utils basecmds yiff)],
   },
);

# channels
my %channels = (
   example => {
      '#channel' => '',
   },
);

### end config ###

checkparams();

 my $mynick            = $profiles{$myprofile}{nick};
(my $defaultuser       = $mynick) =~ s/[^A-Za-z0-9-_]//g;
 my $authcmd           = $profiles{$myprofile}{authcmd};
 my $authserv          = $profiles{$myprofile}{authserv};
 my $authservackwho    = $profiles{$myprofile}{authservackwho};
 my $authservackstring = $profiles{$myprofile}{authservackstring};
 my $mypass            = $profiles{$myprofile}{pass};

my $myuser            = $profiles{$myprofile}{user}        || $defaultuser;
my $myuserinfo        = $profiles{$myprofile}{userinfo}    || $mynick;
my $myaltnick         = $profiles{$myprofile}{altnick}     || sprintf("[%s]", $mynick);
my $authaltnick       = $profiles{$myprofile}{authaltnick} || 0;
my $mydefumode        = $profiles{$myprofile}{umode}       || 0;
my $ipv6              = $profiles{$myprofile}{ipv6}        || 0;
my $ssl               = $profiles{$myprofile}{ssl}         || 0;
my $auth              = $profiles{$myprofile}{auth}        || 0;
my @mychantypes       = defined @{$profiles{$myprofile}{chantypes}} ? @{$profiles{$myprofile}{chantypes}} : qw(#);

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
   $port = $profiles{$myprofile}{portssl};
}
else {
   $port = $profiles{$myprofile}{portnonssl};
}

### modules
my %modules;

loadmodules(\@mymodules);

my $refresher = Module::Refresh->new;

### connection
my $connected = 0;
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

### main loop

while (my @raw = split(' ', <$socket>)) {
   local $/ = "\r\n";

   chomp(@raw);
   printf("<- %s\n", "@raw") if $rawlog;

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
         callhook('on_invite', (split('!', $who))[0], lc(substr($raw[3], 1)), $who);
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
}

### functions

sub acceptadmins {
   my %uniq;

   $uniq{(split('!', $_))[0]}++ for @myadmins;
   acceptuser($_) for (keys(%uniq));
}

sub acceptuser {
   my $nick = shift || return;

   raw('ACCEPT %s', $nick);
   raw('ACCEPT +%s', $nick);
   printf("[%s] *** Accepted %s\n", scalar localtime, $nick) unless $rawlog;
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
      on_umodeg    => \&on_umodeg,
   );

   if (exists $subs{$sub}) {
      &{$subs{$sub}}(@args) if defined &{$subs{$sub}};

      for (values(%modules)) {
         $_->$sub(@args) if $_->can($sub);
      }
   }
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

sub loadmodules {
   my ($toload, $target) = @_;

   for (@$toload) {
      printf("[%s] === Loading module [%s]\n", scalar localtime, $_);

      unless (exists $modules{$_}) {
         my $modpath = sprintf("modules/%s.pm", $_);

         if (-e $modpath) {
            unless (system(sprintf("/usr/bin/env perl -c %s > /dev/null 2>&1", $modpath))) {
               eval { require sprintf("modules/%s.pm", $_) };

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
                  utils->err($target, sprintf("[%s] was not loaded due to an unhandled exception, check log", $_)) if ($target && utils->can('err'));
               }
            }
            else {
               printf("[%s] === Failed to load erroneous module [%s]\n", scalar localtime, $_);
               utils->err($target, sprintf("[%s] was not loaded because it is erroneous", $_)) if ($target && utils->can('err'));
            }
         }
         else {
            printf("[%s] === Failed to load non-existing module [%s]\n", scalar localtime, $_);
            utils->err($target, sprintf("[%s] was not loaded because it does not exist", $_)) if ($target && utils->can('err'));
         }
      }
      else {
          printf("[%s] === Failed to load already loaded module [%s]\n", scalar localtime, $_);
          utils->err($target, sprintf("[%s] was not loaded because it is already loaded", $_)) if ($target && utils->can('err'));
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

sub israwlog {
   if ($rawlog) {
      return 1;
   }
   else {
      return 0;
   }
}

sub raw {
   my $raw = sprintf(shift, @_) || return;

   printf($socket "%s\r\n", $raw);
   printf("-> %s\n", $raw) if $rawlog;
}

sub unloadmodules {
   my ($tounload, $target) = @_;

   for (@$tounload) {
      if (exists $modules{$_}) {
         $_->on_unload if $_->can('on_unload');
         printf("[%s] === Unloading module [%s]\n", scalar localtime, $_);
         $refresher->unload_module(sprintf("modules/%s.pm", $_));
         delete $modules{$_};
      }
      else {
         printf("[%s] === Can not unload inactive module [%s]\n", scalar localtime, $_);
         utils->err($target, sprintf("[%s] was not unloaded because it was not active", $_)) if ($target && utils->can('err'));
      }
   }
}

sub quit {
   callhook('on_ownquit');
   raw('QUIT :k');
   printf("[%s] *** %s: exiting\n", scalar localtime, $mynick) unless $rawlog;
}

#### main hooks

sub on_connected {
   printf("[%s] *** Connected to %s:%d [IPv6: %d, SSL: %d] as \"%s\"\n", scalar localtime, $server, $port, $ipv6, $ssl, $mynick) unless $rawlog;
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
      printf("[%s] *** Mode change [%s] for user %s\n", scalar localtime, $mode, $target) unless $rawlog;

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
      $_ =~ s/[+%@&~]//;
      $mychannels{$myprofile}{$chan}{$_}++;
   }
}

sub on_nick {
   my ($oldnick, $newnick) = @_;

   if ($oldnick eq $mynick) {
      printf("[%s] *** Renamed from %s to %s\n", scalar localtime, $oldnick, $newnick) unless $rawlog;
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
      printf("[%s] *** Nickname %s is already in use\n", scalar localtime, $mynick) unless $rawlog;
      $mynick = $myaltnick;
      raw('NICK %s', $mynick);
      $nicktries++;
      $auth = 0 unless $authaltnick;
      croak("All nicknames already in use") if $nicktries > 1;
   }
}

sub on_notice {
   my ($target, $msg, undef, undef, undef, undef, $who) = @_;

   $msg = utils->stripcodes($msg) if (utils->can('stripcodes'));

   if ($auth && $target eq $mynick && $who eq $authservackwho) {
      if ($msg =~ /^$authservackstring/) {
         printf("[%s] *** Successfully authenticated to %s as \"%s\"\n", scalar localtime, $authserv, $1 ? $1 : $mynick) unless $rawlog;
         autojoin();
      }
   }
}

sub on_ownjoin {
   my $chan = shift || return;

   printf("[%s] *** Joined %s\n", scalar localtime, $chan) unless $rawlog;
}

sub on_ownkick {
   my ($chan, $kicker, $reason) = @_;

   printf("[%s] *** Kicked from %s by %s [%s]\n", scalar localtime, $chan, $kicker, $reason) unless $rawlog;
   delete $mychannels{$myprofile}{$chan};

   if ($rejoinonkick && exists $channels{$myprofile}{$chan}) {
      printf("[%s] *** Trying to rejoin %s because it is a main channel\n", scalar localtime, $chan) unless $rawlog;
      raw('JOIN %s %s', $chan, $channels{$myprofile}{$chan});
   }
}

sub on_ownpart {
   my $chan = shift || return;

   printf("[%s] *** Left %s\n", scalar localtime, $chan) unless $rawlog;
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
                     utils->ntc($nick, 'Successfully authenticated [%s]', $who) if utils->can('ntc');
                  }
                  else {
                     utils->ntc($nick, 'Already authenticated [%s]', $who) if utils->can('ntc');
                  }
               }
               else {
                  utils->ntc($nick, 'Wrong password for [%s]', $who) if utils->can('ntc');
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
                  $tolist .= sprintf("%s, ", $_);
               }

               if ($tolist) {
                  utils->msg($target, substr($tolist, 0, -2)) if utils->can('msg');
               }
               #else {
               #   utils->msg($target, 'no modules loaded') if utils->can('msg');
               #}
            }
            elsif ($cargs[0] eq 'LOAD' || $cargs[0] eq 'L') {
               if ($args[1]) {
                  my @toload = @args[1..$#args];

                  loadmodules(\@toload, $target);
                  utils->ack($target) if utils->can('ack');
               }
               else {
                  utils->err($target, 'syntax: MODULE(MOD) LOAD(L) ALL|<name> [<name>]...') if utils->can('err');
               }
            }
            elsif ($cargs[0] eq 'UNLOAD' || $cargs[0] eq 'U') {
               if ($args[1]) {
                  my @toreload = @args[1..$#args];

                  unloadmodules(\@toreload, $target);
                  utils->ack($target) if utils->can('ack');
               }
               else {
                  utils->err($target, 'syntax: MODULE(MOD) UNLOAD(U) ALL|<name> [<name>]...') if utils->can('err');
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
                     utils->ack($target) if utils->can('ack');
                  }
                  else {
                     my @toreload = @args[1..$#args];

                     unloadmodules(\@toreload, $target);
                     loadmodules(\@toreload, $target);
                     utils->ack($target) if utils->can('ack');
                  }
               }
               else {
                  utils->err($target, 'syntax: MODULE(MOD) RELOAD(R) ALL|<name> [<name>]...') if utils->can('err');
               }
            }
            elsif ($cargs[0] eq 'HELP') {
               if (utils->can('hlp')) {
                  utils->hlp($target, $_) for (@syntax);
               }
            }
         }
         elsif (!$args[0]) {
            if (utils->can('hlp')) {
               utils->err($target, $_) for (@syntax);
            }
         }
      }
   }
}

sub on_quit {
   my ($nick, undef) = @_;

   delete $mychannels{$myprofile}{$_}{$nick} for (keys(%{$mychannels{$myprofile}}));
}

sub on_umodeg {
   my $nick = shift || return;
   my %uniq;

   $uniq{(split('!', $_))[0]}++ for @myadmins;
   acceptuser($nick) if (exists $uniq{$nick});
}

exit 0;
