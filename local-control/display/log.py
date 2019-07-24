#!/usr/bin/python2.7
import sys


def log(msg):
    print >> sys.stderr, "[LOCAL-CONTROL][DISPLAY] %s" % msg
