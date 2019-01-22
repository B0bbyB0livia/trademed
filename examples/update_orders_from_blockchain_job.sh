#!/bin/bash

# crontab entry example:
# */5 * * * *   SCRIPT=/path/to/script/update_orders_from_blockchain_job.sh; flock -n $SCRIPT.lock $SCRIPT

docker-compose run --rm trademed rails r 'UpdateOrdersFromBlockchainJob.perform_now'
