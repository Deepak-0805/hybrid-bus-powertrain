%clear;
%close all;
%clc;

%% Battery parameters
batt.num_cells = 100;    % total number of cells
batt.num_cell_series = 100;  % number of cells in series
batt.num_module_parallel = 1;   % number of modules in parallel
batt.volt_nom = 3.6;    % nominal voltage in V
batt.volt_max = 3.9;    % max voltage in V
batt.volt_min = 3.2;    % min voltage in V
batt.curr_chg_max = -150;  % max charging current in A
batt.curr_dis_max = 200;     % max discharging current in A
batt.soc_max = 0.92;     % max SoC
batt.soc_min = 0.28;     % min SoC
batt.soc_init = 0.35;     % initial SoC

load HW05_data_2025.mat
%% Current request
% battery_current is in A
curr_demand = [time_in_s,battery_current];

% Max capacity is determined by the battery pack temperature and current
% Inputs: battery pack temperature in C
%         current in A
% Output: maximum capcacity in Ah

% Open circuit voltage is determined by the battery pack temperature and
% SoC
% Inputs: battery pack temperature in C
%         SoC (0 to 1)
% Output: Open circuit voltage in V

% Internal resistance(s) is determined by the battery pack temperature and
% SoC.
% The internal resistance is different between charging and discharging
% Inputs: battery pack temperature in C
%         SoC (0 to 1)
% Output: Internal resistance (either charging or discharging) in ohm

% battery cycle life is determined by the DoD.
% Inputs: DoD (0 to 1)
% Output: cycle life 


%% plots

figure(1)
plot(out.SOC)
figure(2)
plot(time_in_s,battery_current)
figure(3)
plot(out.Terminal_voltage)
figure(4)
plot(out.V_open_circuit)
figure(5)
plot(out.Power)

%% Battery life
% SOC data
x = out.SOC.Data;  
%% Depth of discharge

[c,hist,edges,rmm,idx] = rainflow(x);

%% life in terms of miles
v = interp1(batt.cyc_life.DOD,batt.cyc_life.cyc_life,c(:,2));
life = c(:, 1)./v;
cycle_count = 1/sum(life);
total_life = cycle_count*7.5; %in miles