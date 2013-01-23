package deersearch;

use utf8;
use strict;
use warnings;

use DBI;
use SQL::Abstract;
use SQL::Abstract::Limit;

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
   $dbh = DBI->connect("DBI:mysql:$sql{db}:$sql{host}", $sql{user}, $sql{pass},
          {RaiseError => 1, mysql_auto_reconnect => 1, mysql_enable_utf8 => 1});
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
               main::err($target, 'specify 2 or more characters');
               return;
            }

            my $sqlo = new SQL::Abstract::Limit(limit_dialect => 'LimitXY');
            my @where = (
               {
                  deer => {
                     like => sprintf('%%%s%%', "@args"),
                  },
               },
            );

            mysql_connect();

            my ($stmt, @bind) = $sqlo->select($sql{table}, 'deer', \@where, \'id DESC', $maxresults);
            my $sth = $dbh->prepare($stmt);
            my $result;

            $sth->execute(@bind);
            $result = $sth->fetchall_arrayref({});
            $sth->finish;

            mysql_disconnect();

            if (@$result) {
               printf("[%s] === modules::%s: deers queried [%s] on %s by %s\n", scalar localtime, __PACKAGE__, $args[0], $target, $nick);

               my $count = scalar(@$result);
               my $output;

               for (@$result) {
                  $output .= $_->{deer} . ', ';
               }

               if ($count == 1) {
                  main::msg($target, 'one happy deer: %s', substr($output, 0, -2));
               }
               elsif ($count >= $maxresults) {
                   main::msg($target, 'too many deers, have some: %s', substr($output, 0, -2));
               }
               else {
                  main::msg($target, '%u deers: %s', $count, substr($output, 0, -2));
               }
            }
            else {
                main::msg($target, 'no deers');
            }
         }
         else {
            main::err($target, 'syntax: DEERSEARCH(DS) <search string>');
         }
      }
   }
}

1;
