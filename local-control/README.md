Local control of walk-in display
================================

This package provides local control options for the 
['walk-in display package'](https://github.com/edbookfest/walkin-display) using a USB numeric keypad.


Background
----------
The [Edinburgh International Book Festival](https://www.edbookfest.co.uk/) uses 
[info-beamer hosted](https://info-beamer.com/) to run a 
['walk-in display package'](https://github.com/edbookfest/walkin-display) to display a playlist of images and videos
for every event as the audience enters and exits the venues of the festival.

During each event a static image [(event side)](https://github.com/edbookfest/event-slide-display) is displayed on stage
introducing the participants, sponsors and title of the event.

Historically the control of the display was done via an external application which sends relevant UDP packets to the 
info-beamer node.

This package allows the operator to control the display via a locally attached USB numeric keypad reducing the 
dependency on an external control plane.

In order to provide feedback to the operator this package also optionally supports a Wincor Nixdorf BA63 USB 2 line 
VFD.

Additionally the audio from the events are recorded using a Tascam HD-R1 solid state recorder which is controllable
across the network. This package optionally supports setting up the recorder and putting it into a state ready for each
event to be recorded.

**IMPORTANT** please ensure you are familiar with the work-arounds and compromises detailed in 
[REFACTORING.md](./REFACTORING.md) before using this package.


Operation
---------
**Load an event by ID:**

Press `*` followed by the event ID and then `ENTER`

*eg - To load event '1234':* 
`*` `1` `2` `3` `4` `ENTER`

**Display walk-in**

Press `+`

**Display event slide**

Press `-`


Setup
-----
