Walk-In
=======

####The walk-in player is designed to show a variety of dynamic content as the audience enters and leaves the venue for an event.

Additionally it can be forced to display an 'event slide' with the titles, credits, branding for the event.

[![Import](https://cdn.infobeamer.com/s/img/import.png)](https://info-beamer.com/use?url=https://github.com/edbookfest/walkin-display.git)

## Content

### Walk-In playlist

Random photos
-------------

Add a selection of photos to this module to have it select a different one randomly when it is called in the walk-in playlist.

This can be used to show a rotating selection of photos from around the festival to keep the walk-in sequences dynamic and interesting.

These should be at the same resolution as the output (1920x1080) and ideally in JPEG format.

Sponsor images
--------------

Create a playlist for each 'sponsored event' with the relevent event ID and the order the images should be played back. 

Create a playlist for every sponsored event and 

These should be at the same resolution as the output (1920x1080).

Control
-------
The walk-in player accepts 2 commands to control it's behaviour remotely by the technical operator.

`walkin/show_event_slide:true` to force it to display the 'event slide'

`walkin/show_event_slide:false` to resume the walk-in/out playlist sequence

`walkin/eventid:xxxx` to select the conditional content for a specific event
