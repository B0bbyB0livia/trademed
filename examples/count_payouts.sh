#!/bin/bash

# example script that can be called from cron - count_payouts.sh >/dev/null 2>&1

# cd to location of docker-compose.yml
cd /home/rails/docker/

# docker-compose outputs CR character which breaks bash.
# the "Removing ..." text is shown on stderr.
# -T parameter required when running under cron otherwith no stdout produced.
declare -i RESULT=$(/usr/local/bin/docker-compose run -T --rm trademed rails r  'CountPayoutsJob.perform_now' | tr -d '\015')
if [ $RESULT -gt 0 ]; then
  mail -s "new payout $RESULT" email@example.com < /dev/null
fi
