# Grumman Goose
#
# Fuel Update routines
# Essentially a modified version of standard fuel.nas that has engines draw fuel from array-sequenced tanks.
# Engine[n] draws from tank[n] and only tank[n]. Other tanks are ignored.
#
# Gary Neely aka 'Buckaroo'
#
# Many thanks to Syd Adams for his fix to out-of-fuel reset situations.
#


# Properties under /consumables/fuel/tank[n]:
# + level-gal_us    - Current fuel load.  Can be set by user code.
# + level-lbs       - OUTPUT ONLY property, do not try to set
# + selected        - boolean indicating tank selection.
# + density-ppg     - Fuel density, in lbs/gallon.
# + capacity-gal_us - Tank capacity
#
# Properties under /engines/engine[n]:
# + fuel-consumed-lbs - Output from the FDM, zeroed by this script
# + out-of-fuel       - boolean, set by this code.


								# Fuel Reset: Quick way to reset to fuel fraction
var reset_fuel = func{
  var fuel_fraction= props.globals.getNode("/sim/fuel-fraction");
  var gallons = 110 * fuel_fraction.getValue();
  var lbs = 660 * fuel_fraction.getValue();
  setprop("/consumables/fuel/tank[0]/level-gal_us",gallons);
  setprop("/consumables/fuel/tank[0]/level-lbs",lbs);
  setprop("/consumables/fuel/tank[1]/level-gal_us",gallons);
  setprop("/consumables/fuel/tank[1]/level-lbs",lbs);
  setprop("/consumables/fuel/tank[0]/selected",1);
  setprop("/consumables/fuel/tank[1]/selected",1);
  setprop("/engines/engine[0]/out-of-fuel",0);
  setprop("/engines/engine[1]/out-of-fuel",0);
}


var UPDATE_PERIOD = 0.3;
var tank_list = [];							# Raw tank list
var tanks = [];								# Qualified tank list
var engines = [];
var fuel_freeze = nil;
var total_gals = nil;
var total_lbs = nil;
var total_norm = nil;


var fuel_update = func {
  if (fuel_freeze)
    return;
									# Subtract fuel from tanks, iterating over engines, where
									# engine[i] draws fuel from tank[i]. Other tanks ignored here.
  var i = 0;
  foreach (var e; engines) {
    var fuel = e.getNode("fuel-consumed-lbs");
    var consumed = fuel.getValue();
    fuel.setDoubleValue(0);
    var ppg = tank_list[i].getChild("density-ppg").getValue();
    var lbs = tank_list[i].getChild("level-gal_us").getValue() * ppg;
    lbs = lbs - consumed;
    if (lbs <= 0) {
      lbs = 0;
      e.getNode("out-of-fuel").setBoolValue(1);
    }
    elsif(lbs >1 and engines[i].getNode("running").getValue()) {
      e.getNode("out-of-fuel").setBoolValue(0);
    }
    var gals = lbs / ppg;
    tank_list[i].getChild("level-gal_us").setDoubleValue(gals);
    tank_list[i].getChild("level-lbs").setDoubleValue(lbs);
    i += 1;
  }
  
									# Total fuel properties
									# Note that this takes into account /all/ tanks
  var lbs = 0;
  var gals = 0;
  var cap = 0;
  
  foreach (var t; tanks) {
    lbs += t.getNode("level-lbs").getValue();
    gals += t.getNode("level-gal_us").getValue();
    cap += t.getNode("capacity-gal_us").getValue();
  }
  
  total_lbs.setDoubleValue(lbs);
  total_gals.setDoubleValue(gals);
  total_norm.setDoubleValue(gals / cap);
}


var fuel_loop = func {
  fuel_update();
  settimer(fuel_loop, UPDATE_PERIOD);
}


var init_double_prop = func(node, prop, val) {
  if (node.getNode(prop) != nil) {
    val = num(node.getNode(prop).getValue());
  }
  node.getNode(prop, 1).setDoubleValue(val);
}


FuelInit = func {
  #print("Initializing Goose fuel system...\n");
  fuel.update = func{};							# Remove default fuel fuel system
  setlistener("/sim/freeze/fuel", func(n) { fuel_freeze = n.getBoolValue() }, 1);
  
  total_gals = props.globals.getNode("/consumables/fuel/total-fuel-gals", 1);
  total_lbs = props.globals.getNode("/consumables/fuel/total-fuel-lbs", 1);
  total_norm = props.globals.getNode("/consumables/fuel/total-fuel-norm", 1);
  
  tank_list = props.globals.getNode("/consumables/fuel",1).getChildren("tank");
  
  engines = props.globals.getNode("engines", 1).getChildren("engine");
  foreach (var e; engines) {
    e.getNode("fuel-consumed-lbs", 1).setDoubleValue(0);
    e.getNode("out-of-fuel", 1).setBoolValue(0);
  }

  foreach (var t; props.globals.getNode("/consumables/fuel", 1).getChildren("tank")) {
    if (!size(t.getChildren()))
      continue;           						# skip native_fdm.cxx generated zombie tanks
    append(tanks, t);
    init_double_prop(t, "level-gal_us", 0.0);
    init_double_prop(t, "level-lbs", 0.0);
    init_double_prop(t, "capacity-gal_us", 0.01);			# not zero (div/zero issue)
    init_double_prop(t, "density-ppg", 6.0);				# gasoline
    if (t.getNode("selected") == nil)
      t.getNode("selected", 1).setBoolValue(1);
  }

  settimer(fuel_loop, 2);						# Delay startup a bit to allow things to initialize
}

