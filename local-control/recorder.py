import threading
import time
from threading import Event

import hdr1
from log import log


class RecorderException(Exception):
    pass


class Recorder:
    _attempt_connection = None  # type: Event
    _device = None  # type: hdr1

    def __init__(self, venue_name, debug_enabled=False):
        """
        :type venue_name: str
        """
        self._venue_name = venue_name
        self._debug_enabled = debug_enabled
        self._device = None
        self._attempt_connection = threading.Event()
        self._connected = False
        self._device_ip_address = None

    def _connect(self):
        try:
            self._device = hdr1.Hdr1(self._device_ip_address, self._debug_enabled)
            self._attempt_connection.clear()
            self._connected = True
            log("Connected to HD-R1 " + self._device_ip_address)
            return True
        except hdr1.ConnectionError as e:
            log("Failed to connect to HD-R1: " + e.message)
            return False

    def _reconnect(self):
        self._connected = False
        self._attempt_connection.set()

    def maintain_connection(self, ip_address):
        self._device_ip_address = ip_address

        def loop():
            while 1:
                if not self._connect():
                    # if it did not connect immediately, wait a moment before trying again
                    time.sleep(5)
                    self._attempt_connection.set()
                self._attempt_connection.wait()

        t = threading.Thread(target=loop)
        t.daemon = True
        t.start()

    def _send_command(self, fn, *args):
        # attempt this unit of work twice
        for attempt in range(1, 3):
            try:
                return fn(*args)
            except hdr1.ConnectionError:
                # if we're disconnected, reconnect
                self._reconnect()
                # wait a moment for it to reconnect and try again
                time.sleep(2)
            except hdr1.InvalidArgumentException as e:
                # if the option was invalid, fail immediately, it's not going to work next time
                raise RecorderException(e.message)
        else:
            raise RecorderException("Failed after 2 attempts")

    def get_parameter(self, parameter):
        # type: (str) -> str
        # if we know we're disconnected, fail immediately
        if self._connected:
            return self._send_command(self._device.get_parameter, parameter)
        raise RecorderException("Not connected")

    def set_parameter(self, parameter, option):
        # type: (str, str) -> str
        # if we know we're disconnected, fail immediately
        if self._connected:
            return self._send_command(self._device.set_parameter, parameter, option)
        raise RecorderException("Not connected")

    def get_transport(self):
        return self.get_parameter("Transport")

    def stop_device_safely(self):
        transport = self.get_transport()
        if transport == "Record":
            raise RecorderException("ACTIVE RECORDING")
        elif transport == "No Media":
            raise RecorderException("NO REC MEDIA")
        elif transport == "Stop":
            return "Already stopped"

        return self.set_parameter("Transport", "Stop")

    def set_default_parameters(self):
        log("Setting default parameters")
        self.stop_device_safely()

        defaults = {
            "Media": "CF",
            "Auto Track": "512 MB",
            "Input Source": "Analog/Mic",
            "Channels": "Mono Left",
            "File Format": "MP3",
            "Mono MP3 Bit Rate": "128 kbps",
            "MP3 Sample Rate": "48 kHz",
            "Time Display": "Event Elapsed",
        }

        for parameter, option in defaults.iteritems():
            self.set_parameter(parameter, option)

        return "Done"

    def prepare_record(self, event_id):
        # type: (str) -> bool
        file_base_name = str(self._venue_name + "-" + event_id + "-")
        log("Preparing record: " + file_base_name)

        self.stop_device_safely()
        self.set_parameter("Audio File Base Name", file_base_name)
        self.set_parameter("Transport", "Monitor")
        log("Device ready to record")

        return True
