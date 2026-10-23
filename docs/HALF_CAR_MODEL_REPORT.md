# Half-car model: assumptions, validation, and development report

**Status:** Living engineering report / working draft.  
**Baseline:** Repository commit `5b2f637`, plus the documentation, independent simulation timing, dashboard, cosine-road option, and convergence-check changes in this revision.  
**Purpose:** Explain the model to new team members, record engineering decisions, and guide future improvements. This report documents recommendations; it does not establish that the model is physically validated.

## 1. Purpose and current capability

The MATLAB half-car model predicts vertical suspension response along one side of a vehicle, or an equivalent front/rear axle representation if all parameters are scaled consistently. It has four motion coordinates: sprung-body vertical displacement, body pitch, front unsprung displacement, and rear unsprung displacement.

The model represents suspension springs, linear viscous dampers, and vertical tire stiffness. The front and rear wheels follow the same spatial road profile with a wheelbase-dependent time delay. The script supports a single bump or consecutive bumps (smooth cosine by default, with a half-ellipse option) with independently specified heights, widths, and flat gaps. It generates displacement plots and an animation/video.

Useful questions include: How does the body respond to a bump? Does it recover before the next bump? How do spring rate, damping, speed, and spacing change bounce and pitch? These predictions can guide tests and compare candidate designs within the model's valid range.

### Implementation status

| Item | Status at this report baseline |
|---|---|
| Four-degree-of-freedom linear equations and axle delay | Implemented |
| Damping-matrix typo correction | Implemented |
| Independent bump dimensions and consecutive-bump toggle | Implemented |
| Comments describing input conventions | Included in this revision |
| Static-load calculation, dynamic tire loads, contact warning | Implemented in this revision; estimated, not measured |
| Separate acceleration, pitch, travel, and tire-load dashboard | Implemented in this revision; six linked time panels |
| Independent simulation/video timing | Implemented in this revision; video interpolates completed results |
| Optional video capture | Implemented in this revision: fixed-size explicit figure, video FPS, and error cleanup; MATLAB GUI not yet tested |
| Numerical verification | Independent Python numerical cross-check and MATLAB syntax parsing passed; MATLAB regression suite added but unrun (runtime unavailable) |
| Physical validation | Not established |

## 2. Inputs and conventions

### Mass, inertia, and geometry

Choose and document one convention before using results for design:

- **Symmetric one-side representation:** half the total sprung mass, half the total sprung-body pitch inertia, one front and one rear wheel assembly's effective unsprung mass, and per-wheel suspension/tire properties.
- **Axle-equivalent representation:** full sprung mass and pitch inertia, front/rear axle unsprung masses, and summed left/right stiffnesses and damping coefficients.

Do not mix these conventions or halve a value already supplied per side. Include driver, fuel, and payload consistently. Sprung mass excludes unsprung mass. Effective unsprung mass includes more than the tire: hub, brake, upright, and appropriate suspension contributions matter.

| Variable | Meaning | Units / instruction |
|---|---|---|
| `m` | Represented sprung-body mass | kg; not total mass including wheels |
| `m1`, `m2` | Front / rear effective unsprung masses | kg; match the chosen representation |
| `Iy` | Sprung-body pitch inertia about its CG | kg·m²; obtain from CAD or measurement, with the same mass condition |
| `a1`, `a2` | Sprung-body CG distance to front / rear axle | m; wheelbase = `a1 + a2` |
| `k1`, `k2` | Front / rear vertical suspension wheel rates | N/m; not raw coil-spring rates |
| `c1`, `c2` | Front / rear wheel-equivalent viscous damping | N·s/m; not damping ratios or damper click settings |
| `kt1`, `kt2` | Front / rear vertical tire stiffness | N/m; dependent on tire, pressure, and operating load |
| `vel` | Constant forward speed | m/s; divide km/h by 3.6 |

### Spring rate versus wheel rate

The equations act at the wheel. With motion ratio defined as spring compression divided by vertical wheel travel:

`k_wheel = k_spring * MR_s^2`

For example, `14600 N/m` and `MR_s = 0.67` give `6553.94 N/m` at the wheel. Use a ride-height motion ratio for this constant-rate approximation, including installation geometry once. Convert N/mm to N/m by multiplying by 1000; convert lbf/in to N/m by approximately 175.127.

### Damping

With damper motion ratio defined as damper-shaft travel divided by vertical wheel travel:

`c_wheel = c_damper * MR_d^2`

