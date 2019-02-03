package foodloader;

use utf8;
use strict;
use warnings;

use DBI;

my $mytrigger;

my $dbh;

### start config

my %sql = (
   db    => "/srv/www/foodloader.net/db/foodloader.db",
   table => 'foodloader',
);

### end config

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mytrigger = $self->{mytrigger};

   return $self;
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

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, $user, $host, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      $target = $nick unless ($ischan);

      # cmds
      
      if ($cmd eq 'FL') {
         if ($args[0]) {
            if (length("@args") < 2) {
               main::msg($target, 'specify 2 or more characters');
               return;
            }

            printf("[%s] === modules::%s: foodloader food queried [%s] on %s by %s\n", scalar localtime, __PACKAGE__, "@args", $target, $nick);

            $_ =~ s/ /_/g;

            my $stmt;
            my @bind;

            if ("@args" eq 'random') {
               $stmt = "SELECT id,username,food,date FROM $sql{table} ORDER BY RANDOM() LIMIT 1";
            }
            else {
               $stmt = "SELECT id,username,food,date FROM $sql{table} WHERE filename LIKE ? ORDER BY id DESC LIMIT 1";
               @bind = ("%@args%");
            }

            unless (sqlite_connect() == 0) {
               main::err($target, 'database error');
               return 1;
            }

            my $result = $dbh->selectrow_arrayref($stmt, {}, @bind);

            sqlite_disconnect();

            if ($result) {
               main::msg($target, 'https://foodloader.net/s/%s :: %s :: %s :: %s', @$result[0], @$result[3], @$result[1], @$result[2]);
            }
            else {
                main::msg($target, 'no match');
            }
         }
         else {
            main::hlp($target, 'syntax: FL <search string|random>');
         }
      }
   }
}

1;
