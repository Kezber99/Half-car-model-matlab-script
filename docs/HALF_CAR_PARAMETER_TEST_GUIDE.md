# Half-car model: parameter measurement and validation guide

**Working test plan — no physical results are claimed.**  
**Applies to:** `half_car_model.m` and `simulate_half_car.m`, baseline commit `91a3718` and later compatible versions.  
**Audience:** Baja suspension team, test team, and future model owners.

## 1. What we are trying to establish

There are three separate jobs:

1. **Measure the inputs:** mass, geometry, wheel rates, damping, tires, road, and speed.
2. **Verify the calculation:** check matrix construction, time-step convergence, signs, units, and repeatability.
3. **Validate predictions:** compare the independently measured vehicle response with simulation of the same test.

Matching one graph after adjusting many unknown inputs does not uniquely identify the correct parameters. Measure the easily accessible properties first; use dynamic testing to assess the remaining uncertainty. Keep some test runs separate from parameter fitting.

A modest set of well-documented measurements is more useful than a complex test with uncertain units, timing, or loading conditions. Every parameter should have a value, unit, source, date, loading condition, and an uncertainty or defensible range.

## 2. Establish the vehicle representation first

For this team's one-side model of an approximately left/right-symmetric car:

| Input | Required representation |
|---|---|
| `m` | Half of total sprung mass, including the represented driver/fuel/payload |
| `m1` | One front corner's effective unsprung mass |
| `m2` | One rear corner's effective unsprung mass |
| `Iy` | Half of total sprung-body pitch inertia about the sprung CG |
| `k1`, `k2`, `c1`, `c2`, `kt1`, `kt2` | Per-wheel equivalent properties |
| `a1`, `a2` | Sprung-body CG distances to front/rear axles; not halved |

An axle-equivalent model is also possible, but then use full sprung mass/inertia, summed axle unsprung masses, and summed left/right rates and damping throughout. Do not mix conventions. Large left/right asymmetry cannot be represented faithfully by simply halving the total car.

Use the same driver, posture, fuel, payload, tire pressure, and intended ride height throughout a test series. Use a representative mass distribution if the driver is replaced with ballast. Driver-in-car corner weighing is appropriate; suspended or component-rig tests should use secured representative ballast rather than an occupant.

## 3. Equipment: minimum versus later additions

### Basic measurement kit

- Four calibrated corner scales, or a level weighing arrangement with all wheels at equal height.
- Bench scale for components; tape measure, calipers, straightedge, and digital angle gauge.
- Tire pressure gauge with suitable resolution for Baja operating pressures.
- Calibrated force gauge/load cell and displacement gauge, or access to a spring tester.
- A suitable supported suspension-motion fixture for measuring wheel and spring/damper displacement.
- Access to CAD mass properties for a first pitch-inertia estimate.

### Minimum useful dynamic-validation kit

- A rigidly mounted 6-axis IMU on the sprung structure, preferably near the sprung CG.
- Front and rear suspension-travel sensors, such as linear potentiometers or LVDTs, on the same side as the modeled track.
- A wheel-speed encoder and/or an independent speed reference; a pair of light gates can verify average speed over a short known distance.
- A common-clock data acquisition system, measured bump geometry, and a repeatable test location.

### Optional improvements

- Upright-mounted accelerometers to evaluate front/rear wheel-hop response.
- Optical tracking, laser displacement, or calibrated high-speed video to measure body/wheel displacement relative to ground.
- Damper dynamometer, vertical tire test rig, and an appropriately designed inertia-measurement fixture.
- Wheel-force transducers or instrumented test platens if direct dynamic tire-load validation becomes necessary. They are not required to start validating body acceleration and suspension travel.

Select sensor range, travel, and bandwidth before purchase. Check expected impact acceleration, full suspension stroke, mounting stiffness, cable routing, and environmental protection. The force fixtures must be rated for the expected loads; stored spring energy and supported vehicles require suitable restraints and stands.

## 4. Measurement procedure shared by all parameters

1. Identify the parameter and the convention/units required by the model.
2. Zero and calibrate the instrument; record calibration and mounting details.
3. Reproduce the intended load, geometry, temperature, pressure, and settings.
4. Measure several points across the operating range rather than relying on one reading.
5. Repeat independent loading/unloading cycles to reveal repeatability and hysteresis.
6. Fit the property over the range actually used in simulation, and preserve the raw data.
7. Record uncertainty from calibration, scatter, fixture geometry, and approximations.
8. Check the resulting value against an independent method where practical.

