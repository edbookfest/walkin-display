#!/usr/bin/python2.7
import binascii
import os
import sys


class Ba63Vfd:
    NUMBER_CHARS_PER_LINE = 20
    NUMBER_LINES = 2
    SIZE_BUFFER_MAX = 32
    SIZE_MESSAGE_MAX = 29

    S_MARK_START = b'\x02\x00'
    S_CLEAR = b'\x1B\x5B\x32\x4A'
    S_CLEAR_LINE = b'\x1B\x5B\x30\x4B'
    S_CURSOR = {
        1: b'\x1B\x5B\x31\x3B\x31\x48',
        2: b'\x1B\x5B\x32\x3B\x31\x48'
    }

    S_SET_CHARSET = b'\x1B\x52\x31'
    S_CHARSET_GB = b'\x1B\x52\x03'

    S_CONFIG_REQ = b'\x21\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'

    S_SELF_TEST = b'\x1B\x5B\x30\x63'
    S_TEST_REQ = b'\x00\x10\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    S_STATUS_REQ = b'\x00\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    S_RESET_REQ = b'\x00\x40\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'

    def __init__(self, fs_path, debug_enabled=False):
        self.fs_path = fs_path
        self._fd = os.open(fs_path, os.O_RDWR | os.O_NONBLOCK)
        self._debug_enabled = debug_enabled

    def _package(self, data):
        return self.S_MARK_START + bytes(chr(len(data))) + bytes(data)

    def _write_raw(self, data):
        if self._debug_enabled:
            print >> sys.stderr, "BA63: " + binascii.b2a_hex(data)
        os.write(self._fd, data)

    def _write(self, data):
        self._write_raw(self._package(data))

    def clear_screen(self):
        self._write(self.S_CLEAR)

    def clear_line_from_cursor(self):
        self._write(self.S_CLEAR_LINE)

    def cursor_to_start_of_line(self, line_no):
        self._write(self.S_CURSOR[line_no])

    def write_line(self, line_no, msg, clear_remaining_line=True):
        msg = msg[:20]
        self.cursor_to_start_of_line(line_no)
        self._write(msg)
        if clear_remaining_line and len(msg) < 20:
            self.clear_line_from_cursor()

    def test(self):
        self.cursor_to_start_of_line(1)
        self._write(b'\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB')
        self.cursor_to_start_of_line(2)
        self._write(b'\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB\xDB')
