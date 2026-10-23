%% Half car model
% Simulation and animation of a half car model.
%
% UPDATE SUMMARY (2026-10-23)
% - Documented units, wheel-rate / spring-rate and damper conversions,
%   consistent mass / inertia scaling, driver-loaded CG, and road inputs.
% - Decoupled simulation_dt from playback_speed and video_fps; rendering
%   interpolates completed results and cannot change engineering outputs.
% - Added post_bump_time for observing settling after the final bump.
% - Made cosine bumps the default; half_ellipse remains selectable, with
%   the existing single / consecutive bump heights, widths, and gaps.
% - Renamed the physical damping matrix C_damping and output matrix C_output;
%   C_output = eye(8) returns all four displacements and four velocities.
% - Moved the numerical solve / metrics into simulate_half_car.m, which
%   must remain on the MATLAB path alongside this entry script.
% - Added estimated static / dynamic tire loads and a negative-load warning.
%   This flags the continuous-contact limit; it does NOT simulate lift-off.
% - Replaced crowded plots with six linked, unit-labelled panels: road,
%   body bounce, pitch, acceleration, suspension travel, and tire loads.
% - Added an optional half-time-step convergence check and metrics table.
%   Numerical convergence is not physical validation; original-step results
%   remain the main plotted solution even when the check fails.
% - Made animation / video optional, set explicit video FPS and a fixed-size
%   capture figure, checked frame sizes, and added writer error cleanup.
% - Added README instructions, an engineering report (including sensor
%   sampling guidance), MATLAB regression tests, and a Python cross-check.
% - Independent Python numerical checks and MATLAB syntax parsing passed.
%   MATLAB execution / graphics / video and physical validation remain unrun.
% See docs/HALF_CAR_MODEL_REPORT.md for assumptions and the improvement plan.
%
%%

clear ; close all ; clc

%% Parameters

% INPUT CONVENTIONS -- read before replacing the example values below.
% Use SI units: kg, m, s, N/m, N*s/m, and kg*m^2.
% These example values have not been validated against your actual vehicle.
%
% MASS / INERTIA: choose one consistent representation for ALL inputs.
% For a symmetric one-side half-car: use half the total sprung mass and
% half the total sprung-body pitch inertia, plus ONE front and ONE rear
% wheel assembly's unsprung mass, suspension wheel rate, damping, and tire
% stiffness. Do not halve a value already specified per wheel / per side.
% An axle-equivalent model instead uses full sprung mass / pitch inertia,
% both wheels' unsprung masses per axle, and summed axle rates / damping.
% Do not mix these representations. The existing numbers need confirmation.
% Include driver / fuel / payload in the chosen sprung-mass condition.
% Unsprung mass is the effective mass moving with each wheel, not just the
% tire: include upright, hub, brake, and appropriate suspension contributions.

% Masses and sprung-body pitch inertia
m   = 840/2;    % Sprung mass represented by this model; EXCLUDE unsprung [kg]
m1  = 53;       % Front unsprung mass represented by this model           [kg]
m2  = 152/2;    % Rear unsprung mass represented by this model            [kg]
Iy  = 1100;     % Sprung-body pitch inertia about CG; use same scale as m [kg*m^2]
% Iy is NOT mass. Obtain from CAD / measurement for the same mass condition.

% Geometry: CG of the sprung body; a1 + a2 is the wheelbase.
% Measure with the driver / fuel / payload used in the simulation.
% Axle scales give WHOLE-VEHICLE CG. For this sprung-body model, subtract
% the unsprung loads before calculating CG distances (see the report).
% CG location does not determine pitch inertia Iy; that is a separate input.
a1  = 1.4;      % Longitudinal distance from sprung-body CG to front axle [m]
a2  = 1.47;     % Longitudinal distance from sprung-body CG to rear axle  [m]

% SUSPENSION STIFFNESS: enter effective VERTICAL WHEEL RATES, not raw
% coil-spring rates. With MR_s = spring compression / vertical wheel travel:
%     k_wheel = k_spring * MR_s^2
% Example: 14600 N/m spring, MR_s = 0.67 -> 6553.94 N/m wheel rate.
% Convert N/mm to N/m by multiplying by 1000; lbf/in to N/m by 175.127.
% Use the local motion ratio at ride height for this constant-rate model.
% Include installation geometry in MR_s; do not apply it a second time.
k1  = 10000;    % Front suspension wheel rate                             [N/m]
k2  = 13000;    % Rear suspension wheel rate                              [N/m]

% TIRES: effective vertical tire force / deflection stiffness, not a
% suspension spring rate. Use measurements for the operating tire pressure
% and load. No suspension motion-ratio conversion is applied to tire rates.
% 200000 N/m = 200 N/mm. This linear tire model assumes continuous contact.
kt1 = 200000;   % Front vertical tire stiffness                           [N/m]
kt2 = 200000;   % Rear vertical tire stiffness                            [N/m]

