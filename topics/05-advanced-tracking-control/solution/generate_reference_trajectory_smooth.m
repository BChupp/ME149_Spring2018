% Generate Reference Trajectory  --  HW 05
%
% This script uses the OptimTraj trajectory optimization library to
% generate an interesting reference trajectory for the planar quadrotor.
%
% Trajectory Optimization Problem Statement:
%
% dz = f(z, u)    % system dynamics
%
% cost = integral(sum(u^2));  % actuation-squared objective function
%
% boundary constraints:
%   x0 = 1.0;  % initial horizontal position
%   y0 = 1.0;  % final horizontal position
%   q0 = 2*pi;  % initial absolute angle
%   xT = 0.0;  % final horizontal position
%   yT = 1.0;  % final vertical position
%   qT = 0.0;  % final absolute angle
%   dx0 = dy0 = dq0 = 0;  % start at rest
%   dxT = dyT = dqT = T;  % finish at rest
%
% Adds some trickery to ensure zero acceleration at the boundary
% TODO:  explain trickery.
%

clc; clear;

% Check dependencies
run('../../../codeLibrary/addLibraryToPath.m');
if ~checkForOptimTraj(), return; end  % Abort if OptimTraj is not installed

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%                     Set up problem statement                            %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%

% Dynamics function and parameters
param.m = 0.4;  % mass (kg)
param.w = 0.4;  % width (m)
param.g = 10;  % gravity acceleration (m/s^2)
problem.func.dynamics = @(t, z, u)( [planarQuadrotorDynamics(z(1:6, :), z(7:8, :), param); u] ); 

% Objective function
uNom = 0.5 * param.m * param.g;
% problem.func.pathObj = @(t, z, u)( sum(u.^2, 1) );  % actuation-squared
problem.func.pathObj = @(t, z, u)( sum(z(7:8,:).^2 + 0.2 * u.^2, 1) );  % actuation-squared

% Boundary constraints:
xInit = 1.0;  % initial horizontal position  (m)
height = 1.0;  % height off the ground for start and end
qInit = 2*pi;  % initial absolute angle (rad)
duration = 1.0;  % duration (s)

problem.bounds.initialTime.low = 0;
problem.bounds.initialTime.upp = 0;
problem.bounds.finalTime.low = duration;
problem.bounds.finalTime.upp = duration;

hoverThrust = uNom * [1;1];

z0 = [xInit; height; qInit; zeros(3,1); hoverThrust];
zT = [0; height; 0; zeros(3,1); hoverThrust];

problem.bounds.state.low = -inf(8,1);
problem.bounds.state.low(2) = height - 0.001;

problem.bounds.initialState.low = z0;
problem.bounds.initialState.upp = z0;
problem.bounds.finalState.low = zT;
problem.bounds.finalState.upp = zT;

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%                    Initial guess at trajectory                          %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%

zMid = 0.5 * (z0 + zT);
zMid(2) = 1.5 * height;

problem.guess.time = duration * linspace(0,1,3);
problem.guess.state = [z0, zMid, zT];
problem.guess.control = zeros(2,3);


%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%                         Solver options                                  %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%

% Solve on coarse grid first
problem.options(1).nlpOpt = optimset(...
    'Display','iter',...
    'MaxFunEvals',5e5);
problem.options(1).method = 'trapezoid';  
problem.options(1).trapezoid.nGrid = 16;

% Solve on fine grid second
problem.options(2).nlpOpt = problem.options(1).nlpOpt;
problem.options(2).method = 'trapezoid';  
problem.options(2).trapezoid.nGrid = 31;

% Solve on fine grid third
problem.options(3).nlpOpt = problem.options(1).nlpOpt;
problem.options(3).method = 'hermiteSimpson';  
problem.options(3).hermiteSimpson.nSegment = 30;


%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%                            Solve!                                       %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%

soln = optimTraj(problem);

%% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%                     Plot the optimal trajectory                         %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%

% Interpolate the solution trajectory
S = soln(end);
t = linspace(S.grid.time(1),S.grid.time(end), 150);
x = S.interp.state(t);
z = x(1:6, :);
u = x(7:8, :);
% du = S.interp.control(t);

% Plot the trajectory as function of time
figure(5025); clf;
planarQuadrotorPlot(t, z, u, param);

% Animation of the trajectory
xLim = [-param.w, xInit + param.w];  % horizontal limits for plot
yLim = [-0.5*param.w, max(z(2,:)) + 0.5*param.w];  % vertical limits for plot
P.plotFunc = @(t, zu)( planarQuadrotorDraw(t, zu(1:6), zu(7:8), param, xLim, yLim) );
P.speed = 0.3;  % default playback speed
P.figNum = 5030;
animate(t, [z;u], P);

%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%                     Save the data to a csv file                         %
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%

dataTable = table();
dataTable.t = t';
dataTable.x = z(1,:)';
dataTable.y = z(2,:)';
dataTable.q = z(3,:)';
dataTable.dx = z(4,:)';
dataTable.dy = z(5,:)';
dataTable.dq = z(6,:)';
dataTable.u1 = u(1,:)';
dataTable.u2 = u(2,:)';
writetable(dataTable,'quadrotorOptimalFlipData.csv');
writetable(struct2table(param),'quadrotorOptimalFlipParam.csv');
