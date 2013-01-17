package deerme;

use utf8;
use strict;
use warnings;

use DBI;
use SQL::Abstract;
use SQL::Abstract::Limit;

my $mytrigger;

my $dbh;
my %prevdeers;

### start config ###

my $deeritor = 'http://example.com/deeritor';

my %sql = (
   host  => '',
   db    => '',
   table => '',
   user  => '',
   pass  => '',
);

### end config ###

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

sub fetchdeer {
   my $deer = shift || return;
   my ($special, $creator, $sqlout);

   eval {
      my $sql = SQL::Abstract::Limit->new(limit_dialect => 'LimitXY');
      my $ucdeer = uc($deer);
      my ($stmt, @bind);

      mysql_connect();

      if ($ucdeer eq 'RANDOM') {
         $special = 1;
         ($stmt, @bind) = $sql->select($sql{table}, 'creator,irccode,deer', {}, \'RAND() DESC', 1);
      }
      elsif ($ucdeer eq 'LATEST') {
         $special = 1;
         ($stmt, @bind) = $sql->select($sql{table}, 'creator,irccode,deer', {}, \'date DESC', 1);
      }
      else {
         ($stmt, @bind) = $sql->select($sql{table}, 'creator,irccode', { deer => $deer }, \'id DESC', 1);
      }

      my $sth = $dbh->prepare($stmt);

      $sth->execute(@bind);

      if ($sth->rows == 0) {
         return;
      }
      else {
         $sqlout = $sth->fetch;
      }

      $sth->finish;
      mysql_disconnect();
   };

   if ($@) {
      chomp $@;
      warn "$@";
   }
   else {
      unless ($special) {
         return @$sqlout[0], @$sqlout[1], $deer, 0;
      }
      else {
         return @$sqlout[0], @$sqlout[1], @$sqlout[2], 1;
      }
   }
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   # cmds
   if ($msg =~ /^deer (.+)/) {
      my ($creator, $irccode, $deer, $special) = fetchdeer($1);

      if ($creator) {
         main::msg($target, $irccode);
         main::msg($target, "$deer by $creator") if $special;

         $prevdeers{$target}{deer} = $deer;
         $prevdeers{$target}{creator} = $creator;

         printf("[%s] === modules::%s: Deer [%s] on %s for %s\n", scalar localtime, __PACKAGE__, $1, $target, $nick) unless main::israwlog();
      }
      else {
         main::msg($target, "404 Deer Not Found. Go to $deeritor and create it.");
      }
   }
   elsif (lc($msg) eq "$$mytrigger prevdeer") {
      main::msg($target, "The previous deer to walk the earth was $prevdeers{$target}{deer} by $prevdeers{$target}{creator}") if exists $prevdeers{$target};
   }
}

1;