% DAMPING: enter wheel-equivalent linear viscous coefficients, NOT damping
% ratio, damper click setting, or force alone. With
% MR_d = damper shaft travel / vertical wheel travel:
%     c_wheel = c_damper * MR_d^2
% For a linear damper F = c_damper * shaft_velocity; use force-velocity test
% data to choose an equivalent coefficient over the relevant speed range.
% Actual compression / rebound curves may differ; this model uses one
% constant coefficient per end. Spring and damper motion ratios may differ.
% Confirm the example 10000 values: they strongly damp the current model.
c1  = 10000;    % Front wheel-equivalent damping                          [N*s/m]
c2  = 10000;    % Rear wheel-equivalent damping                           [N*s/m]

% Animation model
% Drawing dimensions only: these do not set static sag, preload, or ride height
% in the dynamic equations. Dynamic displacements are relative to equilibrium.
z_s_static = 1.6;   % Sprung mass static vertical position      [m]
z_u_static = 0.7;   % Unsprung mass static vertical position    [m]
h_s = 0.1;          % Sprung block height                       [m]
w_u = 0.3;          % Unsprung block width                      [m]
h_u = 0.1;          % Unsprung block height                     [m]
w_e = 0.2;          % Unsprung width extension                  [m]
l_win        = 5;   % Length window analysis                    [m]
l_win_maring = 0.3; % Length window margin at the begining      [m]

% Vehicle speed
% Constant forward speed: km/h / 3.6 = m/s. This is NOT playback speed.
vel = 10;                          % Longitudinal speed [m/s]
assert(isscalar(vel) && isfinite(vel) && vel > 0, ...
    'vel must be a finite, positive scalar.');

% Simulation controls -- these alone determine the engineering time grid.
simulation_dt = 0.001;              % Maximum simulation sample interval [s]
tF = 1;                             % Minimum simulation duration [s]
post_bump_time = 1;                  % Time after rear clears last bump [s]
run_convergence_check = true;        % Repeat with half the actual time step
convergence_relative_tolerance = 0.01; % 1% of the refined metric magnitude
% Absolute tolerances also apply near zero. Order matches the metrics table:
% body displacement [m], pitch [rad], acceleration [m/s^2], front/rear travel
% [m], minimum front/rear tire loads [N], RMS body acceleration [m/s^2].
convergence_absolute_tolerances = [1e-5 1e-5 0.01 1e-5 1e-5 1 1 0.01];
% These are numerical screening tolerances, NOT physical-validation limits.

% Animation / video only -- changing these does not change simulation results.
enable_animation = true;             % false: engineering plots only
save_video = true;                   % Only used when enable_animation is true
playback_speed = 0.1;                % 0.1 = slow motion; 1 = real-time target
video_fps = 30;                      % Frames per playback second
video_filename = 'half_car_model.mp4';
assert(isscalar(simulation_dt) && isreal(simulation_dt) && ...
    isfinite(simulation_dt) && simulation_dt > 0, ...
    'simulation_dt must be a finite, positive scalar.');
assert(isscalar(tF) && isfinite(tF) && tF > 0 && ...
    isscalar(post_bump_time) && isfinite(post_bump_time) && post_bump_time >= 0, ...
    'tF must be positive and post_bump_time must be nonnegative.');
assert(isscalar(convergence_relative_tolerance) && ...
    isfinite(convergence_relative_tolerance) && convergence_relative_tolerance >= 0 && ...
    numel(convergence_absolute_tolerances) == 8 && ...
    all(isfinite(convergence_absolute_tolerances)) && ...
    all(convergence_absolute_tolerances >= 0), ...
    'Convergence tolerances must be finite and nonnegative (8 absolute values).');
assert(isscalar(playback_speed) && isfinite(playback_speed) && playback_speed > 0 && ...
    isscalar(video_fps) && isfinite(video_fps) && video_fps > 0, ...
    'playback_speed and video_fps must be finite, positive scalars.');

%% Road
% All road dimensions are in metres. Width is along the direction of travel.
% Gaps are edge-to-edge flat distances, NOT distances between bump centres.
% Heights are road elevations; they are not suspension travel or tire compression.
% Stretch 1
x_r_1_total = 5;        % Distance of the first stretch             [m]
dx_r_1 = 0.1;           % resolution                                [m]
x_r_1 = 0:dx_r_1:x_r_1_total;
z_r_1 = zeros(1,length(x_r_1));
% Shape choice: "cosine" joins flat ground with zero slope; "half_ellipse"
% retains the original profile with steep edges. Both keep the same height
% and width. A smoother bump does not guarantee continuous tire contact.
bump_shape = "cosine";
assert(isscalar(bump_shape) && any(strcmpi(bump_shape, {'cosine','half_ellipse'})), ...
    'bump_shape must be "cosine" or "half_ellipse".');
% Stretch 2: single bump or consecutive bumps
consecutive_bumps = "no";          % "yes" enables the lists below
bump_height = 0.2;                 % Single bump height [m]
bump_width  = 0.4;                 % Single bump width along road [m]
% With consecutive_bumps = "yes", the lists below define three bumps.
% Add or remove entries to change the number of bumps: each bump needs
% one height and one width, and N bumps need N-1 gaps between them.
% Example for four bumps:
% bump_heights = [0.2 0.1 0.15 0.25];
% bump_widths  = [0.4 0.6 0.5 0.8];
% bump_gaps    = [1.0 1.5 1.0];
bump_heights = [0.2 0.1 0.15];      % Consecutive heights [m], one per bump
bump_widths  = [0.4 0.6 0.5];       % Consecutive widths [m], one per bump
bump_gaps    = [1.0 1.5];           % Flat distance between bumps [m]
                                  % N bumps require N-1 gaps; [] for N=1
