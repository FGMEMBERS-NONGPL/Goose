# Grumman Goose
#
# Engine management routines
#
# Gary Neely aka 'Buckaroo'
#


# The following values are largely derived from tweaking to match data taken from the Beaver flight manual
# for the R-985 Wasp Jr. There's nothing magic about them. Note that many are based on the update time of
# 0.2 secs. If you change this, many if not most values will no longer yield results within the R-985's norm.

var UPDATE_INTERVAL	= 0.2;					# Update engines every 0.2 secs.
var MAX_RPM		= 2200;					# Above this the engine starts to accumulate strain
								# from over-rev issues if MAX_RPM_T exceeded
var MAX_RPM_CLK		= 60;					# Secs; Time up to this value doesn't count toward strain
var MAX_IDLE		= 800;					# Above this the engine starts to accumulate strain
								# from oil viscosity issues
var MAX_STRAIN		= 20000;				# Arbitrary strain value, when exceeded, engine dies
var OILV_DELTA_WARMUP	= 0.002;				# Viscosity increment per cycle when warming up
var OILV_DELTA_COOLDN	= 0.0002;				# Viscosity decrement per cycle when cooling down
var VISC_PENALTY	= 40;					# Maximum reduction of oil pressure for viscosity
var COLD_OIL_FACTOR	= 25;					# Arbitrary strain value for running engine over idle when cold
								# This is killer, so keep value small or users will whine
var MAX_OK_OILT		= 80;					# Maximum best oil temperature
var MIN_OK_OILT		= 60;					# Minimum best oil temperature
var MIN_OILP		= 70;					# Minimum acceptable oil pressure
var MAX_OILP		= 150;					# Highest value oil pressure will register
var MAX_OK_OILP		= 90;					# Maximum best oil pressure
var MIN_OK_OILP		= 70;					# Minimum best oil pressure
var MIN_OILP		= 50;					# Minimum acceptable oil pressure, currently not used

var TARGET_FUEL_P	= 5;					# Target best fuel pressure
var CYLT_MAX		= 270;					# Engine always takes damage above this temp
var TARGET_CYLT_HIGH	= 230;					# Target best cylinder head temp, high end
								# Engine takes damage above this temp after a time interval
var TARGET_CYLT_LOW	= 150;					# Target best cylinder head temp, low end
var MAX_CYLT_STRAIN_CLK	= 60;					# Time in secs that must pass before engine under CYLT_MAX
								# but over CYLT_HIGH starts taking damage
var DELTA_T_F		= 0.1;					# Change in temperature master factor,
								# inc to make changes faster, dec to slow temp changes
var DELTA_T_ENV		= 0.014;				# Change in temp due to ambient air factor
var DELTA_T_THRUST	= 0.006;				# Change in temp due to power factor
var DELTA_T_AS		= 0.02;					# Change in temp due to airspeed-induced air factor
var MIXTURE_CUTOFF	= 0.8;					# Mixture setting: below this value, no cooling benefits
var MIXTURE_FACTOR	= 14;					# Mixture cooling benefits multiplier
var OPOH		= 50;					# Engine operational overhead value
var PROP_AIR		= 0.01;					# Factor for prop air moving over engine
var AMBIENT_REDUCTION	= 0.25;					# Factor for reduction of ambient cooling under max operating range
var MIXTURE_PEAK	= 0.74;					# Observed mixture setting for peak power
var MIXTURE_BIAS	= 10;					# Max degrees C to augment cyl temp at mixture peak
var ENGINE_MASS		= 1;					# Engine mass factor; not currently used, but the idea is to
								# inc this to slow temperature changes


var eng_checks	= props.globals.getNode("/sim/goose/engine-checks");
var eng_warns	= props.globals.getNode("/sim/goose/engine-warns");
var tanks	= props.globals.getNode("/consumables/fuel").getChildren("tank");
var engines	= props.globals.getNode("/engines").getChildren("engine");
var controls	= props.globals.getNode("controls/engines").getChildren("engine");
var airspeed	= props.globals.getNode("/velocities/airspeed-kt");
var envtemp	= props.globals.getNode("/environment/temperature-degc");

var oilt_target = (MAX_OK_OILT-MIN_OK_OILT)/2 + MIN_OK_OILT;	# Calculate a nice mid-range temp value to seek
var oilp_target = (MAX_OK_OILP-MIN_OK_OILP)/2 + MIN_OK_OILP;	# Calculate a nice mid-range pressure value to seek


								# Functions for enabling engine options:

