package deersearch;

use utf8;
use strict;
use warnings;

use DBI;

my $mytrigger;

my $dbh;

### start config

my $maxresults = 20;

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
   unless ($dbh = DBI->connect("DBI:mysql:$sql{db}:$sql{host}", $sql{user}, $sql{pass}, {mysql_connect_timeout => 2, mysql_auto_reconnect => 1, mysql_enable_utf8 => 1})) {
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
   my ($self, $target, $msg, undef, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      # cmds
      if ($cmd eq 'DEERSEARCH' || $cmd eq 'DS') {
         if ($args[0]) {
            if (length("@args") < 2) {
               main::msg($target, 'specify 2 or more characters');
               return;
            }

            my $stmt = "SELECT deer FROM $sql{table} WHERE deer LIKE ? ORDER BY id DESC LIMIT ?";
            my @bind = ("%@args%", $maxresults);
            
            unless (mysql_connect() == 0) {
               main::err($target, 'database error');
               return 1;
            }

            my $result = $dbh->selectall_arrayref($stmt, {}, @bind);

            mysql_disconnect();

            if (@$result) {
               printf("[%s] === modules::%s: Deers queried [%s] on %s by %s\n", scalar localtime, __PACKAGE__, $args[0], $target, $nick);

               my $count = scalar(@$result);
               my $output;

               for (@$result) {
                  $output .= $_->[0] . ', ';
               }

               $output = substr($output, 0, -2);

               if ($count == 1) {
                  main::msg($target, 'one happy deer: %s', $output);
               }
               elsif ($count >= $maxresults) {
                   main::msg($target, 'too many deers, have some: %s', $output);
               }
               else {
                  main::msg($target, '%u deers: %s', $count, $output);
               }
            }
            else {
                main::msg($target, 'no deers');
            }
         }
         else {
            main::hlp($target, 'syntax: DEERSEARCH(DS) <search string>');
         }
      }
   }
}

1;