Use enough repeated readings to assess scatter; three repeat cycles is a practical starting point, not a statistical guarantee. For suspension and tire slopes, a small series of load/displacement points on both loading and unloading branches is preferable to a two-point calculation.

## 5. Sprung mass: `m` [kg]

**Equipment:** corner scales and component/effective-unsprung-mass estimates.

**Procedure:** place all four scales on one level plane, set operating tire pressures, release suspension bind by settling the vehicle, and weigh in the intended driver/fuel/payload condition. Record each corner and front/rear totals. Repeat after unloading/repositioning to assess repeatability.

Scale displays commonly report kg-equivalent mass, not N. Sum all four readings for loaded total vehicle mass. Subtract the total effective unsprung mass to estimate total sprung mass:

`total_sprung_mass = loaded_total_mass - total_unsprung_mass`

For a symmetric one-side model:

`m = total_sprung_mass / 2`

**Check:** modeled sprung plus unsprung masses must reconstruct the represented total mass. Driver and fuel must not be counted twice. Treat the uncertainty in effective unsprung mass as part of the uncertainty in `m`.

**Common mistake:** entering half of total vehicle mass as `m` and also adding unsprung masses separately. This double-counts unsprung mass.

## 6. Unsprung masses: `m1`, `m2` [kg]

**Equipment:** component scale, component inventory, and suspension geometry/CAD.

**Procedure:** weigh the complete wheel/tire, hub, upright, brake components, and other parts moving predominantly with the wheel at each end. Include the appropriate contribution of links, shafts, and partially moving spring/damper assemblies. Record what is included so that the same mass is not also counted as sprung.

A wheel/tire weight alone is insufficient. Weighing an assembly is useful, but the effective vertical unsprung mass of articulating components is not always their full physical mass.

**Simple initial approach:** sum measured wheel-following components and make a documented estimate for partially moving components. Use a sensitivity range rather than disguising the estimate as a precise measurement. There is no universal correct 'half the control-arm mass' rule.

**Improved approach:** use CAD kinematics and kinetic-energy equivalence near ride height. For vertical wheel velocity `v_w`, each component contributes translational `m_i*(v_i/v_w)^2` and rotational `I_i*(omega_i/v_w)^2` terms about the relevant component motion. Include geometry-induced rotations, not unrelated drivetrain spin. This generally varies with suspension position.

**Validation:** upright acceleration and measured wheel-hop modes can help assess the combined mass/stiffness prediction. A wheel-hop frequency alone does not uniquely determine unsprung mass when tire and suspension stiffness are also uncertain.

## 7. Geometry and CG: `a1`, `a2` [m]

**Equipment:** level corner scales, tape/laser measure, and effective unsprung-mass estimates.

Measure loaded wheelbase `L` between axle centres. Obtain front/rear scale loads and calculate longitudinal sprung-body CG. The following uses **full-axle forces in N** and **total front/rear axle effective unsprung masses**:

```matlab
Wf_sprung = Wf_measured - Mu_front_axle*9.81;
Wr_sprung = Wr_measured - Mu_rear_axle*9.81;
a1 = L * Wr_sprung / (Wf_sprung + Wr_sprung);
a2 = L * Wf_sprung / (Wf_sprung + Wr_sprung);
```

Convert scale kg readings to N by multiplying by 9.81, or perform the ratio using kg-equivalent values consistently. Do not subtract a per-wheel mass from a full-axle mass. Under the symmetry assumption, the resulting distances also apply to the one-side model; do not divide distances by two.

**Checks:** `a1 + a2 = L`; both distances should be positive for a sprung CG between axles. Reconstruct the front/rear static loads and compare with the scale readings within measurement/representation uncertainty.

**Is measuring with the driver enough?** It is the correct condition for a driver-loaded model, but uncorrected scale readings locate whole-car CG. The equations use sprung-body CG. The unsprung correction distinguishes them. CG location also does not determine pitch inertia.

CG height is not an input to this vertical/pitch baseline. It matters for later braking/roll/load-transfer extensions; a full CG-height test is not required merely to populate `a1` and `a2`.

## 8. Pitch inertia: `Iy` [kg m^2]

