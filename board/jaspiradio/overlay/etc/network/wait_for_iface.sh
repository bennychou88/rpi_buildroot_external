#!/bin/sh

ATTEMPTS=1000
while [ ! -f /sys/class/net/$1/dev_id ] && [ "$ATTEMPTS" -gt "0" ]; do
  ATTEMPTS=$(( $ATTEMPTS - 1 ))
done

if [ "$ATTEMPTS" -eq "0" ]; then
  echo failed to find $1
else
  echo $1 showed up
fi