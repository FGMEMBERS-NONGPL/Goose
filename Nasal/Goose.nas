# Grumman Goose
#
# Initialization routines
#
# Gary Neely aka 'Buckaroo'
#
# Wake generation code largely derived from Syd Adam's Beaver
#


aircraft.livery.init("Aircraft/Goose/Models/Liveries");

var Goose_screenmssg	= screen.window.new(nil, -150, 2, 5);
var Goose_screenmssg2	= screen.window.new(nil, -180, 2, 5);

								# Lighting setup

								# Install beacon timer and controller
beacon_switch = props.globals.getNode("/controls/lighting/beacon", 1);
beacon_switch.setBoolValue(0);
aircraft.light.new("/sim/model/Goose/lighting/beacon", [0.2, 2], beacon_switch);
								# Pass beacon timer over MP (aliasing the timer value
								# doesn't seem to work, so a listener is used)
var Goose_BeaconState	= props.globals.getNode("sim/model/Goose/lighting/beacon/state[0]", 1);
var Goose_MPBeaconState	= props.globals.getNode("/sim/multiplay/generic/float[1]", 1);
setlistener(Goose_BeaconState, func {
  if (Goose_BeaconState.getBoolValue())	{ Goose_MPBeaconState.setValue(1) }
  else					{ Goose_MPBeaconState.setValue(0) }
});



								# Disabled keyboard engine starter message
var starter_null = func {
  Goose_screenmssg.fg = [1, 1, 1, 1];
  Goose_screenmssg.write("Use the overhead starter switches.");
}

								# Anchor/Tie-up stuff

var Goose_anchor = func{
  if (Goose_door_bow.getValue() != 1) {				# Var declared in Goose-doors.nas
    Goose_screenmssg.fg = [1, 0.5, 0, 1];
    Goose_screenmssg.write("Bow doors need to be open before you can toss out the anchor.");
    return 0;
  }
  props.globals.getNode("/controls/winch/place").setBoolValue(1);
  settimer(set_anchor,1);
}

var set_anchor = func{
  props.globals.getNode("/controls/winch/place").setBoolValue(0);
}


								# Wake generation stuff

var Wake1		= props.globals.getNode("/gear/gear[4]/wake",1);
var Wake2		= props.globals.getNode("/gear/gear[6]/wake",1);
var Wake3		= props.globals.getNode("/gear/gear[7]/wake",1);

var update_wake = func{
    var wk1 = 0;
    var wk2 = 0;
    var wk3 = 0;
    if (getprop("velocities/groundspeed-kt") > 15.0) {		# No wake under this speed
      if (getprop("/gear/gear[4]/wow")) { wk1 = 1; }		# Fuselage
      if (getprop("/gear/gear[6]/wow")) { wk2 = 1; }		# Right Float
      if (getprop("/gear/gear[7]/wow")) { wk3 = 1; }		# Left Float
      #if (wk1 or wk2 or wk3) { update_wake_history(); }
    }
    Wake1.setBoolValue(wk1);
    Wake2.setBoolValue(wk2);
    Wake3.setBoolValue(wk3);
}

var setup_start = func{
}

								# Fast start-up for testing purposes
var Startup = func{
Goose.MJB_On();
setprop("controls/engines/engine[0]/magnetos",3);
setprop("controls/engines/engine[0]/fuel-pump",1);
setprop("controls/engines/engine[0]/propeller-pitch",1);
setprop("controls/engines/engine[0]/mixture",1);
setprop("controls/engines/engine[1]/magnetos",3);
setprop("controls/engines/engine[1]/fuel-pump",1);
setprop("controls/engines/engine[1]/propeller-pitch",1);
setprop("controls/engines/engine[1]/mixture",1);
setprop("controls/flight/flaps",0.5);
setprop("engines/engine[0]/out-of-fuel",0);
setprop("engines/engine[1]/out-of-fuel",0);
setprop("engines/engine[0]/rpm",500);
setprop("engines/engine[1]/rpm",500);
setprop("engines/engine[0]/running",1);
setprop("engines/engine[1]/running",1);
}


var Shutdown = func{
setprop("controls/engines/engine[0]/magnetos",0);
setprop("controls/engines/engine[0]/fuel-pump",0);
setprop("controls/engines/engine[0]/propeller-pitch",0);
setprop("controls/engines/engine[0]/mixture",0);
setprop("controls/engines/engine[1]/magnetos",0);
setprop("controls/engines/engine[1]/fuel-pump",0);
setprop("controls/engines/engine[1]/propeller-pitch",0);
setprop("controls/engines/engine[1]/mixture",0);
setprop("engines/engine[0]/running",0);
setprop("engines/engine[1]/running",0);
}

								# Triggers startup/shutdown stuff on setting of
								# start-idling property by Menu option
setlistener("/sim/model/start-idling", func(idle){
  var run = idle.getBoolValue();
  if (run) {
    Startup();
  }
  else {
    Shutdown();
  }
},0,0);

								# Wake generation disabled due to damned CVS collision code.
#var update = func {
#  update_wake();
#  settimer(update,0);
#}


								# Settings that will be saved on exit:
Goose_Savedata = func {
  aircraft.data.add("/sim/goose/engine-warns");			# Engine warning messages
  aircraft.data.add("/sim/goose/engine-checks");		# Realistic engine damage and failure
}


setlistener("/sim/signals/fdm-initialized", func {
  FuelInit();							# See Goose-fuel.nas
  ElectricalInit();						# See Goose-electrical.nas
  EngineInit();							# See Goose-engines.nas
  InstrumentationInit();					# See Goose-instrumentation_drivers.nas
  Goose_Savedata();
});




