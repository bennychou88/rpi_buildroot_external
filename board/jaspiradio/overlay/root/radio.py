#!/usr/bin/env python3
import struct
import mpd
import json
from pathlib import Path
from threading import Timer, Lock

# ACTIONS
class Station(dict):
    def __init__(self, name, uri):
        self['name'] = name
        self['uri']  = uri

    def handle_key_event(self, radio, value):
        if value:
            radio.update_state(station=self)

VOLUME_MIN=1
VOLUME_MAX=100
STATE_STORAGE_INTERVAL=1

REPEAT_DELAY_INIT=0.5
REPEAT_DELAY=0.01

STATE_FILE=Path('/root/radio_state.json')
STATE_DEFAULT={
    'station': None,
    'volume': 50
}

class VolumeControl(dict):
    def __init__(self, name, delta):
        self['name']  = name
        self['delta'] = delta
        self.timer = None

    def handle_key_event(self, radio, value):
        if value:
            radio.update_state(volume_delta = self['delta'])
            self.repeating=True
            self.timer = Timer(REPEAT_DELAY_INIT, self.repeat, (radio, ))
            self.timer.start()
        else:
            if self.timer:
                self.timer.cancel()
                self.timer = None
            self.repeating=False

    def repeat(self, radio):
        radio.update_state(volume_delta = self['delta'])
        if self.repeating:
            self.timer = Timer(REPEAT_DELAY, self.repeat, (radio, ))
            self.timer.start()

class Radio():
    def __init__(self, actions):
        self.actions = actions
        self.load_state()

        self.mpd_mux = Lock()
        self.client = mpd.MPDClient(use_unicode=True)
        self.client.connect("localhost", 6600)

        #timer_state initialised by ensure_state first call
        self.ensure_state(True, True)

    def load_state(self):
        if not STATE_FILE.exists():
            self.reset_state()

        try:
            with open(STATE_FILE, 'r') as f:
                self.state = json.load(f)
        except json.decoder.JSONDecodeError:
            self.reset_state()

    def store_state(self):
        with open(STATE_FILE, 'w') as f:
            json.dump(self.state, f)

    def reset_state(self):
        print("Creating state file [{}] with default state".format(STATE_FILE))
        with open(STATE_FILE, 'w') as f:
            json.dump(STATE_DEFAULT, f)
        self.state = STATE_DEFAULT

    def update_state(self, station=None, volume_delta=0):
        station_changed = False
        if station:
            station_changed = True
            if self.state['station'] == station:
                self.state['station'] = None
            else:
                self.state['station'] = station

        volume_changed = False
        if volume_delta:
            curvol = self.state['volume']
            if curvol + volume_delta > VOLUME_MAX:
                self.state['volume'] = VOLUME_MAX
            elif curvol + volume_delta < VOLUME_MIN:
                self.state['volume'] = VOLUME_MIN
            else:
                self.state['volume'] += volume_delta
            volume_changed = curvol != self.state['volume']

        if volume_changed or station_changed:
            self.store_state()

        self.ensure_state(station_changed, volume_changed)

    def ensure_state(self, ensure_station, ensure_volume):
        self.mpd_mux.acquire()
        if ensure_station:
            if self.state['station']:
                uri = self.state['station']['uri']
                cursong = self.client.currentsong()

                if not 'file' in cursong or cursong['file'] != uri:
                    self.client.clear()
                    self.client.add(uri)
                    self.client.play()
            else:
                self.client.clear()
                self.client.stop()

        if ensure_volume and self.state['station']:
            self.client.setvol(self.state['volume'])

        self.mpd_mux.release()

    def monitor_buttons(self):
        with open('/dev/input/event0', 'rb') as input:
            while True:
                (sec, usec, type, code, value) = \
                    struct.unpack_from('@IIHHI', input.read(16))
                if code in ACTIONS:
                    action = ACTIONS[code]
                    action.handle_key_event(self, value)

#Actions map keycodes to actions
ACTIONS = {
#Stations
    0x100 : Station('radio1', 'http://icecast.vrtcdn.be/radio1-high.mp3'),
    0x101 : Station('radio2 antwerpen', 'http://icecast.vrtcdn.be/ra2ant-high.mp3'),
    0x102 : Station('klara', 'http://icecast.vrtcdn.be/klara-high.mp3'),
    0x103 : Station('stubru', 'http://icecast.vrtcdn.be/stubru-high.mp3'),
    0x104 : Station('mnm','http://icecast.vrtcdn.be/mnm-high.mp3'),
#Commands
    0x105 : VolumeControl('volume up',   +1),
    0x106 : VolumeControl('volume down', -1),
}

if __name__=='__main__':
    r = Radio(ACTIONS)
    r.monitor_buttons()