For an ideal linear damper, force equals coefficient times shaft velocity. Real dampers can have different compression and rebound curves and velocity-dependent slopes. Use measured force–velocity data to choose an equivalent coefficient for the test range. Spring and damper motion ratios may differ.

The example `c1 = c2 = 10000 N·s/m` needs verification. A simplified uncoupled bounce estimate gives a damping ratio near 3.2 for the present parameters; this is a screening estimate, not the exact coupled modal damping. Do not replace the values solely to obtain a visually pleasing graph.

### Tire stiffness

The current `kt1 = kt2 = 200000 N/m` equals `200 N/mm`. This is an assumed linear vertical tire rate, not a measured property of the team's tires. No suspension motion-ratio conversion applies to it. Record tire pressure, load, and the source of the assumption; measure or refine it later.

### Road and display inputs

Heights, widths, and gaps are in metres. Width is along the travel direction; gaps are edge-to-edge flat distances, not centre-to-centre spacing. N bumps require N heights, N widths, and N−1 gaps. `consecutive_bumps = "no"` uses the single-bump inputs; `"yes"` uses the lists.

The `z_s_static` and `z_u_static` animation values are drawing offsets. They do not calculate physical sag or preload. Dynamic coordinates are relative to equilibrium.

### Is a CG measurement with the driver enough?

A driver-in-car measurement is the right loading condition if that is the condition being simulated. It establishes CG location for that condition, not the pitch inertia, spring rates, or damper behavior. Keep fuel, driver posture, and payload consistent.

Axle scales give whole-vehicle longitudinal CG. The body coordinates in this model require sprung-body CG. On level ground, if `W_front` and `W_rear` are measured ground loads in N and use the SAME per-side or axle convention as `m1` and `m2`:

```matlab
sprung_front_load = W_front - m1*9.81;
sprung_rear_load  = W_rear  - m2*9.81;
a1 = wheelbase * sprung_rear_load / (sprung_front_load + sprung_rear_load);
a2 = wheelbase * sprung_front_load / (sprung_front_load + sprung_rear_load);
m  = (sprung_front_load + sprung_rear_load)/9.81;
```

These estimates assume effective unsprung masses at the axle locations. Do not combine full-axle scale loads with per-wheel unsprung masses. Do not assign `Iy` from CG location; determine inertia separately for the sprung body including the driver. CG height is not an input to this vertical/pitch baseline, but matters in more complete braking, roll, and load-transfer models.

## 3. Assumptions and limits

The baseline assumes a rigid sprung body, small pitch angles, linear springs, constant linear damping, constant speed, a common front/rear road track, and continuous tire contact. It omits roll, left/right differences, suspension geometry variation, bump stops, droop limits, tire lift-off/recontact, and detailed terrain/tire interaction.

Omitting explicit gravity from the current perturbation equations is not automatically an error: they describe motion about static equilibrium. Static loads must nevertheless be restored when calculating total ground contact force and travel margins.

The half-ellipse road has steep edges. The default is now a raised-cosine bump with zero slope at its joins to flat ground. Set `bump_shape = "half_ellipse"` to reproduce the original shape or `"cosine"` for smooth joins. A cosine is a controlled test input, not automatically a more accurate representation of a particular real obstacle. Measured road profiles remain future work. Sharp obstacles may require finite-radius tire enveloping rather than point road sampling.

## 4. Recommended simple tire-load check

**Implemented approach:** retain the linear model and calculate an estimated contact-validity warning, without attempting a full nonlinear tire-contact simulation.

Measured wheel-load data is not required to make an initial estimate. Use the existing mass, CG, geometry, and tire stiffness inputs, while clearly marking them as assumed or measured. An estimated warning is not a replacement for vehicle validation.

For level ground, static equilibrium, vertical ground forces, and the model's lumped unsprung masses at their axles:

```matlab
g = 9.81;
L = a1 + a2;
Fz_front_static = m*g*a2/L + m1*g;
Fz_rear_static  = m*g*a1/L + m2*g;
```

These are per-wheel loads for a one-side model and per-axle loads for an axle-equivalent model. Their sum should equal `(m + m1 + m2)*g`.

For the current upward-positive displacement convention and a tire spring without tire damping, the implemented calculation in `simulate_half_car.m` is equivalent to:

```matlab
Fz_front = Fz_front_static + kt1*(u1(:) - zu1);
Fz_rear  = Fz_rear_static  + kt2*(u2(:) - zu2);
contact_violation = (Fz_front < 0) | (Fz_rear < 0);

if any(contact_violation)
    first_bad = find(contact_violation, 1);
    warning(['Continuous-contact assumption violated at t = %.4f s. ' ...
        'Results from this point onward may be unreliable.'], time(first_bad));
end
```

Record each minimum load, the first violation time, and whether the run remains within the continuous-contact assumption. Forces approaching zero also deserve review because parameter uncertainty can change the predicted contact status.

**Do not clamp negative forces to zero in the output while leaving the dynamics unchanged.** That changes the display, not the physics. Lift-off and recontact require a nonlinear contact model that changes the forces in the equations of motion.

An earlier independent Python reproduction of the baseline default bump (0.2 m high, 0.4 m wide, 10 m/s) predicted negative normal loads. This is a model-validity warning, not a prediction that tires exert tensile road forces. That investigation was not a MATLAB execution or a physical test. Its exact analysis script was not committed; recreate and archive it before citing numerical results externally.

Until contact dynamics are implemented, use moderate test inputs and screen each run. Smaller bumps do not guarantee validity; check the estimated loads and suspension travel.

## 5. Reading and improving the outputs

The dashboard now uses separate panels for road inputs, body displacement, pitch angle, body acceleration, suspension travel, and tire loads, with linked time axes. Units are displayed in mm, degrees, m/s², and N. The road-geometry plot uses distance; all dashboard panels correctly use seconds. Keep axis scales consistent when comparing runs. A contact warning is also shown in the dashboard title when detected on the main simulation grid.

With this script's pitch convention:

```matlab
front_travel = z - a1*theta - zu1;
rear_travel  = z + a2*theta - zu2;
```

These are relative displacement changes, not absolute available compression or rebound. Apply static position, actual travel limits, and motion ratio when comparing with damper stroke or bump-stop clearance.

Calculate acceleration from the equations and state velocities rather than unnecessarily differentiating noisy displacement. Add acceleration at the driver location when assessing ride: body pitch means CG acceleration is not necessarily driver acceleration.

Recommended summary metrics are peak and RMS body acceleration over a stated interval, peak pitch, maximum compression/rebound travel, minimum tire normal load, and settling time within an explicitly defined band. A raw acceleration RMS is not automatically a standards-based ride-comfort rating.

### Ride frequency

A clean, single-bump free decay can provide a damped oscillation estimate: `f = number_of_cycles / elapsed_time`. Measure between same-direction peaks after both wheels have cleared the bump. Repeated-input peak spacing can instead reflect the road forcing frequency. Heavy damping or mixed bounce/pitch modes can make peak timing unreliable.

Undamped coupled natural frequencies come from `eig(K,M)`. An independent calculation of the baseline parameters gave approximately 0.98, 1.18, 8.43, and 10.02 Hz. Mode shapes are needed to identify body-dominated and wheel-dominated modes. These are model calculations, not measured vehicle frequencies.

## 6. Data acquisition and sampling-rate guidance

**Recommended starting configuration:** acquire the main dynamic channels together at **1000 Hz** if supported. **500 Hz** is a practical alternative for initial validation. Neither rate guarantees accurate impact peaks; the required rate depends on bandwidth, event duration, sensor characteristics, and the allowable error.

| Measurement / objective | Practical starting rate |
|---|---|
| Smooth-test body bounce and pitch | 100–200 Hz |
| Suspension travel and wheel-hop response | 200–500 Hz |
| Common acquisition rate for initial validation | 500 Hz; preferably 1000 Hz |
| Sharp-impact acceleration peaks | 1000 Hz or higher; determine through pilot tests |

The current model's approximately 1–1.2 Hz body modes and 8–10 Hz wheel modes do not define the full bandwidth of an impact. The theoretical Nyquist condition requires sampling above twice the highest retained signal frequency, with adequate anti-alias filtering. For useful waveform and peak resolution, roughly 10–20 samples per cycle of interest is a starting guideline, not an accuracy guarantee.

A 0.4 m bump crossed at 10 m/s lasts 0.04 s:

| Sampling rate | Approximate samples during crossing |
|---|---:|
| 100 Hz | 4 |
| 500 Hz | 20 |
| 1000 Hz | 40 |

### Requirements beyond the sample rate