assert(isscalar(consecutive_bumps) && ...
    any(strcmpi(consecutive_bumps, {'yes','no'})), ...
    'consecutive_bumps must be "yes" or "no".');
if strcmpi(consecutive_bumps, 'yes')
    heights = bump_heights;
    widths = bump_widths;
    gaps = bump_gaps;
else
    assert(isscalar(bump_height) && isscalar(bump_width), ...
        'Single bump height and width must be scalars.');
    heights = bump_height;
    widths = bump_width;
    gaps = [];
end
assert(isvector(heights) && ~isempty(heights) && ...
    all(isfinite(heights(:))) && all(heights(:) >= 0), ...
    'Bump heights must be a nonempty vector of finite, nonnegative values.');
assert(isvector(widths) && numel(widths) == numel(heights) && ...
    all(isfinite(widths(:))) && all(widths(:) > 0), ...
    'Provide one finite, positive width for each bump.');
assert((isempty(gaps) || isvector(gaps)) && ...
    numel(gaps) == numel(heights)-1 && ...
    all(isfinite(gaps(:))) && all(gaps(:) >= 0), ...
    'Provide N-1 finite, nonnegative gaps for N bumps.');

% Road samples are independent of the simulation and video time grids.
th_r = linspace(0,pi,315);
x_r_2 = x_r_1_total;
z_r_2 = 0;
for bump_index = 1:numel(heights)
    if bump_index > 1 && gaps(bump_index-1) > 0
        gap_start = x_r_2(end);
        gap_points = max(2, ceil(gaps(bump_index-1)/dx_r_1)+1);
        gap_x = linspace(gap_start, gap_start+gaps(bump_index-1), gap_points);
        x_r_2 = [x_r_2 gap_x(2:end)];
        z_r_2 = [z_r_2 zeros(1,gap_points-1)];
    end
    if strcmpi(bump_shape, 'cosine')
        fraction = linspace(0,1,315);
        bump_x = x_r_2(end) + widths(bump_index)*fraction;
        bump_z = heights(bump_index)/2*(1-cos(2*pi*fraction));
    else
        bump_x = x_r_2(end) + (widths(bump_index)/2)*(1-cos(th_r));
        bump_z = heights(bump_index)*sin(th_r);
    end
    bump_z([1 end]) = 0;
    x_r_2 = [x_r_2 bump_x(2:end)];
    z_r_2 = [z_r_2 bump_z(2:end)];
end
% Let the rear axle clear the final bump, then allow settling time.
tF = max(tF, x_r_2(end)/vel + post_bump_time);
number_of_steps = ceil(tF/simulation_dt);
time = linspace(0,tF,number_of_steps+1)';
actual_simulation_dt = time(2)-time(1); % <= requested simulation_dt
% Stretch 3
x_r_3_total = 15;       % Distance of the last stretch              [m]
dx_r_2 = 0.1;           % resolution                                [m]
% Extend the flat road to cover both axles throughout the simulation.
x_r_3_total = max(x_r_3_total, vel*tF+a1+a2-x_r_2(end));
x_r_3 = linspace(x_r_2(end), x_r_2(end)+x_r_3_total, ...
    ceil(x_r_3_total/dx_r_2)+1);
z_r_3 = zeros(1,length(x_r_3));

% Concatenating 
X_r = [x_r_1 x_r_2(2:end) x_r_3(2:end)];
Z_r = [z_r_1 z_r_2(2:end) z_r_3(2:end)];

figure('Name','Road geometry');
plot(X_r,Z_r*1000,'k','LineWidth',1.5);
grid on; xlabel('Distance along road [m]'); ylabel('Road height [mm]');
title(sprintf('Road profile (%s)', char(bump_shape)));

%% Simulation

% States
% z     - Body vertical motion coordinate
% th    - Body pitch motion coordinate
% zu1   - Front wheel vertical motion coordinate 
% zu2   - Rear wheel vertical motion coordinate

positive_parameters = [m m1 m2 Iy a1 a2 k1 k2 kt1 kt2];
assert(isreal(positive_parameters) && all(isfinite(positive_parameters)) && ...
    all(positive_parameters > 0), 'Masses, inertia, distances, and stiffnesses must be positive.');
assert(isreal([c1 c2]) && all(isfinite([c1 c2])) && all([c1 c2] >= 0), ...
    'Damping coefficients must be finite and nonnegative.');

% M \ddot{x} + C_damping \dot{x} + K x = F u
M = [   m   0   0   0   ;
        0   Iy  0   0   ;
        0   0   m1  0   ;
        0   0   0   m2  ];
