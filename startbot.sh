#!/bin/sh

while true
do
   perl $HOME/irc/bot/bot.pl -p $1
   echo "!!! Bot exited"
   sleep 15
done
