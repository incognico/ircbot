package quotes;

use utf8;
use strict;
use warnings;

use experimental 'smartmatch';

my $mytrigger;

my $dbh;

### start config

my $quotechan = '';
my @candel = qw();
my %sql = (
   db    => "$ENV{HOME}/.bot/quotes/quotes.db",
   table => 'quotes',
);

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

sub sqlite_connect {
   unless ($dbh = DBI->connect("DBI:SQLite:dbname=$sql{db}", '', '', { AutoCommit => 1 })) {
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

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mytrigger = $self->{mytrigger};

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, $who) = @_;

   return if ($target ne $quotechan);

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my @cargs = map { uc } @args;
      my $cmd = substr(shift(@cargs), 1);
      shift(@args);

      # cmds 
      if ($cmd eq 'QUOTE') {
         unless (sqlite_connect() == 0) {
            main::err($target, 'database error');
            return 1;
         }

         if ($args[0] && $cargs[0] eq 'ADD') {
            if ($args[1]) {
               my $result = $dbh->do("INSERT INTO $sql{table} (date, channel, nickname, quote) VALUES(datetime('now','localtime'), ?, ?, ?)", {}, ($target, $nick, "@args[1..$#args]"));
               my $id = $dbh->sqlite_last_insert_rowid();
               
               if ($result) {
                  main::msg($target, 'quote #%d has been added', $id);
               }
               else {
                  main::err($target, 'quote was not added');
               }
            }
         }
         elsif ($args[0] && $cargs[0] eq 'DELETE') {
            if (defined $args[1] && $args[1] =~ /\d/ && $who ~~ @candel) {
               my $rows = $dbh->do("DELETE FROM $sql{table} WHERE id = ? and channel = ?", {}, $args[1], $target);

               if ($rows && $rows > 0) {
                  main::ack($target, 'quote #%d has been deleted', $args[1]);
               }
               else {
                  main::err($target, 'quote #%d was not deleted', $args[1]);
               }
            }
         }
         elsif ($args[0] && $cargs[0] eq 'TOTAL' || $args[0] && $cargs[0] eq 'COUNT') {
            my $result = $dbh->selectrow_arrayref("SELECT count(*) as cnt FROM $sql{table} WHERE channel = ?", {}, $target);

            if (defined $result) {
               main::msg($target, 'total quotes for %s: %d', $target, @$result[0]);
            }
            else {
               main::err($target, 'database error');
            }
         }
         elsif ($args[0] && $cargs[0] eq 'READ' || $args[0] && $cargs[0] eq 'SHOW') {
            if ($args[1] && $args[1] =~ /\d/) {
               my $stmt = "SELECT nickname,quote,(strftime('%s','now','localtime') - strftime('%s', date, 'localtime')) FROM $sql{table} WHERE channel = ? and id = ?";
               my @bind = ($target, $args[1]);

               my $result = $dbh->selectrow_arrayref($stmt, {}, @bind);

               if ($result) {
                  main::msg($target, '[quote] #%d added by %s %s ago:', $args[1], @$result[0], join(' and ', splice(@{[split(/, /, duration(@$result[2]))]}, 0, 2)));
                  main::msg($target, '[quote] %s', @$result[1]);
               }
               else {
                  main::msg($target, 'no such quote');
               }
            }
         }
         elsif ($args[0] && $cargs[0] eq 'HELP') {
            main::msg($target, 'http://spa.st/%s', $nick);
         }
         elsif ($args[0] && $cargs[0] eq 'RANDOM' || !$args[0]) {
            my $stmt = "SELECT id,nickname,quote,(strftime('%s','now','localtime') - strftime('%s', date, 'localtime')) FROM $sql{table} WHERE channel = ? ORDER BY RANDOM() DESC LIMIT 1";
            my @bind = $target;

            my $result = $dbh->selectrow_arrayref($stmt, {}, @bind);

            if ($result) {
               main::msg($target, '[quote] #%d added by %s %s ago:', @$result[0], @$result[1], join(' and ', splice(@{[split(/, /, duration(@$result[3]))]}, 0, 2)));
               main::msg($target, '[quote] %s', @$result[2]);
            }
            else {
               main::msg($target, 'no quotes for %s', $target);
            }
         }
         elsif ($args[0] && $cargs[0] eq 'SEARCH' || $args[0] && $cargs[0] eq 'FIND') {
            #elsif ($args[0] && $cargs[0] eq 'SEARCH' || exists $args[0] && exists $cargs[0]) {
            if ($args[1]) {
               if (length("@args[1..$#args]") < 2) {
                  main::msg($target, 'specify 2 or more characters');
                  return 1;
               }
               else {
                  my $stmt = "SELECT id,nickname,quote,(strftime('%s','now','localtime') - strftime('%s', date, 'localtime')) FROM $sql{table} WHERE channel = ? and quote LIKE ? ORDER BY id";
                  my @bind = ($target, "%@args[1..$#args]%");

                  my $result = $dbh->selectall_arrayref($stmt, {}, @bind);

                  if ($result) {
                     my $matches;

                     for (@$result) {
                        $matches .= "$_->[0],";
                     }

                     chop($matches) if ($matches);

                     unless (scalar(@$result)) {
                        main::msg($target, 'no matching quote found');
                     }
                     elsif (scalar(@$result) == 1) {
                        main::msg($target, '[quote] #%d added by %s %s ago:', @$result[0]->[0], @$result[0]->[1], join(' and ', splice(@{[split(/, /, duration(@$result[0]->[3]))]}, 0, 2)));
                        main::msg($target, '[quote] %s', @$result[0]->[2]);
                     }
                     else {
                        main::msg($target, 'matching quotes: %s', $matches) if ($matches);
                     }
                  }
               }
            }
         }

         sqlite_disconnect();
      }
      elsif ($cmd eq 'QUOTEME') {
         unless (sqlite_connect() == 0) {
            main::err($target, 'database error');
            return 1;
         }

         my $stmt = "SELECT id,nickname,quote,(strftime('%s','now','localtime') - strftime('%s', date,'localtime')) FROM $sql{table} WHERE channel = ? AND quote LIKE ? ORDER BY RANDOM() DESC LIMIT 1";
         my @bind = ($target, "%$nick%");

         my $result = $dbh->selectrow_arrayref($stmt, {}, @bind);

         if ($result) {
            main::msg($target, '[quote] #%d added by %s %s ago:', @$result[0], @$result[1], join(' and ', splice(@{[split(/, /, duration(@$result[3]))]}, 0, 2)));
            main::msg($target, '[quote] %s', @$result[2]);
         }
         else {
            main::msg($target, 'no quotes of %s in %s', $nick, $target);
         }
      
         sqlite_disconnect();
      }
   }
}

1;