**Preferred first method: CAD mass properties.** Use the sprung assembly, correct component masses, driver/ballast distribution, fuel and payload. Calculate inertia about the transverse pitch axis through the sprung-body CG. For a one-side model, halve the total sprung-body pitch inertia, not the inertia of an unrelated quarter of the car.

**Equipment:** CAD model and measured component masses. For a later physical measurement, use an engineered inertia fixture with calibrated geometry and angle/time measurement, such as an encoder or IMU.

A properly designed physical-pendulum test can measure inertia. For an approximately rigid sprung assembly pivoted about a horizontal transverse axis a measured distance `d` above its CG, using small oscillations and negligible/corrected fixture effects:

`I_CG = M_sprung*g*d*(T/(2*pi))^2 - M_sprung*d^2`

Here `T` is the measured oscillation period. Subtract fixture inertia and account for its mass/CG contribution in a complete fixture model; do not apply the bare-body formula blindly to a heavy fixture. The result is sensitive to CG-distance error and bearing friction. Use representative secured ballast rather than an occupant.

**Important:** a normal on-tires body-pitch decay test is NOT this pendulum test. Tire and suspension stiffness/damping affect that period. A yaw-inertia rig does not automatically provide pitch inertia unless configured and analyzed for the correct axis.

**If no rig is available:** retain a documented CAD estimate and vary `Iy` over a justified uncertainty range. Do not adjust it solely to make one response graph match.

## 9. Suspension wheel rates: `k1`, `k2` [N/m]

The model requires vertical **wheel rate**, not the coil spring's catalog rate.

### Method A: spring test plus motion ratio

**Equipment:** spring tester or calibrated load cell and compression fixture; displacement gauges for spring and wheel travel.

1. Measure spring force versus compression over the operating range, using controlled loading/unloading. Fit the local slope `k_spring = dF/dx`; preload is an offset, not the spring rate.
2. With the chassis safely supported, move the wheel through positions around ride height. Record spring compression and vertical wheel-centre movement relative to the chassis.
3. Calculate `MR_s = delta_spring_compression / delta_vertical_wheel_travel` over the local range.
4. Enter `k_wheel = k_spring * MR_s^2` for each end, including installation geometry once.

If geometry changes substantially through travel, the rate is nonlinear. The constant-rate approximation uses a local value; preload and changing leverage can add geometric-stiffness effects beyond the simple squared-ratio approximation.

### Method B: measure wheel rate directly

Apply measured vertical force through a suitable hub/wheel-centre fixture while recording wheel-centre displacement relative to a fixed chassis. Control or characterize damper force, joint friction, anti-roll coupling, and other load paths. Use slow loading/unloading so viscous damper forces are small; average branches only if that treatment is justified.

A direct wheel-rate test should exclude tire compliance or measure wheel-centre motion separately. Ground-to-body displacement includes tire and suspension compliance in series and is not automatically suspension wheel rate.

**Validation:** compare measured front/rear relative travel during a low-amplitude test. Body/ wheel natural modes provide an additional system-level check, not a unique spring-rate measurement.

## 10. Damping coefficients: `c1`, `c2` [N s/m]

**Preferred equipment:** damper dynamometer with force measurement and shaft position/velocity, plus damper/wheel displacement measurements for motion ratio.

Test the intended click settings, gas pressure, operating temperature, and representative stroke/speed ranges. Record force versus shaft velocity separately for compression and rebound. Account for fixture inertia, gas-spring force, and seal friction as appropriate to the rig; do not interpret all measured force as viscous damping.

Fit a linear equivalent coefficient over a stated velocity range. For an ideal viscous branch `F = c_damper*v_shaft`; the actual curve can require an intercept/friction model or separate branches. A local slope is not necessarily the same as a secant `F/v` when offsets are present.

Measure `MR_d = shaft_travel / vertical_wheel_travel` near ride height, then convert:

`c_wheel = c_damper * MR_d^2`

Spring and damper motion ratios may differ. The current model uses one constant per end, so it cannot reproduce different compression/rebound behavior exactly. Document how the equivalent value was selected and the speed range where it is intended to apply.

**Low-equipment alternative:** a small-amplitude free-decay test with an IMU/travel sensor can constrain effective damping once masses and stiffnesses are known. In this coupled half-car, do not apply a single-degree-of-freedom logarithmic-decrement formula to an arbitrary mixed-mode trace. Use a justified isolated-mode fit or fit the complete measured response. Heavy damping may leave no usable oscillation peaks.

