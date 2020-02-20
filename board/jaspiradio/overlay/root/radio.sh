#!/bin/sh

LED='/sys/class/leds/led0'
CURR_STATION_STOR='./current_radio_station'
DO_RADIO=true
DO_BUTTONS=false
DO_LED=true

SCAN_TIMEOUT=0.1
LOG="logger -s -t jaspiradio.radio"
#PINS= 11 12 13 15 16
GPIOS="17 18 22 23 24"

RADIO="radio1,http://icecast.vrtcdn.be/radio1-high.mp3
radio2antwerpen,http://icecast.vrtcdn.be/ra2ant-high.mp3
klara,http://icecast.vrtcdn.be/klara-high.mp3
stubru,http://icecast.vrtcdn.be/stubru-high.mp3
mnm,http://icecast.vrtcdn.be/mnm-high.mp3"

if [ ! -f ${CURR_STATION_STOR} ]; then
  touch ${CURR_STATION_STOR}
fi

#Turn off LED
if $DO_LED; then
  echo 0 > ${LED}/brightness
fi

#Enable buttons and generate button read command
GPIO_STATE_CMD="cat "
for i in $GPIOS; do
  if $DO_BUTTONS; then
    echo Enabling GPIO $i;
    echo $i > /sys/class/gpio/export
    echo in > /sys/class/gpio/gpio$i/direction
    GPIO_STATE_CMD="${GPIO_STATE_CMD} /sys/class/gpio/gpio$i/value"
  else
    echo Faking GPIO $i;
    GPIO_STATE_CMD="${GPIO_STATE_CMD} ./gpio_$i"
    echo 0 > ./gpio_$i
  fi
done


# Check buttons and modify state as needed
GPIO_STATE=`${GPIO_STATE_CMD}`
while true; do
  GPIO_STATE_PREV=$GPIO_STATE
  GPIO_STATE=`${GPIO_STATE_CMD}`

  # Check button state and compute selected stream
  SELECTED=-1
  idx=0
  for i in $GPIOS; do
    if [ "${GPIO_STATE:$idx:1}" -ne "${GPIO_STATE_PREV:$idx:1}" ]; then
      if [ "${GPIO_STATE:$idx:1}" -eq "0" ]; then
        SELECTED=$idx
      fi
    fi
    idx=$(( $idx + 2 ))
  done

  # We have a button push, act on it
  if [ "$SELECTED" -ge "0" ]; then
    idx=0
    #Find selected radio station
    for r in $RADIO; do
      if [ "$idx" -eq "$SELECTED" ]; then
        STATION_NAME=`echo $r|cut -d , -f 1`
        STATION_URL=`echo $r|cut -d , -f 2`
        break
      fi
      idx=$(( $idx + 2 ))
    done

    ${LOG} Acting on ${STATION_NAME}@${STATION_URL}
    # Update file containing radio state
    if [ "`cat ${CURR_STATION_STOR}`" != "${STATION_URL}" ]; then
      echo Updating station URL to ${STATION_URL}
      echo ${STATION_URL} > ${CURR_STATION_STOR}
    else
      echo Stopping station ${STATION_URL}
      echo > ${CURR_STATION_STOR}
    fi
  fi

  # Make sure MPD state is up to date
  if $DO_RADIO; then
    CURR_STATION=`cat ${CURR_STATION_STOR}`

    # We want to be playing
    if [ "${CURR_STATION}" != "" ]; then
      TRIES=5
      while [ "`mpc|grep -o \\\\[playing]`" != '[playing]' ] ||
            [ "`mpc -f %file% current`" != "${CURR_STATION}" ]; do
        if [ "${TRIES}" -eq "0" ]; then
          echo Failed after trying a few times
          break
        fi
        TRIES=$(( $TRIES - 1 ))

        if $DO_LED; then
          echo timer > ${LED}/trigger
          echo 50 > ${LED}/delay_on
          echo 100 > ${LED}/delay_off
          echo 1 > ${LED}/brightness
        fi

        echo Activating MPC
        mpc clear
        mpc add ${CURR_STATION}
        mpc play
      done

      if ${DO_LED}; then
        echo 0 > ${LED}/brightness
      fi

    #We want silence
    else

      if [ "`mpc|grep -o \\\\[playing]`" == '[playing]' ]; then
        echo Stopping MPC
        mpc stop
      fi
    fi
  fi

  sleep ${SCAN_TIMEOUT}
done
