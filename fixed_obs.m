function traj = fixed_obs(x)
% 1. Run Backward Reachable Set (BRS) with a goal
%     uMode = 'min' <-- goal
%     minWith = 'none' <-- Set (not tube)
%     compTraj = false <-- no trajectory
% 2. Run BRS with goal, then optimal trajectory
%     uMode = 'min' <-- goal
%     minWith = 'none' <-- Set (not tube)
%     compTraj = true <-- compute optimal trajectory
% 3. Run Backward Reachable Tube (BRT) with a goal, then optimal trajectory
%     uMode = 'min' <-- goal
%     minWith = 'minVOverTime' <-- Tube (not set)
%     compTraj = true <-- compute optimal trajectory
% 4. Add disturbance
%     dStep1: define a dMax (dMax = [.25, .25, 0];)
%     dStep2: define a dMode (opposite of uMode)
%     dStep3: input dMax when creating your DubinsCar
%     dStep4: add dMode to schemeData
% 5. Change to an avoid BRT rather than a goal BRT
%     uMode = 'max' <-- avoid
%     dMode = 'min' <-- opposite of uMode
%     minWith = 'minVOverTime' <-- Tube (not set)
%     compTraj = false <-- no trajectory
% 6. Change to a Forward Reachable Tube (FRT)
%     add schemeData.tMode = 'forward'
%     note: now having uMode = 'max' essentially says "see how far I can
%     reach"
% 7. Add obstacles
%     add the following code:
%     obstacles = shapeCylinder(g, 3, [-1.5; 1.5; 0], 0.75);
%     HJIextraArgs.obstacles = obstacles;
% 8. Add random disturbance (white noise)
%     add the following code:
%     HJIextraArgs.addGaussianNoiseStandardDeviation = [0; 0; 0.5];


%% Should we compute the trajectory?
compTraj = true;

%% Grid
grid_min = [-7; -7; -pi]; % Lower corner of computation domain
grid_max = [7; 7; pi];    % Upper corner of computation domain
N = [41; 41; 41];         % Number of grid points per dimension
pdDims = 3;               % 3rd dimension is periodic
g = createGrid(grid_min, grid_max, N, pdDims);
% Use "g = createGrid(grid_min, grid_max, N);" if there are no periodic
% state space dimensions

%% target set
R = 2;
% data0 = shapeCylinder(grid,ignoreDims,center,radius)
data0 = shapeCylinder(g,3,[0; 0; 0], R);
% also try shapeRectangleByCorners, shapeSphere, etc.

%% time vector
t0 = 0;
tMax = 3;
dt = 0.05;
tau = t0:dt:tMax;

%% problem parameters

% input bounds
speed = 1;
wMax = 1;
% do dStep1 here

% control trying to min or max value function?
uMode = 'min';
% do dStep2 here 

%% Pack problem parameters

% Define dynamic system
% obj = DubinsCar(x, wMax, speed, dMax)-- (state: [xpos; ypos], angle max(or min), speed, disturbance bounds)
dCar = DubinsCar([0, 0, 0], wMax, speed); %do dStep3 here

% Put grid and dynamic systems into schemeData
schemeData.grid = g;
schemeData.dynSys = dCar;
schemeData.accuracy = 'high'; %set accuracy  [low, medium, high, veryHigh]
schemeData.uMode = uMode;
%do dStep4 here

%% additive random noise
%do Step8 here
%HJIextraArgs.addGaussianNoiseStandardDeviation = [0; 0; 0.5];
% Try other noise coefficients, like:
%    [0.2; 0; 0]; % Noise on X state
%    [0.2,0,0;0,0.2,0;0,0,0.5]; % Independent noise on all states
%    [0.2;0.2;0.5]; % Coupled noise on all states
%    {zeros(size(g.xs{1})); zeros(size(g.xs{1})); (g.xs{1}+g.xs{2})/20}; % State-dependent noise

%% If you have obstacles, compute them here 
% the obstacle trajectory can be set as antoher path
obstacles_1 = shapeCylinder(g, 3, [-1; 3; 0], 0.75);
obstacles_2 = shapeCylinder(g, 3, [3; 0; 0], 0.75);

obstacles = shapeUnion(obstacles_1,obstacles_2);

HJIextraArgs.obstacleFunction = obstacles;
%% Compute value function

%HJIextraArgs.visualize = true; %show plot
HJIextraArgs.visualize.valueSet = 1;
HJIextraArgs.visualize.initialValueSet = 1;
HJIextraArgs.visualize.figNum = 1; %set figure number
HJIextraArgs.visualize.deleteLastPlot = true; %delete previous plot as you update
HJIextraArgs.visualize.obstacleSet = 1;
HJIextraArgs.visualize.obstacleFunction = 1;    % what it means?
% uncomment if you want to see a 2D slice
HJIextraArgs.visualize.plotData.plotDims = [1 1 0]; %plot x, y
HJIextraArgs.visualize.plotData.projpt = [0]; %project at theta = 0
HJIextraArgs.visualize.viewAngle = [0,90]; % view 2D

%[data, tau, extraOuts] = ...
% HJIPDE_solve(data0, tau, schemeData, minWith, extraArgs)
[data, tau2, ~] = ...
  HJIPDE_solve(data0, tau, schemeData, 'zero', HJIextraArgs);

%% Compute optimal trajectory from some initial state
if compTraj
  
  %set the initial state (Start point for the trajectory)
  xinit = [x(1), x(2), -pi];
  
  %check if this initial state is in the BRS/BRT
  %value = eval_u(g, data, x)
  value = eval_u(g,data(:,:,:,end),xinit);
  
  if value <= 0 %if initial state is in BRS/BRT
    % find optimal trajectory
    
    dCar.x = xinit; %set initial state of the dubins car

    TrajextraArgs.uMode = uMode; %set if control wants to min or max
    TrajextraArgs.dMode = 'max';
    TrajextraArgs.visualize = true; %show plot
    TrajextraArgs.fig_num = 2; %figure number
    
    %we want to see the first two dimensions (x and y)
    TrajextraArgs.projDim = [1 1 0]; 
    
    %flip data time points so we start from the beginning of time
    dataTraj = flip(data,4);
    
    % [traj, traj_tau] = ...
    % computeOptTraj(g, data, tau, dynSys, extraArgs) %% can be continuous
    [traj, traj_tau] = ...
      computeOptTraj(g, dataTraj, tau2, dCar, TrajextraArgs);


%     figure(6)
%     clf
%     h = visSetIm(g, data(:,:,:,end));
%     h.FaceAlpha = .3;
%     hold on
%     s = scatter3(xinit(1), xinit(2), xinit(3));
%     s.SizeData = 70;
%     title('The reachable set at the end and x_init')
%     hold off
%     [~,c] = size(traj);
%     
%     figure(4)
% 
%     % add the target set to that
%     [g2D, data2D] = proj(g, data0, [0 0 1]);
%     visSetIm(g2D, data2D, 'green');
% 
%     hold on
%     [g2D_of,data2D_of] = proj(g,obstacles,[0 0 1]);
%     visSetIm(g2D_of,data2D_of,'black');
%     
% 
% 
% 
%     for n = 1:c
%         plot(traj(1,n), traj(2,n),'bo','MarkerSize',5)
%         xlim([-8 8])
%         ylim([-8 8])
%         pause(0.05)
%     end
    title('2D projection of the trajectory & target set')
    hold off
  else
    error(['Initial state is not in the BRS/BRT! It have a value of ' num2str(value,2)])
  end
end
end