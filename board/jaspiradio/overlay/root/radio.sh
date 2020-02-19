#!/bin/sh

DO_RADIO=true
DO_BUTTONS=true

LOG="logger -s -t jaspiradio.radio"
#PINS= 11 12 13 15 16
GPIOS="17 18 22 23 24"

RADIO="radio1,http://icecast.vrtcdn.be/radio1-high.mp3
radio2antwerpen,http://icecast.vrtcdn.be/ra2ant-high.mp3
klara,http://icecast.vrtcdn.be/klara-high.mp3
stubru,http://icecast.vrtcdn.be/stubru-high.mp3
mnm,http://icecast.vrtcdn.be/mnm-high.mp3"

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

echo cmd=[${GPIO_STATE_CMD}]
GPIO_STATE=`${GPIO_STATE_CMD}`
echo $GPIO_STATE

while true; do
	GPIO_STATE_PREV=$GPIO_STATE
	GPIO_STATE=`${GPIO_STATE_CMD}`

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

	if [ "$SELECTED" -ge "0" ]; then
		idx=0
		for r in $RADIO; do
			if [ "$idx" -eq "$SELECTED" ]; then
				STATION_NAME=`echo $r|cut -d , -f 1`
				STATION_URL=`echo $r|cut -d , -f 2`
				${LOG} Acting on ${STATION_NAME}@${STATION_URL}
				if $DO_RADIO; then
					if [ "`mpc -f %file% current`" != ${STATION_URL} ]; then
						${LOG} Switching MPC to ${STATION_NAME}@${STATION_URL}
						mpc clear
						mpc add $STATION_URL
						mpc play
					else
						${LOG} Toggling MPC play/pause
						mpc toggle
					fi
				fi
			fi
			idx=$(( $idx + 2 ))
		done
	fi

	sleep 0.1
done
