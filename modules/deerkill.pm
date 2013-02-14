package deerkill;

use utf8;
use strict;
use warnings;

use DBI;

my $mytrigger;

my $dbh;

### start config

my %sql = (
   host  => '',
   db    => '',
   table => '',
   user  => '',
   pass  => '',
);

### end config

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $mytrigger = $self->{mytrigger};

   return $self;
}

sub mysql_connect {
   unless ($dbh = DBI->connect("DBI:mysql:$sql{db}:$sql{host}", $sql{user}, $sql{pass}, {mysql_auto_reconnect => 1, mysql_enable_utf8 => 1})) {
      printf("[%s] !!! modules::%s: %s\n", scalar localtime, __PACKAGE__, $DBI::errstr);
      return 1;
   }
   else {
      return 0;
   }
}

sub mysql_disconnect {
   $dbh->disconnect;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, $who) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      return unless (main::isadmin($who));

      $target = $nick unless ($ischan);

      # cmds
      if ($cmd eq 'DEERKILL' || $cmd eq 'DK') {
         if ($args[0]) {
            unless (mysql_connect() == 0) {                                                                                                                    main::err($target, 'database error');
               return 1;                                                                                                                                    }

            my $rows = $dbh->do("DELETE FROM $sql{table} WHERE deer = ?", {}, "@args");

            mysql_disconnect();

            unless ($rows == 0) {
               printf("[%s] === modules::%s: deer killed [%s] on %s by %s\n", scalar localtime, __PACKAGE__, $args[0], $target, $nick);
               main::msg($target, '%d deer killed', $rows);
            }
            else {
                main::msg($target, 'no deers killed');
            }
         }
         else {
            main::hlp($target, 'syntax: DEERKILL(DK) <deer name>');
         }
      }
   }
}

1;
