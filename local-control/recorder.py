import threading
import time

import hdr1
from log import log


class RecorderException(Exception):
    pass


class Recorder:
    _device = None  # type: hdr1

    def __init__(self, venue_name, debug_enabled=False):
        """
        :type venue_name: str
        """
        self._venue_name = venue_name
        self._debug_enabled = debug_enabled
        self._device = None

    def connect(self, ip_address):
        def do_work():
            while 1:
                if self._device is None:
                    try:
                        self._device = hdr1.Hdr1(ip_address, self._debug_enabled)
                        log("Connected to HD-R1 " + ip_address)
                    except hdr1.ConnectionError:
                        log("Failed to connect to HD-R1")
                time.sleep(10)

        t = threading.Thread(target=do_work)
        t.daemon = True
        t.start()

    def get_parameter(self, parameter):
        # type: (str) -> str
        if self._device:
            try:
                return self._device.get_parameter(parameter)

            except hdr1.ConnectionError as e:
                self._device = None
                raise RecorderException(e.message)

            except hdr1.InvalidArgumentException as e:
                raise RecorderException(e.message)

        raise RecorderException("Not connected")

    def set_parameter(self, parameter, option):
        # type: (str, str) -> str
        if self._device:
            try:
                return self._device.set_parameter(parameter, option)

            except hdr1.ConnectionError as e:
                self._device = None
                raise RecorderException(e.message)

            except (hdr1.InvalidArgumentException, hdr1.MustBeInStopException) as e:
                raise RecorderException(e.message)

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