- Apply appropriate anti-alias filtering before sampling. Digital filtering afterward cannot undo aliasing already introduced.
- Synchronize IMU, suspension travel, and speed measurements using a common clock or a verified synchronization method; preserve timestamps.
- Check actual sensor bandwidth, internal filtering, update rate, noise, range, clipping, and mounting. A 1000 Hz data stream does not prove 1000 Hz of independent measurements.
- Use a suitable acceleration range for pilot tests; inspect saturation and missing samples before drawing conclusions.
- Save raw data and document calibration, units, orientation, filters, tire pressure, loading condition, and sensor positions.
- Differentiate between fast DAQ sampling and the update rate of speed sensors such as GNSS. Repeated or interpolated readings do not create new measurements.

### Establishing a defensible minimum

Record a representative pilot at 1000 or 2000 Hz, or higher if the required impact bandwidth demands it. Low-pass filter before downsampling. Compare lower-rate results against the original acquisition using peak acceleration, RMS acceleration, travel, and event timing. Select the lowest rate that satisfies predefined tolerances and retain enough bandwidth for the intended analysis. The original high-rate record must itself have adequate sensor bandwidth and anti-alias protection.

Physical data-acquisition rate is separate from the simulation time step. Demonstrate numerical convergence independently. The script now uses `simulation_dt` independently of `playback_speed` and `video_fps`. Changing playback controls cannot change the simulation time grid or the engineering solution.

### How to use the time-step convergence check

Start with `simulation_dt = 0.001` seconds. With `run_convergence_check = true`, the script runs the same vehicle, road, speed, and end time again with half the actual time step (approximately 0.0005 seconds). Both grids share the same duration and the refined grid includes every coarse time point. Actual spacing may be slightly smaller than requested so that the end time is exact.

The Command Window shows original and refined values for peak absolute body displacement, pitch, acceleration, front/rear suspension travel, minimum front/rear tire loads, and whole-run RMS body acceleration. PASS requires each absolute metric change to be at most:

`absolute_tolerance + relative_tolerance * abs(refined_metric)`

The default relative tolerance is 1%. Absolute tolerances are 0.01 mm for displacement/travel, 0.00001 rad for pitch, 0.01 m/s² for peak/RMS acceleration, and 1 N for minimum tire loads. They are editable numerical screening choices, not validated design criteria. The absolute term avoids a meaningless percentage comparison near zero.

If the check fails, reduce `simulation_dt`, rerun, and inspect which metric changed. The plotted and exported engineering arrays remain the ORIGINAL-step solution; the comparison does not silently substitute the refined run. Passing is evidence of time-step consistency for the selected metrics, not physical validation or proof of full waveform accuracy. Road spatial sampling is held fixed, so road-profile resolution needs a separate check. A converged solution can still violate tire contact assumptions.

### Current controls and file requirements

Keep `half_car_model.m` and `simulate_half_car.m` together on the MATLAB path. The entry script requires MATLAB with Control System Toolbox; the dashboard uses features available in R2018b and later. Run from the repository folder.

- `simulation_dt`: maximum engineering time step in seconds.
- `post_bump_time`: seconds after the rear axle clears the final bump; the flat road extends automatically.
- `run_convergence_check`: repeats the solve at half the time step when true.
- `enable_animation`: false skips all animation/video and leaves the engineering plots/results.
- `save_video`: false previews animation without writing video (only used when animation is enabled).
- `playback_speed`: ratio of simulated seconds to playback seconds; 0.1 gives tenfold slow motion.
- `video_fps`: output frames per playback second. Rendering interpolates completed results; it does not alter the simulation.

Video encoding support is platform-dependent. The code uses an explicit, fixed-size figure and `drawnow`, checks frame dimensions, and attempts to close the writer on errors. Video errors leave the engineering results available. The live preview targets the requested speed but can be slower if rendering is expensive. GUI/video behavior remains untested in this cloud environment.

## 7. Proposed physical validation

| Measurement | Instrument / method | Use |
|---|---|---|
| Body vertical acceleration and pitch rate | Rigidly mounted 6-axis IMU near sprung-body CG | Compare body dynamics |
| Front/rear suspension travel | Linear potentiometers or LVDTs | Compare relative travel, accounting for motion ratio |
| Wheel acceleration, when available | Accelerometers on uprights | Check wheel-hop response |
| Speed and position reference | Encoder plus independent speed reference where practical | Reconstruct road timing and axle delay |
| Road input | Measured bump fixture or surveyed profile | Supply known input geometry |

Start with measured single bumps at low speed; progress to repeated identical bumps and additional speeds. Keep loading and tire pressure controlled. Repeat runs to characterize scatter.

