#!/usr/bin/env python3
import struct
import os
class Station():
    def __init__(self, name, url):
        self.name = name
        self.url  = url
        self.playing = False

    def handle_key_event(self, code):
        if code:
            with open('/root/current_radio_station', 'r') as f:
                curr_station = f.read()
            with open('/root/current_radio_station', 'w') as f:
                f.write(self.url if curr_station != self.url else "")
            with open('/root/current_radio_station', 'r') as f:
                curr_station = f.read()
            print("Current station is now [{}]".format(curr_station))

class Command():
    def __init__(self, name, command):
        self.name    = name
        self.command = command

    def handle_key_event(self, code):
        if code:
            print("Executing {}".format(self.command))
            os.system(self.command)


CURRENT_STATION=None

ACTIONS = {
#Stations
    0x100 : Station('radio1', 'http://icecast.vrtcdn.be/radio1-high.mp3'),
    0x101 : Station('radio2 antwerpen', 'http://icecast.vrtcdn.be/ra2ant-high.mp3'),
    0x102 : Station('klara', 'http://icecast.vrtcdn.be/klara-high.mp3'),
    0x103 : Station('stubru', 'http://icecast.vrtcdn.be/stubru-high.mp3'),
    0x104 : Station('mnm','http://icecast.vrtcdn.be/mnm-high.mp3'),
#Commands
    0x105 : Command('volume_up', 'mpc volume +5'),
    0x106 : Command('volume_down', 'mpc volume -5'),
}

with open('/dev/input/event0', 'rb') as input:
    while True:
        (sec, usec, type, code, value) = \
            struct.unpack_from('@IIHHI', input.read(16))
        if code in ACTIONS:
            action = ACTIONS[code]
            action.handle_key_event(value)
