package deerme;

use utf8;
use strict;
use warnings;

use DBI;

my $mytrigger;

my $dbh;
my %prevdeers;

### start config

my $deeritor = 'http://example.com/deeritor';

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

sub fetchdeer {
   my $deer   = shift || return;
   my $ucdeer = uc($deer);
   my ($stmt, @bind, $special, $creator);

   if ($ucdeer eq 'RANDOM') {
      $special = 1;
      $stmt = "SELECT creator,irccode,deer FROM $sql{table} ORDER BY RAND() DESC LIMIT 1";
   }
   elsif ($ucdeer eq 'LATEST') {
      $special = 1;
      $stmt = "SELECT creator,irccode,deer FROM $sql{table} ORDER BY date DESC LIMIT 1";
   }
   else {
      $stmt = "SELECT creator,irccode,deer FROM $sql{table} WHERE deer = ? ORDER BY id DESC LIMIT 1";
      @bind = $deer;
   }

   return 1 unless (mysql_connect() == 0);  
 
   my $result = $dbh->selectrow_arrayref($stmt, {}, @bind);
   
   mysql_disconnect();

   unless ($result) {
      return 0;
   }
   else {
      return @$result[0], @$result[1], @$result[2], $special;
   }
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   # cmds
   if ($msg =~ /^deer (.+)/) {
      my ($creator, $irccode, $deer, $special);
     
      if ((($creator, $irccode, $deer, $special) = fetchdeer($1)) == 1) {
         main::err($target, 'database error');
      }
      else {
         if ($creator) {
            printf("[%s] === modules::%s: Deer [%s] on %s for %s\n", scalar localtime, __PACKAGE__, $1, $target, $nick);

            main::msg($target, $irccode);
            main::msg($target, '%s by %s', $deer, $creator) if $special;

            $prevdeers{$target}{deer}    = $deer;
            $prevdeers{$target}{creator} = $creator;
         }
         else {
            main::msg($target, '404 Deer Not Found. Go to %s and create it.', $deeritor);
         }
      }
   }
   elsif (lc($msg) eq "$$mytrigger prevdeer") {
      main::msg($target, 'The previous deer to walk the earth was %s by %s', $prevdeers{$target}{deer}, $prevdeers{$target}{creator}) if exists $prevdeers{$target};
   }
}

1;
