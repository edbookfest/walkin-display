import socket
import sys
from telnetlib import Telnet


class HdR1Exception(Exception):
    pass


class ConnectionError(HdR1Exception):
    pass


class InvalidArgumentException(HdR1Exception):
    pass


class MustBeInStopException(HdR1Exception):
    pass


class Hdr1:
    def __init__(self, host, debug_enabled=False):
        self._host = host
        self._debug_enabled = debug_enabled
        self._telnet = Telnet()
        self._connect()

    def _log(self, msg):
        print >> sys.stderr, "[LOCAL-CONTROL][HD-R1] %s" % msg

    def _debug(self, msg):
        if self._debug_enabled:
            self._log(msg)

    def _send(self, command):
        try:
            self._debug("SEND:" + command)
            self._telnet.write(command + "\n")
            response = self._telnet.read_eager()
            response += self._telnet.read_until("HD-R1>", 1).strip("HD-R1>")
            response = response.strip()
            self._debug("RECV:" + response)

            return str(response)
        except (socket.error, EOFError):
            raise ConnectionError("Connection failed")

    def _connect(self):
        try:
            self._telnet.open(self._host, 23, 1)

            r = self._telnet.read_until("HD-R1>", 1).strip()
            if r != "HD-R1>":
                raise ConnectionError("No prompt " + r)

            if self.set_parameter("login", "hd-r1") != "Login Succeeded":
                raise ConnectionError("Login failed")

        except (socket.error, EOFError):
            raise ConnectionError("Connection failed")

    def set_parameter(self, parameter, option):
        response = self._send(parameter + "=" + option)

        if response.strip(option)[-3:] == "???":
            raise InvalidArgumentException("Invalid option '%s' for parameter '%s'" % (option, parameter))

        if response.strip(option)[-1:] == "!":
            raise InvalidArgumentException("Invalid option '%s' for parameter '%s'" % (option, parameter))

        if response.strip(option)[-1:] == "*":
            raise MustBeInStopException("Recorder must be in stop")

        return response.strip()

    def get_parameter(self, parameter):
        response = self._send(parameter + "?")

        if response[-3:] == "???":
            raise InvalidArgumentException("Invalid parameter %s" % parameter)

        if response == "":
            raise ConnectionError("Gone away")

        parts = response.split("=")
        if parts[0] == parameter:
            return parts[1]

        return response.strip()