C_damping = [   c1+c2           a2*c2-a1*c1         -c1         -c2     ;
        a2*c2-a1*c1     c1*a1^2+c2*a2^2     a1*c1       -a2*c2  ;
        -c1             a1*c1               c1          0       ;
        -c2             -a2*c2              0           c2      ];
K = [   k1+k2           a2*k2-a1*k1         -k1         -k2     ;
        a2*k2-a1*k1     k1*a1^2+k2*a2^2     a1*k1       -a2*k2  ;
        -k1             a1*k1               k1+kt1      0       ;
        -k2             -a2*k2              0           k2+kt2  ];
F = [   0       0   ;
        0       0   ;
        kt1     0   ;
        0       kt2 ];
    
% State space model
A = [   zeros(4,4)      eye(4,4)   ;
        -M\K         -M\C_damping    ];
B = [   zeros(4,2)  ;
        M\F      ];           
% Return all four displacements and four velocities (no placeholder zeros).
C_output = eye(8);
D_output = zeros(8,2);
sys = ss(A,B,C_output,D_output);
vehicle = struct('m',m,'m1',m1,'m2',m2,'a1',a1,'a2',a2,'kt1',kt1,'kt2',kt2);

% Core simulation has no playback, figure, or video inputs.
results = simulate_half_car(sys,time,X_r,Z_r,vel,vehicle);
time = results.time;
x = results.states;
y = x;                              % For the existing drawing helpers
u_vet = results.road_inputs;
u1 = u_vet(:,1); u2 = u_vet(:,2);
z = x(:,1); theta = x(:,2); zu1 = x(:,3); zu2 = x(:,4);
body_acceleration = results.body_acceleration;
front_travel = results.suspension_travel(:,1);
rear_travel = results.suspension_travel(:,2);
Fz_front_static = results.static_tire_loads(1);
Fz_rear_static = results.static_tire_loads(2);
Fz_front = results.tire_loads(:,1);
Fz_rear = results.tire_loads(:,2);

fprintf('Actual simulation step: %.6g s (independent of playback).\n', actual_simulation_dt);
disp(table(results.metric_names,results.metric_units,results.metric_values, ...
    'VariableNames',{'Metric','Unit','Value'}));
contact_violation = any(results.tire_loads < 0,2);
if any(contact_violation)
    first_bad = find(contact_violation,1);
    warning('HalfCar:ContactViolation', ...
        ['Continuous-contact assumption violated at t = %.4f s. ' ...
        'This is an estimated warning, not a lift-off simulation. ' ...
        'Results from this point onward may be unreliable.'], time(first_bad));
end

%% Time-step convergence: same car, road, speed, and duration; twice the samples.
% This checks numerical sensitivity, not agreement with the real vehicle.
% PASS means every selected metric changes by no more than:
% absolute_tolerance + relative_tolerance * abs(refined_metric).
convergence = struct('performed',false);
if run_convergence_check
    refined_time = linspace(0,tF,2*number_of_steps+1)';
    refined_results = simulate_half_car(sys,refined_time,X_r,Z_r,vel,vehicle);
    metric_change = abs(results.metric_values-refined_results.metric_values);
    allowed_change = convergence_absolute_tolerances(:) + ...
        convergence_relative_tolerance*abs(refined_results.metric_values);
    metric_passed = metric_change <= allowed_change;
    convergence = struct('performed',true,'passed',all(metric_passed), ...
        'coarse_dt',actual_simulation_dt,'refined_dt',actual_simulation_dt/2, ...
        'metric_change',metric_change,'allowed_change',allowed_change);
    convergence_table = table(results.metric_names,results.metric_units, ...
        results.metric_values,refined_results.metric_values,metric_change, ...
        allowed_change,metric_passed,'VariableNames', ...
        {'Metric','Unit','Original','HalfStep','Change','AllowedChange','Passed'});
    disp(convergence_table);
    if all(metric_passed)
        fprintf('Time-step convergence: PASS for the selected metrics.\n');
    else
        warning('HalfCar:Convergence', ...
            ['Time-step convergence: FAIL. Reduce simulation_dt (e.g. halve it) ' ...
            'and rerun. Results/plots still show the original-step solution.']);
    end
    if ~any(contact_violation) && any(refined_results.tire_loads(:) < 0)
        warning('HalfCar:RefinedContactViolation', ...
            'The half-step run predicts negative tire load missed by the original grid.');
    end
end

