class_name VanInteriorSize
extends RefCounted
## One source for the van's back compartment size (the cab is separate); the shell scripts read these.

## Side wall half width at the floor (meters).
const BOTTOM_HALF := 3.39
## Side wall half width at the roof line.
const TOP_HALF := 2.96
## Unused by the side wall now (it is straight); the raider wall still reads it.
const BOW := 0.25
## Side wall height above the floor.
const WALL_HEIGHT := 4.00
## Cab end of the back compartment (fixed; the front wall's cab-side face is 0.05 further forward).
const FRONT_Z := -4.70
## Rear end of the back compartment.
const REAR_Z := 6.58
## Z centre of the back compartment: the procedural pieces are built around it.
const CENTER_Z := 0.94
## Back compartment length (REAR_Z - FRONT_Z).
const LENGTH := 11.28
## Floor deck width and length (a little over the wall span).
const FLOOR_WIDTH := 6.72
const FLOOR_LENGTH := 11.48
## Ceiling vault width (the van_shell.tscn override value) and the script-default width.
const CEILING_SPAN_X := 5.71
const CEILING_SPAN_X_DEFAULT := 6.61
## Ceiling edge height: script default, and the van_shell.tscn override value.
const CEILING_EDGE := 3.93
const CEILING_EDGE_SHELL := 3.97
## Bulkhead half width and edge height.
const BULKHEAD_HALF := 3.30
const BULKHEAD_EDGE := 3.93
