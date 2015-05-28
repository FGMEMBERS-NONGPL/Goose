# Grumman Goose
#
# Electrical support routines
#
# Gary Neely aka 'Buckaroo'
#
# This system provides support for the DC bus, though the system currently exists to animate the MJB
# panels more than anything else. AC power is provided via inverters to sub-systems that require it,
# but currently I don't simulate AC power.
#
# There are 4 possible feeds for the DC bus: 2 engine generators and the two aircraft batteries.
# Battery power is virtually inexhaustable as I currently don't have data on what amps various
# systems draw and therefore a true drain/charge system isn't feasible. Until more data is available,
# all voltages and currents are typical for their functions.
#


var STD_VOLTS	= 24.0;							# Typical volts for a power source
var MIN_VOLTS	= 23.5;							# Typical minimum voltage level for generic equipment
var STD_AMPS	= 125;							# Typical amps for a power source
var NUM_ENGINES	= 2;


									# Handy handles for DC source feed indices
var feed	= {	eng1	: 0,
			eng2	: 1,
			batt1	: 2,
			batt2	: 3
		  };
var feed_sw	= [0,0,0,0];						# For fast feed checking

									# Other property handles:
var engines	= props.globals.getNode("/engines").getChildren("engine");
var sources	= props.globals.getNode("/systems/electrical").getChildren("power-source");
var sw_batt	= props.globals.getNode("/controls/switches").getChildren("battery");
var sw_gen	= props.globals.getNode("/controls/switches/generator");
var sw_aux	= props.globals.getNode("/controls/switches/aux");
var test_volts	= props.globals.getNode("/systems/electrical/test-volts-dc");
var bus_dc	= props.globals.getNode("/systems/electrical/bus-dc");

var switch_panel	= props.globals.getNode("/controls/switches/panel-norm");
var controls_panel	= props.globals.getNode("/controls/lighting/panel-norm");
var controls_flaps	= props.globals.getNode("/controls/flight/flaps");
var controls_gear	= props.globals.getNode("/gear").getChildren("gear");	# Yeah, I know it's not a 'control'
var controls_lighting	= props.globals.getNode("/controls/lighting");
var controls_switches	= props.globals.getNode("/controls/switches");


									# Engine starter:
									# Engage switch, start engine if volts on bus
var engine_starter = func(i,v) {
  var switches = props.globals.getNode("/controls/switches").getChildren("starter");
  switches[i].getNode("position").setValue(v);
  if (bus_dc.getNode("volts").getValue() > MIN_VOLTS) {
    var controls = props.globals.getNode("/controls/engines").getChildren("engine");
    controls[i].getNode("starter").setValue(v);
  }
}


var panel_lights = func(v) {
  var switch = switch_panel.getValue();
  switch += v;
  if (switch > 1) { switch = 1; }
  if (switch < 0) { switch = 0; }
  switch_panel.setValue(switch);
  if (bus_dc.getNode("volts").getValue() > MIN_VOLTS) {
    controls_panel.setValue(switch);
  }
}


									# Fast Main Junction Box power-up
var MJB_On = func {
  sw_batt[0].getNode("position").setValue(1);
  sw_batt[1].getNode("position").setValue(1);
  sw_gen.setValue(1);
}



#
# Primary electrical system support:
#

									# If an engine is running and the generator switch
									# is on, simulate power available on that source by
									# setting its volts and amps to usable values
var update_generators = func {
  for(var i=0; i<NUM_ENGINES; i+=1) {
    if (engines[i].getNode("running").getValue() and sw_gen.getValue()) {
      feed_sw[i] = 1;
      sources[i].getNode("volts").setValue(STD_VOLTS);
      sources[i].getNode("amps").setValue(STD_AMPS);
    }
    else {
      feed_sw[i] = 0;
      sources[i].getNode("volts").setValue(0);
      sources[i].getNode("amps").setValue(0);
    }
  }
}

var update_battery = func(i) {
  var feed_index = i + 2;						# Offset feed index
  var batt_sw = sw_batt[i].getNode("position").getValue();		# Battery switch status
  feed_sw[feed_index] = batt_sw;
  if (batt_sw) {
    sources[feed_index].getNode("volts").setValue(STD_VOLTS);
    sources[feed_index].getNode("amps").setValue(STD_AMPS);
  }
  else {
    sources[feed_index].getNode("volts").setValue(0);
    sources[feed_index].getNode("amps").setValue(0);
  }
}


var update_bus_feeds = func {
  var volts = 0;							# Assume no volts on bus
  for(var i=0; i<size(feed_sw); i+=1) {					# Check all possible feeds
    if (feed_sw[i]) {							# If feed is on
      var source_volts = sources[i].getNode("volts").getValue();
      if (source_volts > volts) {					# Volts takes on largest source value
        volts = source_volts;
      }
    }
  }
  bus_dc.getNode("volts").setValue(volts);				# Bus takes on largest source value
}


									# Update the voltmeter on change of bus volts
var update_voltmeter = func {
  interpolate(test_volts,bus_dc.getNode("volts").getValue(),1.5);
}


									# Enable or cut power to various electrical stuff.
									# This is a quick-and-dirty way to do this--
									# Better to set up an extensible xml-driven system.
									# But I'm looking for instant-grat right now.
var update_bus_outputs = func {
  if (bus_dc.getNode("volts").getValue() > MIN_VOLTS) {
    controls_panel.setValue(switch_panel.getValue());
    controls_lighting.getNode("lamp-flaps").setValue(controls_flaps.getValue());
    controls_lighting.getNode("lamp-gear-left").setValue(controls_gear[1].getNode("position-norm").getValue());
    controls_lighting.getNode("lamp-gear-right").setValue(controls_gear[2].getNode("position-norm").getValue());
    controls_lighting.getNode("beacon").setValue(controls_switches.getNode("beacon").getValue());
    controls_lighting.getNode("tail").setValue(controls_switches.getNode("tail").getValue());
    controls_lighting.getNode("nav").setValue(controls_switches.getNode("nav").getValue());
    controls_lighting.getNode("landing-left").setValue(controls_switches.getNode("landing-left").getValue());
    controls_lighting.getNode("landing-right").setValue(controls_switches.getNode("landing-right").getValue());
  }
  else {
    controls_panel.setValue(0);
    controls_lighting.getNode("lamp-flaps").setValue(0);
    controls_lighting.getNode("lamp-gear-left").setValue(0);
    controls_lighting.getNode("lamp-gear-right").setValue(0);
    controls_lighting.getNode("beacon").setValue(0);
    controls_lighting.getNode("tail").setValue(0);
    controls_lighting.getNode("nav").setValue(0);
    controls_lighting.getNode("landing-left").setValue(0);
    controls_lighting.getNode("landing-right").setValue(0);
  }
}


									# The master bus update system
var update_bus = func {
  update_generators();
  update_battery(0);
  update_battery(1);
  update_bus_feeds();
  update_bus_outputs();
  update_voltmeter();
  settimer(update_bus,0.5);						# Schedule the next run
}




var electrical_setup = func {
									# Currently no initialization required
  settimer(update_bus,1);						# Startup electrical system
}


var ElectricalInit = func {
  settimer(electrical_setup, 1);					# Give a few seconds for vars to initialize
}