%% Engineering dashboard -- linked time axes, separate quantities and units.
figure('Name','Half-car engineering results','Position',[60 60 1100 850]);
ax = gobjects(6,1);
ax(1) = subplot(3,2,1);
plot(time,u_vet*1000,'LineWidth',1.2);
ylabel('Road height [mm]'); title('Front / rear road inputs');
legend('Front','Rear','Location','best');
ax(2) = subplot(3,2,2);
plot(time,z*1000,'LineWidth',1.2);
ylabel('Body displacement [mm]'); title('Body bounce at sprung CG');
ax(3) = subplot(3,2,3);
plot(time,theta*180/pi,'LineWidth',1.2);
ylabel('Pitch [deg]'); title('Body pitch (positive = front down)');
ax(4) = subplot(3,2,4);
plot(time,body_acceleration,'LineWidth',1.2);
ylabel('Vertical acceleration [m/s^2]'); title('Body acceleration at sprung CG');
ax(5) = subplot(3,2,5);
plot(time,results.suspension_travel*1000,'LineWidth',1.2);
ylabel('Relative travel [mm]'); title('Suspension travel change (positive = extension)');
legend('Front','Rear','Location','best');
ax(6) = subplot(3,2,6);
plot(time,results.tire_loads,'LineWidth',1.2); hold on;
plot([time(1) time(end)],[0 0],'k--','HandleVisibility','off');
ylabel('Estimated normal force [N]'); title('Tire loads: below zero = assumption violated');
legend('Front','Rear','Location','best');
for panel = 1:numel(ax)
    grid(ax(panel),'on'); xlabel(ax(panel),'Time [s]');
end
linkaxes(ax,'x');
if any(contact_violation)
    sgtitle('CONTACT ASSUMPTION VIOLATED: later response may be unreliable');
else
    sgtitle('Linear half-car response (estimated tire loads; not physically validated)');
end

%% Animation -- interpolate completed results; never resimulate for playback.
if enable_animation
    % Uniform video times preserve the requested playback speed. The final
    % frame can precede the simulation end by less than one video interval.
    animation_time = (0:floor(tF*video_fps/playback_speed))' * ...
        (playback_speed/video_fps);
    animation_y = interp1(time,x,animation_time,'linear');
    animation_inputs = interp1(time,u_vet,animation_time,'linear');
    animation_z = animation_y(:,1); animation_theta = animation_y(:,2);
    animation_zu1 = animation_y(:,3); animation_zu2 = animation_y(:,4);
    color = cool(6);
    animation_figure = figure('Name','Half-car animation','WindowStyle','normal', ...
        'Units','pixels','Position',[50 50 640 640],'Resize','off');
    animation_axes = axes('Parent',animation_figure);
    drawnow;
    video_open = false;
    try
        if save_video
            v = VideoWriter(video_filename,'MPEG-4');
            v.Quality = 100;
            v.FrameRate = video_fps;
            open(v);
            video_open = true;
        end
        for i=1:length(animation_time)
    
            frame_clock = tic;
            axes(animation_axes);
            cla(animation_axes)

            % Instant position
            x_inst = vel*animation_time(i);
    
            % Track passing by:
            set(animation_axes,'xlim',[x_inst-l_win_maring x_inst+l_win],'ylim',[-1.7 -1.7+l_win])
            hold on ; grid on ; box on %; axis equal (Dont work well. It drifts vertically)
            plot([-10 X_r],[0 Z_r],'k','LineWidth',3)
    
            set(animation_axes,'FontName','Verdana','FontSize',16)
            title(["Half car model",strcat('Time=',num2str(animation_time(i),'%.3f'),' s (Playback speed=',num2str(playback_speed),')')])

            % Sprung mass plot
            fill([x_inst a1+a2+x_inst a1+a2+x_inst x_inst],[animation_z(i)+z_s_static+a2*animation_theta(i) animation_z(i)+z_s_static-a1*animation_theta(i) animation_z(i)+z_s_static+h_s-a1*animation_theta(i) animation_z(i)+z_s_static+h_s+a2*animation_theta(i)],color(6,:),'LineWidth',2)
  
            % Unprung mass front plot
            fill([x_inst-w_u/2+a1+a2-w_e     x_inst+w_u/2+a1+a2   x_inst+w_u/2+a1+a2   x_inst-w_u/2+a1+a2-w_e],...
                 [animation_zu1(i)+z_u_static  animation_zu1(i)+z_u_static  animation_zu1(i)+h_u+z_u_static  animation_zu1(i)+h_u+z_u_static],color(2,:),'LineWidth',2)
    
            % Unprung mass rear plot
            fill([x_inst-w_u/2   x_inst+w_u/2+w_e     x_inst+w_u/2+w_e    x_inst-w_u/2],...
                 [animation_zu2(i)+z_u_static   animation_zu2(i)+z_u_static  animation_zu2(i)+h_u+z_u_static     animation_zu2(i)+h_u+z_u_static],color(1,:),'LineWidth',2)

            % Damper
            plotDamper(z_s_static,z_u_static,animation_y,i, x_inst+a1+a2 , x_inst,a1,a2,h_u)
      
            % Spring
            plotSpring(z_s_static,z_u_static,animation_inputs,animation_y,i, x_inst+a1+a2 , x_inst,a1,a2,h_u)
    
            % Tire
            plot(x_inst+a1+a2,animation_inputs(i,1),'ko','MarkerFacecolor','k','MarkerSize',7) % Front
            plot(x_inst,animation_inputs(i,2),'ko','MarkerFacecolor','k','MarkerSize',7) % Rear
  
            xlabel('x [m]')
            ylabel('z [m]')
    
            drawnow;
            if save_video
                frame = getframe(animation_figure);
                frame_size = size(frame.cdata);
                if i == 1
                    expected_frame_size = frame_size;
                elseif ~isequal(frame_size,expected_frame_size)
                    error('HalfCar:FrameSize','Animation window size changed during recording.');
                end
                writeVideo(v,frame);
            end
            pause(max(0,1/video_fps-toc(frame_clock)));
    
        end

        if video_open
            close(v);
            video_open = false;
        end
    catch animation_error
        if video_open
            try
                close(v);
            catch
                % Preserve the original animation error if finalization fails.
            end
        end
        warning('HalfCar:AnimationStopped', ...
            'Engineering results remain available; animation/video stopped: %s', ...
            animation_error.message);
    end