**Validation:** compare decay rate, overshoot, body acceleration, and front/rear travel across held-out tests. More damping is not automatically better. Keep temperatures controlled; real dampers can change behavior during repeated runs.

## 11. Vertical tire stiffness: `kt1`, `kt2` [N/m]

**Equipment:** calibrated vertical load cell or suitable scales, a tire/wheel loading fixture or controlled vehicle-loading arrangement, displacement gauge/laser, and pressure gauge.

Measure vertical force versus tire deflection at the actual inflation pressure, temperature, and operating load range. A dedicated tire-on-flat-platen rig best separates tire deflection from suspension movement. Alternatively, measure axle-centre-to-ground distance while changing known wheel load; account for wheel camber/orientation, fixture compliance, and floor motion.

For an unloaded reference radius `R0` and loaded hub-centre height `h`, deflection is approximately `delta = R0 - h` on a flat rigid surface. Fit the local slope:

`kt = delta_force / delta_deflection`

Use multiple load points around the operating load, on loading and unloading branches. A single `force / total_deflection` value is a secant and may not represent local stiffness. Record pressure before and after. Static stiffness may differ from dynamic stiffness; mark a static-derived value accordingly.

**Validation:** compare upright response and wheel-hop behavior when wheel acceleration is available. Tire pressure changes should be treated as new conditions, not unexplained changes in a supposedly fixed parameter.

**Simple starting decision:** if no tire test rig is available, keep `kt1`/`kt2` as explicit estimates, test sensitivity, and retain estimated normal-load warnings. No direct wheel-force sensor is required for this first step. Do not claim the tire rate or dynamic tire force is experimentally validated merely because body acceleration matches.

## 12. Road geometry and speed

### Bump inputs

**Equipment:** tape, straightedge/profile template or surveyed height measurements; digital level for the reference ground.

Measure height versus distance, total bump width along travel, flat edge-to-edge gaps, and the start position. Repeat measurements along the actual left/right wheel tracks. A driver must follow the intended track; left/right differences produce roll that this model omits.

Use `bump_shape = "cosine"` for a smooth controlled fixture when appropriate. Use a half ellipse only when its steep geometry is the intended input. Do not relabel a real obstacle as a cosine merely to get cleaner predictions; use the measured profile or document the shape approximation.

For N bumps, enter N heights, N widths, and N−1 gaps. Check profile dimensions independently of the dynamic data. Shape, gap, and height errors can otherwise be mistaken for damping errors.

### Vehicle speed: `vel` [m/s]

**Equipment:** wheel encoder, light gates, optical speed reference, or suitable GNSS/inertial instrumentation.

Measure actual speed through the obstacle, not only the driver's target. Wheel encoders require an effective rolling circumference and can be biased by slip. Light gates measure average speed over their separation; GNSS may update too slowly to resolve a short bump crossing by itself. Cross-check the chosen method on flat ground.

The current model assumes constant speed. Select runs with approximately constant measured speed over the event, using a pre-agreed tolerance, or extend the model to use measured distance versus time. Do not hide major acceleration or braking inside a constant-speed fit.

Check front/rear input delay using `delay = (a1+a2)/vel`. Comparing delayed road inputs and impact events is a useful synchronization check, but do not independently shift response channels until each appears to match.

## 13. What sensors validate each output?

| Model output | Measurement | Processing and comparison |
|---|---|---|
| Body acceleration at sprung CG | Sprung-body 6-axis IMU | Calibrate alignment and gravity; account for mounting offset; compare time histories, peaks and RMS over the same window |
| Body pitch rate | IMU gyroscope about transverse axis | Transform into the vehicle convention; compare with state `x(:,6)` |
| Body pitch angle | Validated attitude estimate or optical body tracking | Check reference/sign; dynamic accelerations can bias gravity-only inclination estimates |
| Front/rear suspension travel | Calibrated linear potentiometer or LVDT | Convert shaft stroke to wheel-equivalent travel using geometry and zero at ride height; current model defines positive relative travel as extension |
| Body displacement | Optical tracking, laser, or calibrated external video | Transform measurements to the sprung CG; remove static offset; do not rely on unconstrained double integration of acceleration |
| Wheel displacement/acceleration | Optical/laser tracking and/or upright accelerometer | Match vertical axis; acceleration validates dynamic wheel response but is not automatically a direct displacement measurement |
| Tire normal force | Wheel-force transducer or calibrated instrumented platen | Correct for sensor/fixture dynamics and load paths; indirect estimates must remain identified as estimates |

