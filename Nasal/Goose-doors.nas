# Grumman Goose
#
# Custom routines for door support
#
# Gary Neely aka 'Buckaroo'
#
# Like lights, doors are rigged for multiplayer viewing, so the property used for animation
# is a generic MP property rather than the control prop setup by the aircraft.door function.
# A listener watches for changes the control property and copies that to the MP prop for
# the actual animation. A better method to do this stuff is always welcome.
#
# And thanks to Syd and Melchior for the better method. The listener is now replaced
# by an alias assigned in the master Goose-set file.


var door_bow = aircraft.door.new("/controls/door-bow", 1);

var Goose_door_bow	= props.globals.getNode("/controls/door-bow/position-norm");
var Goose_MP_door_bow	= props.globals.getNode("/sim/multiplay/generic/float[0]");


var door_right = aircraft.door.new("/controls/door-right", 1);

var Goose_door_right	= props.globals.getNode("/controls/door-right/position-norm");
var Goose_MP_door_right	= props.globals.getNode("/sim/multiplay/generic/float[2]");


var door_left = aircraft.door.new("/controls/door-left", 1);

var Goose_door_left	= props.globals.getNode("/controls/door-left/position-norm");
var Goose_MP_door_left	= props.globals.getNode("/sim/multiplay/generic/float[3]");


#setlistener(Goose_door_bow, func {
#  Goose_MP_door_bow.setValue(Goose_door_bow.getValue())
#});