end

function plotSpring(z_s_static , z_u_static , u_vet , y , i , x_1 , x_2 , a1 , a2 , h_u)

    % Spring parameters
    rod_Pct    = 0.11;      % Length rod percentage of total gap
    spring_Pct = 1/3;       % Spring pitch percentage of spring gap 
    spring_wid = 2;         % Spring line width

    % Tire 1 spring  geometry 
    c_t_1 = x_1;            % Longitudinal position
    w_t_1 = 0.07;            % Width

    % Tire 2 spring geometry 
    c_t_2 = x_2;         	% Longitudinal position
    w_t_2 = 0.07;            % Width
    
    % Suspension 1 spring geometry 
    c_s_1 = x_1;            % Longitudinal position
    w_s_1 = 0.1;            % Width

    % Suspension 2 spring geometry 
    c_s_2 = x_2;         	% Longitudinal position
    w_s_2 = 0.1;            % Width
    
    % Base front and rear
    z_b_1 = u_vet(:,1); % Front
    z_b_2 = u_vet(:,2); % Rear

    % Unsprung mass absolute vertical position (lower center point)
    z_u_1 = y(:,3) + z_u_static; % Front
    z_u_2 = y(:,4) + z_u_static; % Rear

    % Spring front and rear (Tire) length without rods
    L_u_1 = (z_u_1 - z_b_1) - 2*rod_Pct * z_u_static; % Front
    L_u_2 = (z_u_2 - z_b_2) - 2*rod_Pct * z_u_static; % Rear

    % Sprung mass front and rear absolute vertical position (lower center point)
    z_s_1 = y(:,1) - a1*y(:,2) + z_s_static; % Front
    z_s_2 = y(:,1) + a2*y(:,2) + z_s_static; % Rear
    
    % Spring front and rear (Suspension) length without rods
    L_s_1 = (z_s_1 - z_u_1 - h_u) - 2*rod_Pct*(z_s_static-z_u_static-h_u) ;
    L_s_2 = (z_s_2 - z_u_2 - h_u) - 2*rod_Pct*(z_s_static-z_u_static-h_u) ;

    % Spring tire 1 front
    spring_u_1_X = [ 
                c_t_1                               % Start
                c_t_1                               % rod
                c_t_1 + w_t_1                       % Part 1   
                c_t_1 - w_t_1                       % Part 2
                c_t_1 + w_t_1                       % Part 3
                c_t_1 - w_t_1                       % Part 4
                c_t_1 + w_t_1                       % Part 5
                c_t_1 - w_t_1                       % Part 6
                c_t_1                               % Part 7
                c_t_1                               % rod/End
                ];
    
	spring_u_1_Y = [ 
                z_b_1(i)                                            % Start
                z_b_1(i)+  rod_Pct*z_u_static                         % rod
                z_b_1(i)+  rod_Pct*z_u_static                         % Part 1 
                z_b_1(i)+  rod_Pct*z_u_static+  spring_Pct*L_u_1(i)     % Part 2
                z_b_1(i)+  rod_Pct*z_u_static+  spring_Pct*L_u_1(i)     % Part 3
                z_b_1(i)+  rod_Pct*z_u_static+2*spring_Pct*L_u_1(i)   % Part 4
                z_b_1(i)+  rod_Pct*z_u_static+2*spring_Pct*L_u_1(i)   % Part 5
                z_b_1(i)+  rod_Pct*z_u_static+3*spring_Pct*L_u_1(i)   % Part 6
                z_b_1(i)+  rod_Pct*z_u_static+3*spring_Pct*L_u_1(i)   % Part 7
                z_b_1(i)+2*rod_Pct*z_u_static+3*spring_Pct*L_u_1(i) % rod/End
               ]; 
           
    % Spring tire 2 rear
    spring_u_2_X = [ 
                c_t_2                               % Start
                c_t_2                               % rod
                c_t_2+w_t_2                         % Part 1   
                c_t_2-w_t_2                         % Part 2
                c_t_2+w_t_2                         % Part 3
                c_t_2-w_t_2                         % Part 4
                c_t_2+w_t_2                         % Part 5
                c_t_2-w_t_2                         % Part 6
                c_t_2                               % Part 7
                c_t_2                               % rod/End
                ];
    
	spring_u_2_Y = [ 
                z_b_2(i)                                            % Start
                z_b_2(i)+rod_Pct*z_u_static                         % rod
                z_b_2(i)+rod_Pct*z_u_static                         % Part 1 
                z_b_2(i)+rod_Pct*z_u_static+spring_Pct*L_u_2(i)     % Part 2
                z_b_2(i)+rod_Pct*z_u_static+spring_Pct*L_u_2(i)     % Part 3
                z_b_2(i)+rod_Pct*z_u_static+2*spring_Pct*L_u_2(i)   % Part 4
                z_b_2(i)+rod_Pct*z_u_static+2*spring_Pct*L_u_2(i)   % Part 5
                z_b_2(i)+rod_Pct*z_u_static+3*spring_Pct*L_u_2(i)   % Part 6
                z_b_2(i)+rod_Pct*z_u_static+3*spring_Pct*L_u_2(i)   % Part 7
                z_b_2(i)+2*rod_Pct*z_u_static+3*spring_Pct*L_u_2(i) % rod/End
               ]; 

    % Spring suspension 1 front
    spring_s_1_X = [ 
                c_s_1                               % Start
                c_s_1                               % rod
                c_s_1+w_s_1                         % Part 1   
                c_s_1-w_s_1                         % Part 2
                c_s_1+w_s_1                         % Part 3
                c_s_1-w_s_1                         % Part 4
                c_s_1+w_s_1                         % Part 5
                c_s_1-w_s_1                         % Part 6
                c_s_1                               % Part 7
                c_s_1                               % rod/End
                ];
    
	spring_s_1_Y = [ 
                z_u_1(i)+h_u                                                                % Start
                z_u_1(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)                          % rod
                z_u_1(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)                          % Part 1 
                z_u_1(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+  spring_Pct*L_s_1(i)    % Part 2
                z_u_1(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+  spring_Pct*L_s_1(i)    % Part 3
                z_u_1(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+2*spring_Pct*L_s_1(i)    % Part 4
                z_u_1(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+2*spring_Pct*L_s_1(i)    % Part 5
                z_u_1(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+3*spring_Pct*L_s_1(i)    % Part 6
                z_u_1(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+3*spring_Pct*L_s_1(i)    % Part 7
                z_u_1(i)+h_u+2*rod_Pct*(z_s_static-z_u_static-h_u)+3*spring_Pct*L_s_1(i)    % rod/End
               ];
           
    % Spring suspension 2 rear 
    spring_s_2_X = [ 
                c_s_2                               % Start
                c_s_2                               % rod
                c_s_2+w_s_2                         % Part 1   
                c_s_2-w_s_2                         % Part 2
                c_s_2+w_s_2                         % Part 3
                c_s_2-w_s_2                         % Part 4
                c_s_2+w_s_2                         % Part 5
                c_s_2-w_s_2                         % Part 6
                c_s_2                               % Part 7
                c_s_2                               % rod/End
                ];
    
	spring_s_2_Y = [ 
                z_u_2(i)+h_u                                                                % Start
                z_u_2(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)                          % rod
                z_u_2(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)                          % Part 1 
                z_u_2(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+  spring_Pct*L_s_2(i)    % Part 2
                z_u_2(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+  spring_Pct*L_s_2(i)    % Part 3
                z_u_2(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+2*spring_Pct*L_s_2(i)    % Part 4
                z_u_2(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+2*spring_Pct*L_s_2(i)    % Part 5
                z_u_2(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+3*spring_Pct*L_s_2(i)    % Part 6
                z_u_2(i)+h_u+  rod_Pct*(z_s_static-z_u_static-h_u)+3*spring_Pct*L_s_2(i)    % Part 7
                z_u_2(i)+h_u+2*rod_Pct*(z_s_static-z_u_static-h_u)+3*spring_Pct*L_s_2(i)    % rod/End
               ];

    % PLOT
    plot(spring_u_1_X,spring_u_1_Y,'k','LineWidth',spring_wid)
    plot(spring_u_2_X,spring_u_2_Y,'k','LineWidth',spring_wid)
    plot(spring_s_1_X,spring_s_1_Y,'k','LineWidth',spring_wid)
    plot(spring_s_2_X,spring_s_2_Y,'k','LineWidth',spring_wid)
        
end

function plotDamper(z_s_static , z_u_static , y , i , x_1 , x_2 , a1 , a2 , h_u)
    
    % Damper parameters
    rod_Lower_Pct = 0.1;      % Length lower rod percentage of total gap  
    rod_Upper_Pct = 0.55;      % Length upper rod percentage of total gap
    cylinder_Height_Pct = 0.55;      % Length cylinder percentage of total gap
    damper_line_wid  = 2;   % Damper line width
    
    offset_hor_1 = -0.3; % Horizontal offset 1 front [m]
    offset_hor_2 =  0.3; % Horizontal offset 2 rear [m]
    
    % Suspension 1 spring geometry
    c_1 = x_1;  % Longitudinal position
    w_1 = 0.07;  % Width
    
    % Suspension 2 spring geometry
    c_2 = x_2;  % Longitudinal position
    w_2 = 0.07;  % Width
    
    % Unsprung mass absolute vertical position (lower center point)
    z_u_1 = y(:,3) + z_u_static; % Front
    z_u_2 = y(:,4) + z_u_static; % Rear

    % Sprung mass front and rear absolute vertical position (lower center point)
    z_s_1 = y(:,1) - a1*y(:,2) + z_s_static; % Front
    z_s_2 = y(:,1) + a2*y(:,2) + z_s_static; % Rear
    
    % rod attached to unsprung mass
    rod_u_1_X = [c_1+offset_hor_1 c_1+offset_hor_1]';
    rod_u_1_Y = [z_u_1+h_u  z_u_1+h_u+rod_Lower_Pct*(z_s_static-z_u_static)];
    
    rod_u_2_X = [c_2+offset_hor_2 c_2+offset_hor_2];
    rod_u_2_Y = [z_u_2+h_u  z_u_2+h_u+rod_Lower_Pct*(z_s_static-z_u_static)];
    
    % Damper 1 base cylinder - rod - base 
    cylinder_1_X = [   
                    c_1-w_1+offset_hor_1
                    c_1-w_1+offset_hor_1
                    c_1+w_1+offset_hor_1
                    c_1+w_1+offset_hor_1
                ];
                
    cylinder_1_Y = [
                    z_u_1(i)+h_u+rod_Lower_Pct*(z_s_static-z_u_static)+cylinder_Height_Pct*(z_s_static-z_u_static)
                    z_u_1(i)+h_u+rod_Lower_Pct*(z_s_static-z_u_static) 
                    z_u_1(i)+h_u+rod_Lower_Pct*(z_s_static-z_u_static) 
                    z_u_1(i)+h_u+rod_Lower_Pct*(z_s_static-z_u_static)+cylinder_Height_Pct*(z_s_static-z_u_static)
                ];
            
    % Damper 2 base cylinder - rod - base 
    cylinder_2_X = [   
                    c_2-w_2+offset_hor_2
                    c_2-w_2+offset_hor_2
                    c_2+w_2+offset_hor_2
                    c_2+w_2+offset_hor_2
                ];
                
    cylinder_2_Y = [
                    z_u_2(i)+h_u+rod_Lower_Pct*(z_s_static-z_u_static)+cylinder_Height_Pct*(z_s_static-z_u_static)
                    z_u_2(i)+h_u+rod_Lower_Pct*(z_s_static-z_u_static) 
                    z_u_2(i)+h_u+rod_Lower_Pct*(z_s_static-z_u_static) 
                    z_u_2(i)+h_u+rod_Lower_Pct*(z_s_static-z_u_static)+cylinder_Height_Pct*(z_s_static-z_u_static)
                ];
    
    % rod attached to sprung mass 1 front
    rod_s_1_X = [c_1+offset_hor_1  c_1+offset_hor_1];
    rod_s_1_Y = [z_s_1 z_s_1-rod_Upper_Pct*(z_s_static-z_u_static)];

    % rod attached to sprung mass 2 rear
    rod_s_2_X = [c_2+offset_hor_2  c_2+offset_hor_2];
    rod_s_2_Y = [z_s_2 z_s_2-rod_Upper_Pct*(z_s_static-z_u_static)];

    % Piston inside cylinder 1 front
    piston_1_X = [c_1-0.6*w_1+offset_hor_1  c_1+0.6*w_1+offset_hor_1];
    piston_1_Y = [z_s_1-rod_Upper_Pct*(z_s_static-z_u_static) z_s_1-rod_Upper_Pct*(z_s_static-z_u_static)];
    
    % Piston inside cylinder 2 rear
    piston_2_X = [c_2-0.6*w_2+offset_hor_2  c_2+0.6*w_2+offset_hor_2];
    piston_2_Y = [z_s_2-rod_Upper_Pct*(z_s_static-z_u_static) z_s_2-rod_Upper_Pct*(z_s_static-z_u_static)];
    
    % Total damper 1 iteration
    rod_u_1_Y_val  = rod_u_1_Y(i,:);
    rod_s_1_Y_val  = rod_s_1_Y(i,:);
    piston_1_Y_Val = piston_1_Y(i,:);
    
    % Total damper 2 iteration
    rod_u_2_Y_val  = rod_u_2_Y(i,:);
    rod_s_2_Y_val  = rod_s_2_Y(i,:);
    piston_2_Y_Val = piston_2_Y(i,:);

    % PLOT DAMPER 1
    % rods
    plot(rod_u_1_X,rod_u_1_Y_val,'k','LineWidth',damper_line_wid)
    plot(rod_s_1_X,rod_s_1_Y_val,'k','LineWidth',damper_line_wid)
    % Damper parts
    plot(piston_1_X,piston_1_Y_Val,'k','LineWidth',damper_line_wid)
    plot(cylinder_1_X,cylinder_1_Y,'k','LineWidth',damper_line_wid)
    
    % PLOT DAMPER 2
    % rods
    plot(rod_u_2_X,rod_u_2_Y_val,'k','LineWidth',damper_line_wid)
    plot(rod_s_2_X,rod_s_2_Y_val,'k','LineWidth',damper_line_wid)
    % Damper parts
    plot(piston_2_X,piston_2_Y_Val,'k','LineWidth',damper_line_wid)
    plot(cylinder_2_X,cylinder_2_Y,'k','LineWidth',damper_line_wid)

end