var eng_checks_set = func {
  if (eng_checks.getValue()) { eng_checks.setValue(0); var mssg = "Engine parameter checks disabled."; }
  else			     { eng_checks.setValue(1); var mssg = "Engine parameter checks enabled."; }
  Goose_screenmssg.fg = [1, 1, 1, 1];
  Goose_screenmssg.write(mssg);
}
var eng_warns_set = func {
  if (eng_warns.getValue())  { eng_warns.setValue(0); var mssg = "Engine parameter warnings disabled."; }
  else			     { eng_warns.setValue(1); var mssg = "Engine parameter warnings enabled."; }
  Goose_screenmssg.fg = [1, 1, 1, 1];
  Goose_screenmssg.write(mssg);
}

								# Engine warning messages:

var eng_checks_overrev = func(i) {
  i+=1;
  var mssg = "Engine "~i~" over-rev warning.";
  Goose_screenmssg.fg = [1, 0.5, 0, 1];
  Goose_screenmssg.write(mssg);
}
var eng_checks_overheat = func(i) {
  i+=1;
  var mssg = "Engine "~i~" over-heating warning.";
  Goose_screenmssg.fg = [1, 0.5, 0, 1];
  Goose_screenmssg.write(mssg);
}
var eng_checks_oilcold = func(i) {
  i+=1;
  var mssg = "Engine "~i~" oil temperature warning.";
  Goose_screenmssg.fg = [1, 0.5, 0, 1];
  Goose_screenmssg.write(mssg);
}
var eng_checks_damage = func(i,y) {
  i+=1;
  var mssg = "Engine "~i~" has passed 25% damage.";
  if (y > MAX_STRAIN * 0.9)		{ mssg = "Engine "~i~" is critical."; }
  elsif (y > MAX_STRAIN * 0.75)		{ mssg = "Engine "~i~" has passed 75% damage."; }
  elsif (y > MAX_STRAIN * 0.5)		{ mssg = "Engine "~i~" has passed 50% damage."; }
  Goose_screenmssg2.fg = [1, 0.5, 0, 1];
  Goose_screenmssg2.write(mssg);
}
var eng_checks_failure = func(i) {
  i+=1;
  var mssg = "Engine "~i~" failure.";
  Goose_screenmssg2.fg = [1, 0, 0, 1];
  Goose_screenmssg2.write(mssg);
}


var FtoC = func (f) {						# Fahrenheit to Celsius
  return (f-32) * 5 / 9;
}


								# Primary engine loop:

