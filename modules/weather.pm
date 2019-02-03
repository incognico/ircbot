package weather;

use lib '/etc/perl';

use utf8;
use strict;
use warnings;

use DateTime::TimeZone;
use Geo::Coder::Google;
use JSON 'decode_json';
use LWP::Simple;
use Weather::YR;
use YAML::Tiny qw(LoadFile DumpFile);

my $myprofile;
my $mytrigger;

my $cfg;
my $changed;
my %userlocations;

my @winddesc = (
   'Calm',
   'Light air',
   'Light breeze',
   'Gentle breeze',
   'Moderate breeze',
   'Fresh breeze',
   'Strong breeze',
   'High wind',
   'Gale',
   'Strong gale',
   'Storm',
   'Violent storm',
   'Hurricane'
);

### start config

my $cfgname  = "$ENV{HOME}/.bot/%s/%s.yml"; # package name, profile name
my $gmapikey = '';
my $elevurl  = "https://maps.googleapis.com/maps/api/elevation/json?key=$gmapikey&locations=";

### end config

### functions

sub loadcfg {
   printf("[%s] === modules::%s: Loading config: %s\n", scalar localtime, __PACKAGE__, $cfg);
   %userlocations = LoadFile($cfg);
}

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $myprofile = $self->{myprofile};
   $mytrigger = $self->{mytrigger};

   $cfg = sprintf($cfgname, __PACKAGE__, $$myprofile);

   loadcfg() if (-e $cfg);

   return $self;
}

sub savecfg {
   if ($changed) {
      printf("[%s] === modules::%s: Saving config: %s\n", scalar localtime, __PACKAGE__, $cfg);
      DumpFile($cfg, %userlocations);
      $changed = 0;
   }
}

### hooks

sub on_ownquit {
   savecfg();
}

sub on_ping {
   savecfg();
}

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if (substr($msg, 0, 1) eq $$mytrigger) {
      my @args = split(' ', $msg);
      my $cmd = uc(substr(shift(@args), 1));

      #$target = $nick unless ($ischan);
      return unless ($ischan);

      # cmds 
      if ($cmd eq 'WEATHER' || $cmd eq 'W') {
         my ($loc, $lat, $lon);
         my $alt = 0;

         unless ($args[0]) {
            if (exists $userlocations{$nick}) {
               $loc = $userlocations{$nick}{loc};
               $lat = $userlocations{$nick}{lat};
               $lon = $userlocations{$nick}{lon};
               $alt = $userlocations{$nick}{alt};
            }
            else {
               main::msg($target, q{last location for %s is unknown, please specify one (%sw <location>) and I'll remember it.}, $nick, $$mytrigger);
               return;
            }
         }
         else {
            my $geo = Geo::Coder::Google->new(apiver => 3, language => 'en', key => $gmapikey);

            my $input;
            eval { $input = $geo->geocode(location => "@args") };

            unless ($input) {
               main::msg($target, 'no match');
               return;
            }

            $loc = $input->{formatted_address};
            $lat = $input->{geometry}{location}{lat};
            $lon = $input->{geometry}{location}{lng};

            my $json = get($elevurl . $lat . ',' . $lon);

            if ($json) {
               my $elevdata;
               eval { $elevdata = decode_json($json) };

               if ($elevdata->{status} eq 'OK') {
                  $alt = $elevdata->{results}->[0]->{elevation};
               }
            }
         
            $userlocations{$nick}{loc} = $loc;
            $userlocations{$nick}{lat} = $lat;
            $userlocations{$nick}{lon} = $lon;
            $userlocations{$nick}{alt} = $alt;

            $changed = 1;
         }

         printf("[%s] === modules::%s: Weather [%s] on %s by %s\n", scalar localtime, __PACKAGE__, $loc, $target, $nick);

         my $fcloc;
         eval { $fcloc = Weather::YR->new(lat => $lat, lon => $lon, msl => int($alt), tz => DateTime::TimeZone->new(name => 'Europe/Oslo'), lang => 'en') };

         unless ($fcloc) {
            main::msg($target, 'error fetching weather data, try again later');
            return;
         }

         my $fc = $fcloc->location_forecast->now;
            
         my $beaufort   = $fc->wind_speed->beaufort;
         my $celsius    = $fc->temperature->celsius;
         my $cloudiness = $fc->cloudiness->percent;
         my $fahrenheit = $fc->temperature->fahrenheit;
         my $fog        = $fc->fog->percent;
         my $humidity   = $fc->humidity->percent;
         my $symbol     = $fc->precipitation->symbol->text;
         my $winddir    = $fc->wind_direction->name;

         main::msg($target, "%s (%dm/%dft) :: %.1f°C / %.1f°F :: %s :: Cld: %u%% :: Hum: %u%% :: Fog: %u%% :: Wnd: %s from %s", $loc, int($alt), int($alt * 3.2808), $celsius, $fahrenheit, $symbol, $cloudiness, $humidity, $fog, $winddesc[$beaufort], $winddir);
      }
   }
}

sub on_unload {
   savecfg();
}

1;
