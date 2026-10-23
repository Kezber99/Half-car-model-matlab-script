function tests = test_half_car_model
% Run from the repository root: runtests('tests/test_half_car_model.m')
% Requires MATLAB and Control System Toolbox. Video is disabled in every test.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.root = root;
testCase.TestData.old_path = path;
addpath(root);
testCase.TestData.old_visibility = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
testCase.TestData.warning_state = warning;
warning('off','HalfCar:ContactViolation');
warning('off','HalfCar:Convergence');
warning('off','HalfCar:RefinedContactViolation');
end

function teardownOnce(testCase)
set(groot,'DefaultFigureVisible',testCase.TestData.old_visibility);
warning(testCase.TestData.warning_state);
path(testCase.TestData.old_path);
end

function testPlaybackCannotChangeEngineeringResults(testCase)
a = variant(testCase, {'playback_speed = 0.1;', 'playback_speed = 0.1;'});
b = variant(testCase, {'playback_speed = 0.1;', 'playback_speed = 2;'});
verifyEqual(testCase,a.results.time,b.results.time);
verifyEqual(testCase,a.results.states,b.results.states);
verifyEqual(testCase,a.results.metric_values,b.results.metric_values);
end

function testFlatRoadAndStaticLoads(testCase)
a = variant(testCase, {'bump_height = 0.2;', 'bump_height = 0;'});
verifyEqual(testCase,a.results.states,zeros(size(a.results.states)),'AbsTol',1e-12);
verifyEqual(testCase,a.results.body_acceleration,zeros(size(a.results.time)),'AbsTol',1e-12);
verifyEqual(testCase,sum(a.results.static_tire_loads), ...
    (a.vehicle.m+a.vehicle.m1+a.vehicle.m2)*9.81,'AbsTol',1e-9);
verifyEqual(testCase,a.results.tire_loads, ...
    repmat(a.results.static_tire_loads,numel(a.results.time),1),'AbsTol',1e-9);
end

function testMatrixStructureAndDashboard(testCase)
a = variant(testCase, {});
verifyEqual(testCase,a.C_damping,a.C_damping.','AbsTol',1e-12);
verifyEqual(testCase,a.K,a.K.','AbsTol',1e-12);
verifyGreaterThan(testCase,min(eig(a.M)),0);
verifyGreaterThan(testCase,min(eig(a.K)),0);
verifyGreaterThanOrEqual(testCase,min(eig(a.C_damping)),-1e-8);
verifyLessThan(testCase,max(real(eig(a.sys.A))),0);
verifyEqual(testCase,a.sys.C,eye(8));
verifyEqual(testCase,a.panel_count,6);
verifyTrue(testCase,all(strcmp(a.xlabels,'Time [s]')));
verifyLessThanOrEqual(testCase,max(diff(a.results.time)),0.001+1e-12);
end

function testConsecutiveBumpsAndBothShapes(testCase)
for shape = {'cosine','half_ellipse'}
 a = variant(testCase, {'consecutive_bumps = "no";', 'consecutive_bumps = "yes";'; ...
     'bump_shape = "cosine";', ['bump_shape = "' shape{1} '";']});
 verifyGreaterThan(testCase,min(diff(a.road_x)),0);
 verifyTrue(testCase,all(isfinite(a.results.states(:))));
 % Every bump is traversed by the rear wheel before settling ends.
 verifyEqual(testCase,a.results.road_inputs(end,:),[0 0],'AbsTol',1e-12);
 verifyEqual(testCase,max(a.road_z),0.2,'AbsTol',1e-12);
end
end

function testConvergenceAndContactWarningAreSeparate(testCase)
a = variant(testCase, {'run_convergence_check = true;', 'run_convergence_check = true;'});
verifyTrue(testCase,a.convergence.performed);
verifyEqual(testCase,a.convergence.refined_dt,a.convergence.coarse_dt/2);
verifyTrue(testCase,a.convergence.passed);
% A numerically converged case can still violate physical contact assumptions.
verifyLessThan(testCase,min(a.results.tire_loads(:)),0);
end

function testInsufficientRoadIsRejected(testCase)
a = variant(testCase, {});
verifyError(testCase,@() simulate_half_car(a.sys,a.results.time, ...
    [0;1],[0;0],10,a.vehicle),'HalfCar:RoadCoverage');
end

function output = variant(testCase, replacements)
% Modify a temporary copy only; the user's parameter file is never edited.
source = fileread(fullfile(testCase.TestData.root,'half_car_model.m'));
source = strrep(source,'enable_animation = true;','enable_animation = false;');
% Only the explicit convergence test needs the extra solve.
source = strrep(source,'run_convergence_check = true;','run_convergence_check = false;');
for index = 1:size(replacements,1)
 old = replacements{index,1}; new = replacements{index,2};
 if strcmp(old,'run_convergence_check = true;')
     old = 'run_convergence_check = false;';
 end
 assert(contains(source,old),'Test configuration no longer matches the script.');
 source = strrep(source,old,new);
end
folder = tempname; mkdir(folder);
folder_cleanup = onCleanup(@() rmdir(folder,'s'));
filename = fullfile(folder,'half_car_model.m');
file = fopen(filename,'w'); assert(file ~= -1);
fwrite(file,source); fclose(file);
previous_figures = findall(groot,'Type','figure');
figure_cleanup = onCleanup(@() closeNewFigures(previous_figures));
output = runScript(filename);
end

function output = runScript(filename)
% The entry script calls clear; isolate its workspace from the test fixture.
run(filename);
output = struct('results',results,'vehicle',vehicle,'M',M,'K',K, ...
    'C_damping',C_damping,'sys',sys,'convergence',convergence, ...
    'road_x',X_r,'road_z',Z_r,'panel_count',numel(ax), ...
    'xlabels',{arrayfun(@(a) a.XLabel.String,ax,'UniformOutput',false)});
end

function closeNewFigures(previous)
current = findall(groot,'Type','figure');
close(current(~ismember(current,previous)));
end
