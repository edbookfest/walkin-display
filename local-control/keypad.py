#!/usr/bin/python2.7
import sys
from select import select

import evdev


class Keypad:

    def __init__(self, debug_enabled=False):
        self._devices = {}
        self._debug_enabled = debug_enabled
        self._debug("Init keypad")

    def _log(self, msg):
        print >> sys.stderr, "[LOCAL-CONTROL][KEYPAD] %s" % msg

    def _debug(self, msg):
        if self._debug_enabled:
            self._log(msg)

    def valid_keys(self):
        return [
            "KEY_KP0",
            "KEY_KP1",
            "KEY_KP2",
            "KEY_KP3",
            "KEY_KP4",
            "KEY_KP5",
            "KEY_KP6",
            "KEY_KP7",
            "KEY_KP8",
            "KEY_KP9",
            "KEY_TAB",
            "KEY_KPASTERISK",
            "KEY_KPMINUS",
            "KEY_KPPLUS",
            "KEY_KPENTER",
            "KEY_HOMEPAGE",
            # "KEY_BACKSPACE",
            # "KEY_SPACE",
            # "KEY_KPDOT",
            # "KEY_NUMLOCK",
            "KEY_KPSLASH",
            # "KEY_MAIL",
            # "KEY_CALC"
        ]

    def _get_key_value(self, key):
        values = {
            'KEY_KP0': 0,
            'KEY_KP1': 1,
            'KEY_KP2': 2,
            'KEY_KP3': 3,
            'KEY_KP4': 4,
            'KEY_KP5': 5,
            'KEY_KP6': 6,
            'KEY_KP7': 7,
            'KEY_KP8': 8,
            'KEY_KP9': 9,
        }
        if key in values:
            return values[key]
        else:
            return key

    def _update_devices(self):
        new = set(evdev.list_devices("/dev/input/"))
        old = set(self._devices.keys())

        for device_name in new - old:
            device = evdev.InputDevice(device_name)
            self._devices[device_name] = device
            self._log("Found input device: " + device_name)

        for device_name in old - new:
            self._log(device_name + " disconnected")
            del self._devices[device_name]

    def monitor_input(self):
        self._update_devices()
        read, write, excep = select(self._devices.values(), [], [], 5)
        for device in read:
            try:
                for event in device.read():
                    if event.type == evdev.ecodes.EV_KEY and event.value == 0:
                        key = str(evdev.ecodes.KEY[event.code])
                        if key in self.valid_keys():
                            self._debug("Keypress: " + key)
                            return self._get_key_value(key)
                        else:
                            self._debug("Ignoring keypress: " + key)
            except IOError:
                # device disconnected
                pass