A damper sensor measures damper-shaft stroke, whereas model suspension travel is wheel-equivalent relative displacement. For small changes and a constant motion ratio, `delta_shaft = MR_d * delta_wheel_travel`; calibrate the sign and use a travel-dependent map if leverage changes appreciably.

At a stationary upright sensor, raw accelerometer readings include gravity in their specific-force convention. Convert sensor-frame specific force into world/vehicle acceleration using orientation and the correct gravity vector. In a world frame with z upward, the gravity vector points downward. Verify processing with a stationary test: corrected vertical dynamic acceleration should be near zero.

For an IMU away from the CG, acceleration also includes angular-acceleration and centripetal terms. Measure the sensor position and either transform the model prediction to the sensor location or correct the measurement. Do not compare an arbitrary chassis/seat location directly to CG acceleration without addressing this.

## 14. Acquisition settings and calibration

Start dynamic acquisition at **1000 Hz** on a common clock where equipment supports it; **500 Hz** is a practical initial alternative for the primary half-car channels. Sharp-impact peak measurements may require higher rates. These are starting recommendations, not universal accuracy guarantees.

The current example's undamped modes are approximately 1–1.2 Hz and 8–10 Hz, but impact content can extend above them. At 10 m/s, a 0.4 m bump lasts 0.04 s: 100 Hz gives about 4 samples during crossing, 500 Hz gives 20, and 1000 Hz gives 40.

Use appropriate anti-alias filtering before sampling. Verify actual sensor bandwidth and update rate, not just logged row frequency. Record noise, range, clipping, dropped samples, timestamp behavior, filter delays, and channel synchronization. Slower speed/GNSS channels can use their genuine timestamps; repeated values do not create new information.

Before track tests:

- Zero travel sensors at the defined equilibrium and calibrate through known displacements; check end-of-travel headroom.
- Check IMU axes, gyro bias, scale and orientation; record stationary data before and after the run.
- Calibrate speed against a measured distance/reference and identify slip-sensitive conditions.
- Test all channels together with a common physical event or hardware trigger; document residual timing uncertainty.
- Select matched filtering for simulated and measured comparison signals. Avoid comparing differently filtered peaks or ignoring filter delay.

To select a defensible minimum sample rate, acquire a representative pilot at an adequately high rate (for example 1000–2000 Hz where sufficient), then low-pass and downsample. Compare peaks, RMS, travel and timing against predefined error allowances. The original acquisition itself must be adequate; downsampling tests cannot reveal peaks already missed by an undersampled sensor.

## 15. Whole-vehicle validation campaign

### Stage A: establish conditions

Complete mass/CG/geometry measurements, confirm spring/damper conversions, record tire condition, estimate uncertainty, and inspect the fixture/vehicle. Check static ride position and available compression/rebound travel. Those limits are not presently enforced by the linear model.

### Stage B: low-amplitude single bumps

Begin with a small, measured bump at low controlled speed, within available travel and continuous contact. Record body IMU, both travel sensors, speed, and road/trigger timing. Repeat runs before changing anything. Compare front/rear event timing, acceleration, pitch rate, travel, and recovery.

### Stage C: held-out variation

After any necessary parameter fitting, reserve different runs for validation. Vary speed, bump width/height, and then repeated-bump gaps in controlled steps. Do not tune on every run and report the same runs as independent validation.

### Stage D: evaluate residuals and applicability

Compare aligned time histories, peak values, RMS over identical windows, decay, and selected frequency content. Track measurement scatter and parameter uncertainty. Set acceptance limits based on intended design use and sensor uncertainty before evaluating final validation cases; a universal 5% or 10% criterion is not defensible for every output.

Diagnose structured errors: timing errors suggest speed/geometry/synchronization; wrong travel amplitudes may suggest rates or motion ratios; wrong decay can suggest damping; strong impact-only errors can indicate tire/contact or nonlinear behavior. These are hypotheses, not unique diagnoses.