Correct IMU orientation and gravity before comparing accelerations. If the IMU is offset from the CG, account for rotational acceleration. Compare gyro pitch rate directly where possible to avoid integration drift. Do not obtain wheel displacement by double-integrating acceleration without a justified drift-control method.

Tune parameters on a subset of runs and assess accuracy on held-out runs. Agree on acceptance criteria before the final comparison; there is no universal percentage error that makes every suspension model acceptable. Retain the validated operating range and known failures with the model.

## 8. Prioritized development plan

| Order | Work | Evidence of completion |
|---|---|---|
| 1 | Confirm input conventions and parameter sources | Parameter sheet with units, loading condition, measured/estimated status, and uncertainty |
| 2 | Add estimated tire-load warnings and travel outputs | Known cases exercise warnings; force/sign conventions checked |
| 3 | Separate simulation timing from video; make animation optional | Identical engineering results with video on/off and different playback settings |
| 4 | Add clear dashboard, metrics, and saved run metadata | Reproducible comparisons with inputs and code version attached |
| 5 | Add numerical verification | Automated flat-road, axle-delay, matrix, stability, static-response, and convergence checks |
| 6 | Conduct controlled physical tests | Repeatable measurements and held-out comparison report |
| 7 | Add nonlinear features when justified | Bump stops, rebound/compression curves, contact loss/recontact, then further geometry or tire detail |

For maintainability, separate vehicle parameters, road generation, matrix construction, simulation, analysis, plotting, and animation into small functions. Keep one simple entry point. Damping and output matrices are now named `C_damping` and `C_output`; `D_output` names the feedthrough matrix. The core calculation is in `simulate_half_car.m`. Provide a README with a minimal example, MATLAB/toolbox requirements, sign conventions, and known limitations.

Verification should include zero response on flat road with zero initial conditions; correct wheelbase delay; symmetric mass/stiffness/damping matrices with expected definiteness; stable positive-parameter dynamics; equal constant road heights eventually producing equal body/wheel displacement and zero pitch; and consistent key metrics as sampling is refined.

## 9. Using this report for future cars

Keep a versioned parameter set for each vehicle and loading condition. Reuse common road cases and metrics to compare candidates, but revalidate after changes that affect mass distribution, tires, motion ratios, or damper behavior. A validated linear baseline is useful for screening designs; it does not establish rollover behavior, structural durability, or landing performance outside its assumptions.

For each future update, record the problem, change, assumptions, parameter sources, verification results, physical evidence, and remaining limitations. The goal is a traceable model whose predictions are trusted within a stated range, with clear warnings outside it.

## 10. Evidence and open questions

This report is based on the repository script, the team's discussion, and the earlier independent numerical review. It is not a completed literature review: external research/team sites were inaccessible during the review, so no verified comparison with specific papers or Baja teams is claimed.

Open questions before design sign-off:

- Do current masses, rates, and `Iy` all use the same one-side or axle-equivalent convention?
- Are suspension rates wheel-equivalent, and what are the spring/damper motion ratios?
- What are the measured damper curves, tire pressure/load dependence, and available travel limits?
- What accuracy and operating range does the team need?
- Which sensors, bandwidths, ranges, synchronization, and acquisition hardware are available?

### Update record

| Revision | Change | Validation status |
|---|---|---|
| Initial working draft | Consolidated assumptions, input comments, simple tire-load proposal, sampling guidance, validation, and improvement roadmap | Documentation only at initial drafting |
| Implementation update | Independent simulation/video controls, default cosine road, optional animation, six-panel dashboard, estimated contact warning, descriptive matrix names, and time-step comparison | MATLAB regression suite added but unrun; independent numerical checks described in README; physical validation outstanding |

### Verification evidence for this update

`tests/check_numerics.py` reads the actual MATLAB parameter and matrix literals. The independent SciPy checks passed for single, consecutive, and touching bumps with both cosine and half-ellipse profiles; all eight selected metrics met the configured time-step allowances at the example settings. Additional checks passed for force/energy matrix construction, stability, static-load balance, zero flat-road response, uniform-road equilibrium, contact-violation detection, rendering-independent calculations, and agreement between the state-space solution and an independently integrated ODE with matching input interpolation. MATLAB syntax parsing passed for the entry script, solver helper, and regression suite.

These checks do not execute MATLAB or verify its plotting/video APIs. The MATLAB suite in `tests/test_half_car_model.m` remains unrun. No physical validation or published performance claim follows from these numerical checks.