var engine_update = func (i) {					# i is engine number, 0-n
  if (engines[i].getNode("running").getValue() == 1) {		# Is engine running?

    var strain = engines[i].getNode("strain").getValue();
    if (strain > MAX_STRAIN) {					# Don't let strain value get absurd when engine
      strain = MAX_STRAIN;					# failure is disabled
      engines[i].getNode("strain").setValue(strain);
    }
								# Calculate engine strain due to over-rev
    var strain_clk_rev = engines[i].getNode("strain-clk-rev").getValue();	# Get time we've been operating over-revved
    if (engines[i].getNode("rpm").getValue() > MAX_RPM) {
      if (strain_clk_rev < MAX_RPM_CLK) {			# Update time allowed for over-rev
        interpolate(engines[i].getNode("strain-clk-rev"),MAX_RPM_CLK,MAX_RPM_CLK-strain_clk_rev);
      }
								# If time allowed over RPM is exceeded:
      if (strain_clk_rev >= MAX_RPM_CLK) {			# Add more strain to engine
        if (eng_checks.getValue()) {
          var strain_add = engines[i].getNode("rpm").getValue() - MAX_RPM;
          engines[i].getNode("strain").setValue(strain + strain_add);
        }
        if (eng_warns.getValue()) { eng_checks_overrev(i); }	# Notice to user
      }
    }
    else {
								# Under max RPM, so allow timer to fall back to 0
      if (strain_clk_rev > 0) {
        interpolate(engines[i].getNode("strain-clk-rev"),0,strain_clk_rev);
      }
    }

								# Fuel pressure
    if (engines[i].getNode("fuel-press").getValue() < TARGET_FUEL_P) {
      interpolate(engines[i].getNode("fuel-press"), TARGET_FUEL_P, 3);
    }

								# Simplified oil temp, viscosity, pressure
								# Note that viscosity is a dimensionless normalized value,
								# not a true viscosity number
    var oilv = engines[i].getNode("oil-visc").getValue();
    if (oilv > 0) {
      oilv = oilv - OILV_DELTA_WARMUP;				# Determine new oilv as necessary
      engines[i].getNode("oil-visc").setValue(oilv);		# Save viscosity
      var oilp =  ((MAX_OILP - oilp_target) * oilv) + oilp_target;# Viscosity determines position between max oilp and target best oilp
      engines[i].getNode("oil-press").setValue(oilp);		# Save oilp, probably not necessary to interpolate
								# Oilt rises from ambient as viscosity falls
      var oilt = (oilt_target - envtemp.getValue()) * (1-oilv) + envtemp.getValue();
      engines[i].getNode("oiltempc").setValue(oilt);		# Save oilt as deg C

								# Oil pressure check:
      if (oilp > MAX_OK_OILP and engines[i].getNode("rpm").getValue() > MAX_IDLE) {
        if (eng_checks.getValue()) {
          engines[i].getNode("strain").setValue(engines[i].getNode("strain").getValue() + (COLD_OIL_FACTOR/oilv));
        }
        if (eng_warns.getValue()) { eng_checks_oilcold(i); }	# Notice to user
      }
    }


								# Cyl head temp change calculations:
								# Currently this accounts for environmental cooling,
								# airflow cooling, and thrust/rpm heating. It should
								# also account for cooling due to rich mixture, but
								# doesn't yet.

    var cyl_temp	= engines[i].getNode("cyltempc").getValue();
    var thrust		= engines[i].getNode("prop-thrust").getValue();
    var mixture		= controls[i].getNode("mixture").getValue();
    var throttle	= controls[i].getNode("throttle").getValue();
    var dT_env		= (envtemp.getValue() - cyl_temp) * DELTA_T_ENV;
    var dT_thrust	= (thrust + OPOH) * DELTA_T_THRUST;
    var dT_airspeed	= airspeed.getValue() * DELTA_T_AS;
    var dT_mixture	= mixture - MIXTURE_CUTOFF;
    if (dT_mixture < 0) { dT_mixture = 0; }			# DeltaT due to rich mixture benefits
    else		{ dT_mixture = dT_mixture * MIXTURE_FACTOR; }
    if (cyl_temp <= TARGET_CYLT_LOW) {				# When below best operating low temp:
      dT_env = dT_env * AMBIENT_REDUCTION;			# DeltaT due to ambient reduction benefits
      dT_airspeed = 0;						# No airspeed benefits below best operating temp low range
								# Linearly reduce mixture benefits down to ambient temp
      dT_mixture = 0;						# No significant mixture benefits in this range
    }
    elsif (cyl_temp < TARGET_CYLT_HIGH) {			# When withing best operating temp range:
								# Normalize temperature range:
      var temp_norm = (cyl_temp - TARGET_CYLT_LOW) / (TARGET_CYLT_HIGH - TARGET_CYLT_LOW);
								# Linearly reduce ambient benefits from full to AMBIENT_REDUCTION over range
      dT_env = dT_env * (AMBIENT_REDUCTION + (AMBIENT_REDUCTION * temp_norm));
								# Linearly reduce airspeed benefits from full to none
      dT_airspeed = dT_airspeed * temp_norm;
								# Linearly reduce mixture benefits from full to none
      if (dT_mixture > 0) { dT_mixture = dT_mixture * temp_norm; }
    }
    var delta_cyl_temp	= (dT_env + dT_thrust - dT_airspeed - dT_mixture) * DELTA_T_F;
    cyl_temp = cyl_temp + delta_cyl_temp;
    engines[i].getNode("cyltempc").setValue(cyl_temp);

								# Calculate engine strain due to over-temp
    var strain_clk_temp = engines[i].getNode("strain-clk-temp").getValue();	# Get time that we've been operating over-temp
    if (cyl_temp > CYLT_MAX) {					# Above this temp engine damage always occurs
      if (eng_checks.getValue()) {
        var strain_add = cyl_temp - TARGET_CYLT_HIGH;
        engines[i].getNode("strain").setValue(strain + strain_add);
      }
      if (eng_warns.getValue()) { eng_checks_overheat(i); }	# Notice to user
    }
    if (cyl_temp > TARGET_CYLT_HIGH) {				# Above this temp engine damage occurs after a period of time
      if (strain_clk_temp < MAX_CYLT_STRAIN_CLK) {		# Update time allowed for over-temp
        interpolate(engines[i].getNode("strain-clk-temp"),MAX_CYLT_STRAIN_CLK,MAX_CYLT_STRAIN_CLK-strain_clk_temp);
      }
								# If time allowed over temp is exceeded:
      if (strain_clk_temp >= MAX_CYLT_STRAIN_CLK) {		# Add more strain to engine
        if (eng_checks.getValue()) {
          var strain_add = cyl_temp - TARGET_CYLT_HIGH;
          engines[i].getNode("strain").setValue(strain + strain_add);
        }
        if (eng_warns.getValue()) { eng_checks_overheat(i); }	# Notice to user
      }
    }
    else {
								# Under temp limits, so allow timer to fall back to 0
      if (strain_clk_temp > 0) {
        interpolate(engines[i].getNode("strain-clk-temp"),0,strain_clk_temp);
      }
    }

								# Mixture adjustments change thrust values by about 5% which
								# which is hard to notice on the gauge. So this is a fudged
								# addition to make the temperate peak more when the mixture
								# is leaned out to highest power output. This means the gauges
								# will read a little high, but failure tests will still be
								# based on true cyl temp.
    var bias = 0;
    if (mixture >= MIXTURE_PEAK) {
      bias = ((1 - mixture) / (1 - MIXTURE_PEAK)) * MIXTURE_BIAS * throttle;
    }
    else {
      bias = (mixture / MIXTURE_PEAK) * MIXTURE_BIAS * throttle;
    }
    engines[i].getNode("cyltempc-biased").setValue(cyl_temp+bias);
    
								# For testing and debugging:
    engines[i].getNode("cyl-dt").setValue(delta_cyl_temp);
    engines[i].getNode("cyl-dte").setValue(dT_env);
    engines[i].getNode("cyl-dtt").setValue(dT_thrust);
    engines[i].getNode("cyl-dta").setValue(dT_airspeed);
    engines[i].getNode("cyl-dtm").setValue(dT_mixture);


								# Engine damage warnings
    if (eng_warns.getValue() and strain > MAX_STRAIN * 0.25) {
      eng_checks_damage(i,strain);
    }


    if (eng_checks.getValue()) {
								# Kill engine if over-strained
      strain = engines[i].getNode("strain").getValue();
      if (strain >= MAX_STRAIN) {
        engines[i].getNode("overrev").setValue(1);
        engines[i].getNode("running").setValue(0);
        engines[i].getNode("out-of-fuel").setValue(1);
        tanks[i].getNode("selected").setValue(0);
        interpolate(engines[i].getNode("fuel-press"), 0, 5);
        if (eng_warns.getValue()) { eng_checks_failure(i); }
      }
    }
  }
  else {							# Engine not running
								# Kill fuel pressure
    if (engines[i].getNode("fuel-press").getValue() > 0) {
      interpolate(engines[i].getNode("fuel-press"), 0, 10);
    }

								# Cyl temp cool-down:
    var cyl_temp	= engines[i].getNode("cyltempc").getValue();
    var dT_env		= (envtemp.getValue() - cyl_temp) * DELTA_T_ENV;
    var dT_airspeed	= airspeed.getValue() * DELTA_T_AS;
    if (cyl_temp <= TARGET_CYLT_LOW) {				# When below best operating low temp:
      dT_env = dT_env * AMBIENT_REDUCTION;			# Reduce ambient cooling
      dT_airspeed = 0;						# No airspeed benefits below best operating temp low range
    }
    elsif (cyl_temp < TARGET_CYLT_HIGH) {			# When withing best operating temp range:
								# Normalize range:
      var temp_norm = (cyl_temp - TARGET_CYLT_LOW) / (TARGET_CYLT_HIGH - TARGET_CYLT_LOW);
								# Linearly reduce ambient benefits from full to AMBIENT_REDUCTION over range
      dT_env = dT_env * (AMBIENT_REDUCTION + (AMBIENT_REDUCTION * temp_norm));
      dT_airspeed = dT_airspeed * temp_norm;			# Linearly reduce airspeed benefits from full to none
    }
    var delta_cyl_temp	= (dT_env - dT_airspeed) * DELTA_T_F;
    cyl_temp = cyl_temp + delta_cyl_temp;
    engines[i].getNode("cyltempc").setValue(cyl_temp);
    engines[i].getNode("cyltempc-biased").setValue(cyl_temp);

								# Oil cool-down; see main oil section for notes
    var oilv = engines[i].getNode("oil-visc").getValue();
    if (oilv < 1) {
      var oilt = (oilt_target - envtemp.getValue()) * (1-oilv) + envtemp.getValue();
      engines[i].getNode("oiltempc").setValue(oilt);
      var oilp = ((MAX_OILP - oilp_target) * oilv) + oilp_target;
      engines[i].getNode("oil-press").setValue(oilp);
      engines[i].getNode("oil-visc").setValue(oilv + OILV_DELTA_COOLDN);
    }
  }

}


var engine_loop = func {
  engine_update(0);
  engine_update(1);
  settimer(engine_loop, UPDATE_INTERVAL);
}



var engine_setup = func {
								# Set engines to ambient temp on startup
  engines[0].getNode("cyltempc").setValue(envtemp.getValue());
  engines[1].getNode("cyltempc").setValue(envtemp.getValue());
  engines[0].getNode("oiltempc").setValue(envtemp.getValue());
  engines[1].getNode("oiltempc").setValue(envtemp.getValue());
								# Uncomment to pre-warm engines for testing:
  #engines[0].getNode("cyltempc").setValue((TARGET_CYLT_HIGH-TARGET_CYLT_LOW)/2+TARGET_CYLT_LOW);
  #engines[1].getNode("cyltempc").setValue((TARGET_CYLT_HIGH-TARGET_CYLT_LOW)/2+TARGET_CYLT_LOW);
  engine_loop();
}

var EngineInit = func {
  settimer(engine_setup, 1);					# Give a few seconds for environment vars to initialize
}
