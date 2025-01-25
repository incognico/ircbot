package ai;

use utf8;
use strict;
use warnings;

use OpenAI::API::Request::Chat;
use Encode::Simple qw(encode_utf8_lax decode_utf8_lax);

my $config = OpenAI::API::Config->new(
   api_base => 'https://api.x.ai/v1',
   api_key  => 'xai-xxx',
   timeout  => 60,
   retry    => 3,
   sleep    => 2,
);

my ($gptres, $chat);

### functions

sub new {
   my ($package, %self) = @_;
   my $self = bless(\%self, $package);

   $chat = OpenAI::API::Request::Chat->new(
      config => $config,
      model  => 'grok-2',
      max_tokens => 512,
      messages => [
         { role => 'system', content => 'Du heißt Eloquence. Du duzt. Ersetze alle adjektive durch ihre eloquenteren Synonyme. Du bist im IRC-Chat im Rizon in #k' },
      ],
   );

   eval { $gptres = $chat->send(); };

   return $self;
}

### hooks

sub on_privmsg {
   my ($self, $target, $msg, $ischan, $nick, undef, undef, undef) = @_;

   if ($msg =~ /^(?:YouTube|TubeYou): (.+)/) {
      return unless ($ischan && $target eq '#k');
      
      eval { $gptres = $chat->send_message(decode_utf8_lax($1)); };

      main::msg($target, '%s: %s', $nick, $$gptres{choices}[0]{message}{content}) unless $@;
   }
}

1;
