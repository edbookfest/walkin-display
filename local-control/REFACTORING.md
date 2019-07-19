Future refactoring
==================

Background
----------
There are a number of work-arounds and sub-optimal processes in this package which are governed by the currently 
available features of info-beamer hosted.

Input devices have only recently been added as a supported feature of info-beamer hosted.
In order to provide feedback to the operator without compromising the main production output that is visible to 
audiences we have had to integrate a 2-line VFD (Wincor Nixdorf BA63 USB) into this package.
Although the display presents as a standard USB HID device similar to input devices, it's not as generic a device as 
to allow the operating system to handle it as input devices are.


Issues
------
 * Info-beamer hosted OS (as at v10) does not contain `libusb.so` or `libhidapi.so` so wrappers and libraries utilising 
 these will not work for handling the device.

 * It is possible to write directly to the device at `/dev/hidraw*` but these devices are currently only read / 
 writable by root and outside of the sandbox.

 * Info-beamer package services can be run as root and outside of the sandbox however there appears to be a possible 
 bug where by the python egg cache is not configured properly / writable which is required to use the evdev package 
 that is bundled with the OS.


Detecting & connecting to the display
-------------------------------------
Without a wrapper around `hidapi` it is impossible to detect the presence of the display and it's filesystem device 
handle in an entirely efficient manner.
The current workaround involves polling and parsing `dmesg` output for the most recent messages from the kernel. The 
BA63 represents 2 USB devices and they appear to connect in a consistent order. 
The first device is purportedly used to flash new firmware and the second is the display itself. Unfortunately it's not 
possible to write the 'report status' command to every `/usb/hidraw*` device and listen for the correct response as 
writing anything to the first device seems to put it into an inoperable mode. 
So there is no way to concretely guarantee the device we have parsed from `dmesg` is a correctly working BA63. Fairly 
intensive testing on the current work-around shows it should behave reliably for production usage. 

If these libraries we're added to infobeamer-hosted OS or a more efficient work around is found it would be preferable. 
To limit the amount of polling of `dmesg` it will only poll on service start until a device is found and not again 
until the device has failed to be written to. This means it's not possible to detect device disconnection until an 
attempt to write to it is made, so a message may go missing before we can attempt to reconnect (however if the device 
has failed or been disconnected, it will never be displayed anyway).  


Writing to the display device
-----------------------------
Writing to the display without the use of a library is relatively trivial however on info-beamer hosted OS v10 the 
`/dev/hidraw*` devices are not accessible inside the sandbox or read/writable by any user except root.
It's possible to work around this by running the package service as root and without the sandbox by utilising the node 
config options in `node.json`. In order to apply a bit of damage limitation and reduce risk the service writing to the 
display is being run in such a manner while another service handling the rest of the functionality runs as normal. 
The 2 separate processes communicate with each other via XMLRPC bound to localhost.

Info-beamer are looking into adding the `/dev/hidraw*' devices into the declarable node permissions, however this will 
go through the testing branch for some time so will not be available immanently.

Additionally this work-around also works around a potential bug where the package service running as root is not able 
to access the python egg cache which is required to unpack the evdev library that the input devices require. 

This issue is being investigated and once resolved along with the permissions will allow the entire package to run as a 
single protected process and remove the need for XMLRPC simplifying things dramatically.
