# Half-car MATLAB model

A four-degree-of-freedom linear model of body bounce/pitch and front/rear wheel motion. Includes single or consecutive bumps, an engineering dashboard, estimated tire-load warnings, optional animation, and a time-step comparison.

## Run

Use MATLAB R2018b or later with **Control System Toolbox**. Keep `half_car_model.m` and `simulate_half_car.m` together, open the repository folder in MATLAB, then run:

```matlab
half_car_model
```

Edit the input section of `half_car_model.m`. The comments explain units, mass conventions, wheel rates versus spring rates, and damping conversion. Existing vehicle values are examples needing verification.

| Setting | Purpose |
|---|---|
| `simulation_dt = 0.001` | Maximum engineering sample interval, seconds |
| `post_bump_time = 1` | Seconds after the rear wheel clears the last bump |
| `run_convergence_check = true` | Compare the same run at half the time step |
| `bump_shape = "cosine"` | Smooth joins; use `"half_ellipse"` for the original profile |
| `consecutive_bumps = "no"` | Use `"yes"` to enable per-bump height/width/gap lists |
| `enable_animation = true` | Use `false` for plots and numerical results only |
| `save_video = true` | Save MPEG-4 when animation is enabled; platform codec support required |
| `playback_speed = 0.1` | Slow-motion ratio; affects rendering only |
| `video_fps = 30` | Video/preview frame rate; affects rendering only |

The dashboard separates road inputs, body displacement, pitch, body acceleration, suspension travel, and estimated normal loads. Time axes are linked. Engineering arrays are available in `results`; the optional half-step solution is in `refined_results`. Changing playback cannot change either solution.

The convergence table compares selected metrics against editable absolute tolerances plus a 1% relative tolerance. A pass is a numerical consistency check, not physical validation. On failure, reduce `simulation_dt` and rerun. Road spatial resolution is held fixed. The main plots always show the original-step solution.

Negative estimated tire loads flag a violation of the continuous-contact assumption. The linear equations do not simulate lift-off or recontact. A cosine bump can still violate this assumption, especially with the severe example dimensions. No measured wheel-load data is required for an initial estimate, but input uncertainty affects accuracy.

## Report

See [the living engineering report](docs/HALF_CAR_MODEL_REPORT.md) for assumptions, parameter conventions, CG measurement guidance, a validation plan, sampling-rate recommendations (500–1000 Hz as a starting range), and the improvement roadmap.

## Verification

Run the MATLAB regression tests from the repository root:

```matlab
test_results = runtests('tests/test_half_car_model.m');
assertSuccess(test_results);
```

The tests use temporary script copies, disable animation, and check playback independence, flat-road/static loads, matrix structure, the six-panel dashboard, consecutive bumps and both shapes, convergence/contact status, and missing-road rejection. **The MATLAB suite has not yet run in the cloud environment because MATLAB is unavailable. GUI/video behavior remains unverified.**

An independent Python cross-check reads the MATLAB parameter/matrix literals and checks force/energy construction, stability, flat-road equilibrium, time-step comparisons for both shapes and multiple bump configurations, the contact warning case, and agreement with an independent ODE integrator. It is a cross-check, not execution of MATLAB code:

```bash
python tests/check_numerics.py
```

Requires NumPy and SciPy. These numerical checks passed during this update. Optional `tree-sitter` and `tree-sitter-matlab` packages enable syntax parsing of all MATLAB files; syntax checks also passed. The numerical test is based on the current example parameters, so intentionally changing those values may require revisiting its expected outcomes.

Physical vehicle validation is still outstanding. Review the report before using predictions to select hardware.

## Iteration log

Use [the offline Excel iteration tracker](docs/Half_Car_Iteration_Tracker.xlsx) to record each run's inputs, outputs, confidence checks, and graph paths. It includes a two-run comparison page, per-bump road records, and header guidance. The example inputs are marked not run and all engineering outputs are blank. See [the tracker guide](docs/ITERATION_TRACKER_GUIDE.md) for the manual recording workflow and sharing graph files.

## Measuring parameters and validating the vehicle

See the [parameter test guide](docs/HALF_CAR_PARAMETER_TEST_GUIDE.md), also available as a [Word document](docs/Half_Car_Parameter_Test_Guide.docx). It covers equipment, measurement procedures, wheel-rate/damping conversions, driver-loaded sprung CG, pitch inertia, sensor processing, sampling, and a staged validation plan. It is a proposed procedure, not a report of completed physical tests.