If predicted normal loads become negative, flag the continuous-contact assumption. Do not treat post-violation response as validated contact behavior. A visually plausible curve cannot establish that wheels remained in contact. Independent observation/force evidence is needed to validate actual lift-off behavior in a future nonlinear model.

## 16. Numerical and display inputs: how to check them

These do not require vehicle sensors, but they must be documented for reproducibility.

| Input / item | Test or check |
|---|---|
| `simulation_dt` | Repeat with half the actual step and compare selected metrics; also inspect relevant waveform features |
| `run_convergence_check` | Enable for numerical assessment; retain original/refined values and configured tolerances |
| Relative and absolute convergence tolerances | Choose for intended numerical precision; they are not physical-validation criteria |
| `tF`, `post_bump_time` | Confirm both wheels clear the road event and the recorded window includes the desired settling; use identical RMS windows for comparisons |
| `dx_r_1`, `dx_r_2`, bump profile sampling | Refine spatial road sampling separately; temporal convergence holds the road samples fixed |
| `x_r_1_total`, `x_r_3_total` | Verify actual road start/end coverage and the event location against the measured track |
| `playback_speed`, `video_fps` | Change them while keeping engineering inputs fixed; numerical results should remain identical |
| Animation dimensions and drawing offsets | Check visual presentation only; they do not measure or enforce physical sag, tire radius, or travel limits |
| `C_damping`, `C_output`, state matrices | Verify construction, units, symmetry/stability where applicable, and state order; these are derived matrices, not separately measured vehicle properties |

The script's half-step check uses `absolute_tolerance + relative_tolerance*abs(refined_metric)`. A pass supports numerical consistency of those metrics, not real-world correctness or convergence of every waveform. A converged run can still violate contact assumptions.

## 17. Record sheet for every parameter

Use the Excel iteration tracker for run inputs/outputs and retain a parameter-measurement record with these fields:

| Record field | What to enter |
|---|---|
| Parameter / variable / units | For example, front wheel rate `k1`, N/m |
| Vehicle / loading condition | Driver or ballast, fuel, payload, pressure, ride position |
| Source / method | Measured, manufacturer data, CAD, or explicit estimate |
| Instrument / calibration | ID, range, resolution, calibration date, mounting |
| Raw data location | Original file and test photos; do not retain only the fitted number |
| Fit and operating range | Equation, branch, displacement/velocity/load range, exclusions |
| Repeats / uncertainty | Scatter, calibration uncertainty, geometry assumptions, sensitivity range |
| Model value and conversion | Final SI value, motion ratio, per-side/axle convention |
| Independent check | What separate observation supports the value |
| Owner / date / version | Who measured it and which code/parameter version used it |

For each vehicle run, save the complete parameter set, measured road, speed record, sensor locations/calibrations, raw channels, processing settings, simulation results, comparison plots, contact/convergence status, conclusion and code commit. A commit alone does not capture uncommitted parameter edits.

## 18. Recommended order for a small Baja team

1. **First:** measure loaded mass, wheelbase, sprung CG estimate, tire pressures, spring data and motion ratios; inventory unsprung components. Use CAD for inertia.
2. **Next:** install a sprung-body IMU, front/rear travel sensors, speed reference and synchronized DAQ. Measure the test bump.
3. **Then:** run repeatable low-amplitude tests, verify units/timing, and compare acceleration, pitch rate and travel.
4. **As resources allow:** obtain damper dyno and tire stiffness measurements; add upright acceleration and better displacement tracking.
5. **Only when justified:** add nonlinear damping, travel stops, tire contact loss/recontact and more detailed geometry, then repeat validation.

Keep estimates clearly marked rather than blocking all progress until every specialist sensor is available. The result should be a model trusted over a documented operating range, not a claim that every possible Baja event has been validated.

## 19. Status and supporting material

This is a proposed practical test guide based on the current repository model and engineering measurement principles. No tests described here have been performed by creating this document, and no sensor-specific accuracy or certification is claimed. Follow the selected equipment's actual specifications and calibration instructions.

Related repository files: `docs/HALF_CAR_MODEL_REPORT.md` for the assumptions/development roadmap; `docs/Half_Car_Iteration_Tracker.xlsx` and `docs/ITERATION_TRACKER_GUIDE.md` for iteration records; `tests/test_half_car_model.m` for MATLAB numerical regression checks. The script and helper require MATLAB with Control System Toolbox. Numerical testing and physical validation remain separate activities.
