# Grumman Goose
#
# Instrumentation Drivers
#
# Gary Neely aka 'Buckaroo'
#
# Support for Attitude Indicator
# Support for the RMI
#


# Support for the Attitude Indicator
#
# The AI presumably relies on either vacuum or electrically powered gyros which must
# be kept spinning to function. Some part of FG decrements the spin value, and some part
# increments it, but it seems to rely on an engine setting (RPM) for engine #1.
# I'm assuming the Goose AI relies on a vacuum-powerd gyro. Therefore I power it
# here by updating it every 5 seconds if either engine is running.
#
# Note that var 'engines' is declared part of the Goose-engines script, so make sure that
# script is loaded first.

var ai_spin	= props.globals.getNode("/instrumentation/attitude-indicator/spin");


var update_ai = func {
  var nextrun = 5;
  if (engines[0].getNode("running").getValue() or engines[1].getNode("running").getValue()) {
								# At least 1 engine running, spin up or feed gyro:
    if (ai_spin.getValue() < 0.9) {				# Arbitrary value indicationg no power for a while
      interpolate(ai_spin, 1, 15);				# Spin up the gyro
      nextrun = 20;						# Delay next run for 20 secs
    }
    else {							# Gyro already spun up
      ai_spin.setValue(1);					# Feed gyro
    }
  }
  settimer(update_ai, nextrun);
}



# Support to calculate RMI needle deflections based on mode (VOR/ADF)
# and beacon range. Simplifies RMI animations.
#
# Reads two custom properties:
#   /instrumentation/rmi-needle[0]/mode		(values 'vor'|'adf', default 'vor')
#   /instrumentation/rmi-needle[1]/mode		(values 'vor'|'adf', default 'vor')
#
# These should be set by cockpit switches to control the two RMI needles.
#
# Function writes to two custom properties:
#  /instrumentation/rmi-needle[0]/value
#  /instrumentation/rmi-needle[1]/value
#
# These are read by the RMI instrument animations.
#
# This code is based in part on code originally suggested by Wolfram Gottfried aka 'Yakko'.


var UPDATE_PERIOD	= 0.125;				# How often to update main loop in seconds (0 = framerate)

var rmi1	= props.globals.getNode("/instrumentation/rmi-needle[0]");
var rmi2	= props.globals.getNode("/instrumentation/rmi-needle[1]");
var adf1	= props.globals.getNode("/instrumentation/adf[0]");
var adf2	= props.globals.getNode("/instrumentation/adf[1]");
var nav1	= props.globals.getNode("/instrumentation/nav[0]");
var nav2	= props.globals.getNode("/instrumentation/nav[1]");
var heading	= props.globals.getNode("/orientation/heading-magnetic-deg");


var update_rmi = func {

  var needle1 = 90;						# Needle default off or out-of-range positions
  var needle2 = 270;
						
  if (rmi1.getNode("mode").getValue()) {			# Mode 1 = ADF
    if(adf1.getNode("in-range").getValue()) {
      needle1 = adf1.getNode("indicated-bearing-deg").getValue();
    }
  }
  else {							# Mode 0 = VOR
    if (nav1.getNode("in-range").getValue() and !nav1.getNode("has-gs").getValue()) {
      needle1 = nav1.getNode("heading-deg").getValue() - heading.getValue(); 
    }
  }

  if (rmi2.getNode("mode").getValue()) {			# Mode 1 = ADF
    if(adf2.getNode("in-range").getValue()) {
      needle2 = adf2.getNode("indicated-bearing-deg").getValue();
    }
  }
  else {							# Mode 0 = VOR
    if (nav2.getNode("in-range").getValue() and !nav2.getNode("has-gs").getValue()) {
      needle2 = nav2.getNode("heading-deg").getValue() - heading.getValue(); 
    }
  }

  rmi1.getNode("value").setValue(needle1);
  rmi2.getNode("value").setValue(needle2);

  settimer(update_rmi, UPDATE_PERIOD);
}

var InstrumentationInit = func {
  settimer(update_rmi, 2);				# Delay startup a bit to allow things to initialize
  settimer(update_ai, 20);				# Maintain spin on backup AI
}
