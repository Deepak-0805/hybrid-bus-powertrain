function [T_engine, T_motor, T_isg, clutch, P_demand, mode, eng_ig, marker,STT] = ...
    PHSB_Controller(SoC, velocity, Acc, MaxPowerTot, PowerMax, TracBrk, WheelSpeed, ...
                    Fd, T_motor_max, T_isg_max,Brk,state)
% Torque = Power
TrnSpeed = WheelSpeed*Fd;
Pacc = Acc*(MaxPowerTot);
Pbrk = Brk*MaxPowerTot;
PbrkMax = -1*TracBrk*WheelSpeed;
P_demand = Pacc + Pbrk;
Te_min = 0.1*PowerMax; 
Te_max = PowerMax;
APU_min = 0; APU_max = 0;
T_demand = P_demand;
eng_ig = 1;
% PHSB Three Energy Modes Controller (MATLAB Function Block Compatible)

%% Parameters
SoC_CD = 0.48;   % EV → CD threshold
SoC_CS = 0.46;   % CD → CS threshold
v_clutch = 6;   % low/high speed threshold (m/s)

%% ===================== MODE SELECTION =====================
if SoC >= SoC_CD && Pacc < 1.1*T_motor_max
    mode = 1;   % EV
    STT = 0;
elseif SoC >= SoC_CS && state == 0
    mode = 2;   % CD
    STT = 0;
elseif SoC <= SoC_CS && state == 0
    mode = 3;
    STT = 1;
elseif SoC >= 0.475 && state == 1
    mode = 2;
    STT = 0;
else 
    mode = 3;
    STT = 1;
end

marker  = 0;

%% ===================== CLUTCH STATE =====================
if velocity < v_clutch
    clutch = 0;   % disengaged

else
    clutch = 1;   % engaged
    if velocity <= 1.05*v_clutch
        clutch = 0;
    end
end

%% ===================== CONTROL LOGIC =====================
T_engine = 0;
T_motor  = 0;
T_isg    = 0;

switch mode
    
%% =========================================================
%%                          EV MODE
%% =========================================================
case 1
    T_engine = 0;
    eng_ig = 0;
    T_isg = 0;
    if P_demand > 0
        T_motor = min(Pacc, T_motor_max);
        marker = 1;
    else
        T_motor = 0;
        marker = 2;
    end

%% =========================================================
%%                          CD MODE
%% =========================================================
case 2
    T_isg = 0;   % ISG unused in CD
    T_engine = 0;
    Pacc = min(Pacc,MaxPowerTot);

    if P_demand > 0 && clutch == 0
       % low speed → electric only
        T_engine = 0;
        T_motor = min(Pacc, T_motor_max);
        eng_ig = 0;
        marker = 0;
    elseif P_demand > 0 && clutch == 1
        % high-speed torque-based control
        if Pacc <= 1.1*Te_min
            T_engine = 0;
            T_motor = max(min(Pacc,T_motor_max),0);
            eng_ig = 0;
            marker = 4;
        elseif Pacc > 1.1*Te_min && Pacc <= 0.98*Te_max
            T_motor = 0.1*T_motor_max;
            Pacc = Pacc - T_motor;
            T_engine = Pacc/(PowerMax);
            marker = 5;
        else
            T_engine = Te_max/PowerMax;
            T_motor = Pacc - Te_max;
            T_motor = min(T_motor, T_motor_max);
            marker = 6;
        end
    else
        eng_ig = 0;
        T_motor = 0;
        marker = 7;
    end

%% =========================================================
%%                          CS MODE
%% =========================================================

case 3
    T_isg = 0;
    T_engine = 0;
    Pacc = min(Pacc,MaxPowerTot);

    if P_demand > 0 && clutch == 0
        %% ---------- Low speed: SERIES hybrid ----------
        T_motor = min(Pacc, T_motor_max);
        T_isg = 1.2*T_motor;
        T_engine = T_isg/PowerMax;
        if T_isg <= 0.2*PowerMax
            T_isg = max(T_isg,0.2*PowerMax);
            T_engine = T_isg/PowerMax;
        elseif T_isg >= 0.5*PowerMax
            T_isg = min(T_isg,0.5*PowerMax);
            T_engine = T_isg/PowerMax;
        end
    elseif P_demand > 0 && clutch == 1
        % high-speed torque-based control
        if Pacc <= 1.1*Te_min
            T_engine = 0;
            T_motor = max(min(Pacc,T_motor_max),0);
            marker = 4;
        elseif Pacc > 1.1*Te_min && Pacc <= 0.98*Te_max
            % T_motor = 0.1*T_motor_max;
            T_motor = 0;
            T_isg = 0.2*T_engine;
            % Pacc = Pacc - T_motor;
            T_engine = Pacc/(PowerMax);
            marker = 5;
        else
            T_engine = Te_max/PowerMax;
            T_motor = Pacc - Te_max;
            T_motor = min(T_motor, T_motor_max);
            marker = 6;
        end
    else
        T_motor = 0;
        marker = 7;
    end
end

%% EV ONLY
% clutch = 0;
% T_engine = 0;
% T_motor = Pacc;
% T_isg = 0;

%% ICE 
% clutch = 1;
% T_engine = (Pacc)/MaxPowerTot;
% T_motor = 0;
% T_isg = 0;

end
