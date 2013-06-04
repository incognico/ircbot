# sqlite3 myprofile.db "create table seen(type text, ts integer, lcnick text primary key, nick text, user text, host text, chan text, kicker text, reason text, newnick text);"

package seen;

use utf8;
use strict;
use warnings;

use DBI;

my $mychannels;
my $myprofile;
my $mytrigger;

my $db;
my $dbh;

### start config

my $dbname = "$ENV{HOME}/.bot/%s/%s.db"; # package name, profile name

### end config

### functions

sub duration {
   my @gmt = gmtime(shift);
   $gmt[5] -= 70;
   return   ($gmt[5] ?                                                        $gmt[5].' year'  .($gmt[5] > 1 ? 's' : '') : '').
            ($gmt[7] ? ($gmt[5]                                  ? ', ' : '').$gmt[7].' day'   .($gmt[7] > 1 ? 's' : '') : '').
            ($gmt[2] ? ($gmt[5] || $gmt[7]                       ? ', ' : '').$gmt[2].' hour'  .($gmt[2] > 1 ? 's' : '') : '').
            ($gmt[1] ? ($gmt[5] || $gmt[7] || $gmt[2]            ? ', ' : '').$gmt[1].' minute'.($gmt[1] > 1 ? 's' : '') : '').
            ($gmt[0] ? ($gmt[5] || $gmt[7] || $gmt[2] || $gmt[1] ? ', ' : '').$gmt[0].' second'.($gmt[0] > 1 ? 's' : '') : '');
}

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mychannels = $self->{mychannels};
   $myprofile  = $self->{myprofile};
   $mytrigger  = $self->{mytrigger};

   $db = sprintf($dbname, __PACKAGE__, $$myprofile);

   sqlite_connect();

   return $self;
}

sub removelcnick {
   $dbh->do('DELETE FROM seen WHERE lcnick = ?', undef, lc($_[0]));
}

sub sqlite_connect {
   unless ($dbh = DBI->connect("DBI:SQLite:dbname=$db", '', '', { AutoCommit => 1 })) {
      printf("[%s] !!! modules::%s: %s\n", scalar localtime, __PACKAGE__, $DBI::errstr);
      return 1;
   }
   else {
      return 0;
   }
}

sub sqlite_disconnect {
   $dbh->disconnect;
}

### hooks

sub on_join {
   my ($self, undef, $nick, undef, undef, undef) = @_;

   removelcnick($nick);
}

sub on_kick {
   my ($self, $chan, $nick, $kicker, $msg) = @_;
   
   removelcnick($nick);

   $dbh->do('INSERT INTO seen (type,ts,lcnick,nick,chan,kicker,reason) VALUES (?,?,?,?,?,?,?)', undef, ('kick', time, lc($nick), $nick, $chan, $kicker, $msg ? $msg : 'n/a'));
}

sub on_nick {
   my ($self, $nick, $newnick, $user, $host, undef) = @_;

   removelcnick($newnick);

   $dbh->do('INSERT INTO seen (type,ts,lcnick,nick,user,host,newnick) VALUES (?,?,?,?,?,?,?)', undef, ('nick', time, lc($nick), $nick, $user, $host, $newnick));
}

sub on_ownquit {
   sqlite_disconnect();
}

sub on_part {
   my ($self, $chan, $nick, $user, $host, undef, $msg) = @_;
   
   removelcnick($nick);

   $dbh->do('INSERT INTO seen (type,ts,lcnick,nick,user,host,chan,reason) VALUES (?,?,?,?,?,?,?,?)', undef, ('part', time, lc($nick), $nick, $user, $host, $chan, $msg ? $msg : 'n/a'));
}

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      return unless ($ischan);

      # cmds 
      if ($cmd eq 'SEEN') {
         if ($args[0]) {
            my $online;

            LOL: { 
               for my $chans (keys(%{$mychannels->{$$myprofile}})) {
                  for (keys(%{$mychannels->{$$myprofile}{$chans}})) {
                     if (lc($_) eq lc($args[0])) {
                        $online = $_;
                        last LOL;
                     }
                  }
               }
            }

            if ($online) {
               main::msg($target, '%s is online right now', $online);
            }
            else {
               my $guy = $dbh->selectrow_hashref('SELECT * FROM seen WHERE lcnick = ?', undef, lc($args[0]));

               unless ($guy) {
                  main::msg($target, 'I have not seen %s yet', $args[0]);
               }
               else {
                  if ($$guy{type} eq 'nick') {
                     main::msg($target, '%s (%s@%s) was last seen %s ago, changing nicks to %s', $$guy{nick}, $$guy{user}, $$guy{host}, duration(time - $$guy{ts}), $$guy{newnick});
                  }
                  elsif ($$guy{type} eq 'kick') {
                      main::msg($target, '%s was last seen %s ago, being kicked from %s by %s with reason %s', $$guy{nick}, duration(time - $$guy{ts}), $$guy{chan}, $$guy{kicker}, $$guy{reason});
                  }
                  elsif ($$guy{type} eq 'part') {
                      main::msg($target, '%s (%s@%s) was last seen %s ago, parting %s with reason: %s', $$guy{nick}, $$guy{user}, $$guy{host}, duration(time - $$guy{ts}), $$guy{chan}, $$guy{reason});
                  }
                  elsif ($$guy{type} eq 'quit') {
                      main::msg($target, '%s (%s@%s) was last seen %s ago, quitting with reason: %s', $$guy{nick}, $$guy{user}, $$guy{host}, duration(time - $$guy{ts}), $$guy{reason});
                  }
               }
            }
         }
         else {
            main::msg($target, 'seen who?');
         }
      }
   }
}

sub on_quit {
   my ($self, $nick, $user, $host, undef, $msg) = @_;

   removelcnick($nick);

   $dbh->do('INSERT INTO seen (type,ts,lcnick,nick,user,host,reason) VALUES (?,?,?,?,?,?,?)', undef, ('quit', time, lc($nick), $nick, $user, $host, $msg ? $msg : 'n/a'));
}

sub on_synced {
   my ($self, $chan) = @_;

   removelcnick($_) for (keys(%{$mychannels->{$$myprofile}{$chan}}));
}

sub on_unload {
   sqlite_disconnect();
}

1;
