%% PHSB Three Energy Modes
clear; clc;
%% Parameters
% Mode switching thresholds
SoC_CD = 0.65;% 65% EV to CD threshold
SoC_CS = 0.35;% 35% CD to CS threshold

% Control thresholds
v_clutch = 20;%Low/high speed threshold in Kmph
%Te_min = Engine torque lower boundary in Nm
%Te_max = Engine torque upper boundary in Nm

% Component limits
%T_motor_max = Motor max torque in Nm
%T_isg_max = ISG max torque in Nm
%APU_max = APU max power in KW
%APU_min = APU min power in KW

%% Inputs 
%SoC = Current SoC (0-1)
%velocity = Current velocity (km/h)
%T_demand = Torque demand (Nm), negative for braking
%P_demand = Power demand (kW)

%% MODE
if SoC >= SoC_CD
    mode = 1;%EV mode
elseif SoC >= SoC_CS
    mode = 2;%CD mode
else
    mode = 3;%CS mode
    if SoC >= 36
        mode = 2;%Switch back to CD (hysteresis)
    end
end

%% Clutch state
if velocity < v_clutch
    clutch = 0;%Disengaged (low speed)
else
    clutch = 1;%Engaged (high speed)
end

%% Control logic

if mode == 1
    % EV mode (SoC > 65%)
    T_engine = 0;
    T_isg = 0;
    
    if T_demand >= 0
        T_motor = min(T_demand, T_motor_max);
    else
        T_motor = 0;%No regenerative braking in EV mode
    end
    
elseif mode == 2
    % CD mode (35% < SoC < 65%)
    T_isg = 0;%ISG not used in CD mode
    
    if T_demand < 0
        % Regenerative braking
        T_engine = 0;
        T_motor = max(T_demand, -0.6 * T_motor_max);%assume 60% regen capacity
        
    elseif clutch == 0
        %Low speed - pure electric
        T_engine = 0;
        T_motor = min(T_demand, T_motor_max);
        
    else
        %High speed - torque-based control
        if T_demand < Te_min
            T_engine = 0;
            T_motor = T_demand;
            
        elseif T_demand <= Te_max
            T_engine = T_demand;
            T_motor = 0;
            
        else
            T_engine = Te_max;
            T_motor = T_demand - Te_max;
            T_motor = min(T_motor, T_motor_max);
        end
    end
    
else
    %CS mode (SoC < 35%) mode = 3   
    if T_demand < 0
        %Regenerative braking
        T_engine = 0;
        T_isg = 0;
        T_motor = max(T_demand, -0.6 * T_motor_max);
        
    elseif clutch == 0
        %Low speed - Series hybrid
        T_motor = min(T_demand, T_motor_max);
        
        if P_demand > APU_max
            %
            T_engine = value;
            T_isg = -T_isg_max;
            
        elseif P_demand > APU_min && SoC > 0.30 && SoC < 0.31
            ratio = P_demand / APU_max;
            %
            T_engine = value * ratio;
            T_isg = -T_isg_max * ratio;
            
        elseif P_demand > APU_min && SoC < 0.30
            T_engine = value;
            T_isg = -T_isg_max;
            
        else
            ratio = APU_min / APU_max;
            %
            T_engine = value * ratio;
            T_isg = -T_isg_max * ratio;
        end
        
    else
        %High speed - Series-parallel hybrid
        if SoC > 0.30 && SoC < 0.31
            %Minimize energy circulation
            if T_demand < Te_min
                T_engine = 0;
                T_motor = T_demand;
                T_isg = 0;
                
            elseif T_demand <= Te_max
                T_engine = T_demand;
                T_motor = 0;
                T_isg = 0;
                
            else
                T_engine = Te_max;
                T_motor = T_demand - Te_max;
                T_motor = min(T_motor, T_motor_max);
                T_isg = 0;
            end
            
        else
            %Charging priority (SoC < 30%)
            if T_demand < Te_min
                T_engine = Te_max;
                T_motor = T_demand;
                T_isg = -(T_engine - T_demand) * efficiency;
                
            elseif T_demand <= Te_max
                T_engine = Te_max;
                T_motor = 0;
                T_isg = -(Te_max - T_demand) * efficiency;
                
            else
                T_engine = Te_max;
                T_motor = 0;
                T_isg = 0;
            end
        end
    end
end

