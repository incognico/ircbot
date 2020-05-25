package youtube;

use utf8;
use strict;
use warnings;

use Encode::Simple qw(encode_utf8 decode_utf8);
use JSON 'decode_json';
use LWP::UserAgent 'get';

my $myprofile;
my $mytrigger;

### start config

my $key = '';
my $url = 'https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics&key=' . $key;

my %categories = (
    1 => 'Film & Animation',
    2 => 'Autos & Vehicles',
   10 => 'Music',
   15 => 'Pets & Animals',
   17 => 'Sports',
   18 => 'Short Movies',
   19 => 'Travel & Events',
   20 => 'Gaming',
   21 => 'Videoblogging',
   22 => 'People & Blogs',
   23 => 'Comedy',
   24 => 'Entertainment',
   25 => 'News & Politics',
   26 => 'Howto & Style',
   27 => 'Education',
   28 => 'Science & Technology',
   29 => 'Nonprofits & Activism',
   30 => 'Movies',
   31 => 'Anime/Animation',
   32 => 'Action/Adventure',
   33 => 'Classics',
   34 => 'Comedy',
   35 => 'Documentary',
   36 => 'Drama',
   37 => 'Family',
   38 => 'Foreign',
   39 => 'Horror',
   40 => 'Sci-Fi/Fantasy',
   41 => 'Thriller',
   42 => 'Shorts',
   43 => 'Shows',
   44 => 'Trailers',
); 

my %ignore = (
   all => {
      profilename => {
         nickname => 1,
      },
   },
   announce => {
      profilename => {
         '#channelname' => 1,
      },
   },
);

my %pause;

### end config

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $myprofile = $self->{myprofile};
   $mytrigger = $self->{mytrigger};

   return $self;
}

sub duration {
   my $sec = shift;

   return '?' unless ($sec);

   my @gmt = gmtime($sec);

   return ($gmt[7] ?  $gmt[7]                                          .'d' : '').
          ($gmt[2] ? ($gmt[7]                       ? ' ' : '').$gmt[2].'h' : '').
          ($gmt[1] ? ($gmt[7] || $gmt[2]            ? ' ' : '').$gmt[1].'m' : '').
          ($gmt[0] ? ($gmt[7] || $gmt[2] || $gmt[1] ? ' ' : '').$gmt[0].'s' : '');
}

sub tsep {
   my $unformatted = shift || 0;
   my $formatted = reverse(join('.', (reverse $unformatted) =~ /([0-9]{1,3})/g));
   return $formatted;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, $user, $host, undef) = @_;

   return unless ($ischan);
   return if (exists $ignore{all}{$$myprofile}{$nick});

   if ($msg =~ m!youtube\.com/.+[?&]v=([\w-]+)! || $msg =~ m!youtu\.be/([\w-]+)!) {
      my $id = $1;
      
      if (exists $pause{$$myprofile}{$target}{$id}) {
         if ((time - $pause{$$myprofile}{$target}{$id}) < 300) {
            return;
         }
         else {
            delete $pause{$$myprofile}{$target}{$id};
         }
      }
      $pause{$$myprofile}{$target}{$id} = time;
      
      my $ua = LWP::UserAgent->new;
      my $yt = $ua->get($url . '&id=' . $id);

      if ($yt->is_success) {
         my $json = decode_json($yt->decoded_content);

         if ($json->{pageInfo}{totalResults} && $json->{items}[0]) {

            #my $comments = $json->{items}[0]{statistics}{commentCount} ? tsep($json->{items}[0]{statistics}{commentCount}) : 0;
            my $dislikes = $json->{items}[0]{statistics}{dislikeCount} ? $json->{items}[0]{statistics}{dislikeCount} : 0;
            my $likes    = $json->{items}[0]{statistics}{likeCount} ? $json->{items}[0]{statistics}{likeCount} : 0;
            my $playtime = $json->{items}[0]{contentDetails}{duration};
            my $title    = $json->{items}[0]{snippet}{title};
            my $date     = $1 if ($json->{items}[0]{snippet}{publishedAt} =~ /^(\d{4}-\d\d-\d\d)T/);
            my $views    = $json->{items}[0]{statistics}{viewCount} ? tsep($json->{items}[0]{statistics}{viewCount}) : 0;

            return if ($title =~ m!youtube\.com/.+[?&]v=([\w-]+)! || $title =~ m!youtu\.be/([\w-]+)!);

            $title =~ s/(\s|\R)+/ /gn;

            printf("[%s] === modules::%s: YouTube video posted [%s] on %s by %s\n", scalar localtime, __PACKAGE__, $id, $target, $nick);

            my $rating = $likes+$dislikes > 0 ? sprintf('%.f%%', $likes/($likes+$dislikes)*100) : 'n/a';

            my $length;
            $playtime =~ s/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/$length = ($1 ? $1 * 60 * 60 : 0) + ($2 ? $2 * 60 : 0) + ($3 ? $3 : 0)/eg;

            $views = '301+' if ($views eq '301');

            #main::msg($target, 'Title: %s :: Duration: %s :: Comments: %s :: Views: %s :: Rating: %s', $title, duration($length), $comments, $views, $rating) unless (exists $ignore{announce}{$$myprofile}{$target});
            main::msg($target, '%s :: %s :: %s :: %s views :: rated %s', encode_utf8("\N{U+200E}".$title), duration($length), $date, $views, $rating);

         }
      }
      else {
         printf("[%s] === modules::%s: YouTube API error: %s (video [%s] on %s by %s)\n", scalar localtime, __PACKAGE__, $yt->status_line, $id, $target, $nick);
      }
   }
}

1;
