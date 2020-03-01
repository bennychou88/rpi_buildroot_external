#!/bin/sh
CURR_STATION_STOR='/root/current_radio_station'
CURR_CMD='/root/current_command'

LOG="logger -s -t jaspiradio.radio"

ACTIONS="0x100,station,radio1,http://icecast.vrtcdn.be/radio1-high.mp3
0x101,station,radio2antwerpen,http://icecast.vrtcdn.be/ra2ant-high.mp3
0x102,station,klara,http://icecast.vrtcdn.be/klara-high.mp3
0x103,station,stubru,http://icecast.vrtcdn.be/stubru-high.mp3
0x104,station,mnm,http://icecast.vrtcdn.be/mnm-high.mp3
0x105,cmd,volume_up
0x106,cmd,volume_down"


DO_RADIO=true
DO_BUTTONS=true
DO_LED=true

LEDS=$(ls -d1 /sys/class/leds/station*)


if [ ! -f ${CURR_STATION_STOR} ]; then
  touch ${CURR_STATION_STOR}
fi

if [ ! -f ${CURR_CMD} ]; then
  touch ${CURR_CMD}
fi

#Turn off LED
if $DO_LED; then
  for l in $LED; do
    echo 0 > ${l}/brightness
  done
fi

if $DO_BUTTONS; then
  echo Starting button monitor
  /root/handle_buttons.py &
  echo monitor started
fi

# monitor state
while true; do
  # Make sure MPD state is up to date
  if $DO_RADIO; then
    CURR_STATION=`cat ${CURR_STATION_STOR}`

    # We want to be playing
    if [ "${CURR_STATION}" != "" ]; then
      TRIES=5

      # Gonna start station
      if $DO_LED; then
        if [ "`mpc|grep -o \\\\[playing]`" != '[playing]' ] ||
           [ "`mpc -f %file% current`" != "${CURR_STATION}" ]; then
           echo timer > ${LED}/trigger
           echo 20 > ${LED}/delay_on
           echo 20 > ${LED}/delay_off
           echo 1 > ${LED}/brightness
        fi
      fi

      while [ "`mpc|grep -o \\\\[playing]`" != '[playing]' ] ||
            [ "`mpc -f %file% current`" != "${CURR_STATION}" ]; do
        if [ "${TRIES}" -eq "0" ]; then
          echo Failed after trying a few times
          break
        fi
        TRIES=$(( $TRIES - 1 ))

        echo Activating MPC
        mpc clear
        mpc add ${CURR_STATION}
        mpc play
      done

      if ${DO_LED}; then
        echo none > ${LED}/trigger
        echo 1 > ${LED}/brightness
      fi

    #We want silence
    else

      if [ "`mpc|grep -o \\\\[playing]`" == '[playing]' ]; then
        echo Stopping MPC
        mpc stop
        if ${DO_LED}; then
          echo none > ${LED}/trigger
          echo 0 > ${LED}/brightness
        fi
      fi
    fi
  fi

  sleep 0.1
done
