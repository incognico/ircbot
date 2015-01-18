package deer;

use utf8;
use strict;
use warnings;

no warnings 'qw';

use DBI;

### start config

my @deerchans = qw(#deer #moredeer);
my $joindeer  = '#deer';
my $deeritor  = 'http://example.com/deeritor';
my $maxsearch = 20;

my %sql = (
   host  => '',
   db    => '',
   table => '',
   user  => '',
   pass  => '',
);

### end config

my $dbh;
my %prevdeer;

### functions

sub mysql_connect {
   unless ($dbh = DBI->connect("DBI:mysql:$sql{db}:$sql{host}", $sql{user}, $sql{pass}, {mysql_auto_reconnect => 1, mysql_enable_utf8 => 1})) {
      return 1;
   }
   else {
      return 0;
   }
}

sub mysql_disconnect {
   $dbh->disconnect;
}

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   return $self;
}

sub countdeer {
   return 1 unless (mysql_connect() == 0);

   my $result = $dbh->selectrow_arrayref("SELECT count(*) as cnt FROM $sql{table}", {});

   mysql_disconnect();

   unless ($result) {
      return 2;
   }
   else {
      return 0, @$result[0];
   }
}

sub fetchdeer {
   my $deer   = shift;
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
      return 2;
   }
   else {
      return 0, @$result[0], @$result[1], @$result[2], $special;
   }
}

sub killdeer {
   my $deer = shift;

   return 1 unless (mysql_connect() == 0);

   my $rows = $dbh->do("DELETE FROM $sql{table} WHERE deer = ?", {}, $deer);

   mysql_disconnect();

   unless (defined $rows) {
      return 2;
   }
   else {
      return 0, $rows;
   }
}

sub searchdeer {
   my $search = shift;
   my $stmt   = "SELECT deer FROM $sql{table} WHERE deer LIKE ? ORDER BY id DESC LIMIT ?";
   my @bind   = ("%$search%", $maxsearch);

   return 1 unless (mysql_connect() == 0);

   my $result = $dbh->selectall_arrayref($stmt, {}, @bind);

   mysql_disconnect();

   if (@$result) {
      my ($count, $output) = scalar(@$result);

      $output .= $_->[0] . ', ' for (@$result);

      return 0, $count, substr($output, 0, -2);
   }
   else {
      return 2;
   }
}

### hooks

sub on_join {
   my ($self, $chan, $nick, undef, undef, undef) = @_;

   return if ($chan ne $joindeer);

   my ($ret, $creator, $irccode, $deer, $special) = fetchdeer('random');

   if ($ret == 1) {
      main::msg($chan, 'Hello %s, I was hit by a car :(', $nick);
   }
   else {
      main::msg($chan, 'Hello %s, have a seat and a deer:', $nick);
      main::msg($chan, $irccode);
      
      $prevdeer{$chan}{deer}    = $deer;
      $prevdeer{$chan}{creator} = $creator;
   }
}

sub on_privmsg {
   my ($self, $target, $msg, undef, undef, undef, undef, $who) = @_;

   return unless ($target ~~ @deerchans);

   my @args = split(' ', $msg);
   my $cmd  = uc(shift(@args));

   if ($cmd eq 'DEER') {
      my ($ret, $creator, $irccode, $deer, $special) = fetchdeer($args[0] ? "@args" : 'random');

      if ($ret == 1) {
         main::msg($target, 'deer: database error');
      }
      elsif ($ret == 2) {
         main::msg($target, '404 Deer Not Found. Go to %s and create it.', $deeritor);
      }                                                                                                                                               else {
         main::msg($target, $irccode);
         main::msg($target, q{'%s'%s}, $deer, $creator eq 'You' || $creator eq 'n/a' ? '' : " by $creator") if ($special);

         $prevdeer{$target}{deer}    = $deer;
         $prevdeer{$target}{creator} = $creator;
      }
   }
   elsif ($cmd eq 'DEERSEARCH') {
      if (length($args[0]) < 2) {
         main::msg($target, 'deerearch: specify 2 or more characters');
      }
      else {
         my ($ret, $count, $deertring) = searchdeer($args[0]);

         if ($ret == 1) {
            main::msg($target, 'deerearch: database error');
         }
         elsif ($ret == 2) {
            main::msg($target, 'deerearch: no result');
         }
         else {
            unless ($count) {
               main::msg($target, 'no deer');
            }
            elsif ($count == 1) {
               main::msg($target, 'one happy deer: %s', $deertring);
            }
            elsif ($count >= $maxsearch) {
                main::msg($target, 'too many deer, have some: %s', $deertring);
            }
            else {
               main::msg($target, '%u deer: %s', $count, $deertring);
            }
         }
      }
   }
   elsif ($cmd eq 'DEERKILL') {
      return unless(main::isadmin($who));

      my ($ret, $killed) = killdeer($args[0]);

      if ($ret == 1) {
         main::msg($target, 'deerkill: database error');
      }
      elsif ($ret == 2) {
         main::msg($target, 'no deer killed');
      }
      else {
         main::msg($target, '%d deer killed', $killed);
      }
   }
   elsif ($cmd eq 'DEERCOUNT') {
      my ($ret, $count) = countdeer();

      if ($count == 1) {
         main::msg($target, 'deercount: database error');
      }
      elsif ($count == 2) {
         main::msg($target, 'deercount: no result');
      }
      else {
         main::msg($target, 'there are %u deer', $count);
      }
   }
   elsif ($cmd eq 'PREVDEER') {
      main::msg($target, q{'%s'%s}, $prevdeer{$target}{deer}, $prevdeer{$target}{creator} eq 'You' || $prevdeer{$target}{creator} eq 'n/a' ? '' : " by $prevdeer{$target}{creator}") if (exists $prevdeer{$target});
   }
}

1;
