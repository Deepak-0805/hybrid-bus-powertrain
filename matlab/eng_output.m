function [BSFC2, RPM_grid, Brake_torque2, Power1, optimal_torque, optimal_speed, max_torque_curve] = eng_output(Eng_RPM)

Eng_RPM = 500:196.875:6800; %RPM step 
Manifold_AP = 35000:5000:100000; %Manifold air pressure step 

load('question2.mat'); %from HW 3
%code from HW3
[RPM_grid, MAP_grid] = meshgrid(Eng_RPM, Manifold_AP); %creating a grid
Brake_torque2 = NaN(size(RPM_grid));
BSFC2 = NaN(size(RPM_grid));
Power1 = NaN(size(RPM_grid));
Efficiency = NaN(size(RPM_grid));

optimal_torque = [];
optimal_speed = [];

for i = 1:length(Manifold_AP)
    for j = 1:length(Eng_RPM)
        RPM = RPM_grid(i,j);
        MAP = MAP_grid(i,j);

        %Interpolating for volumetric and thermodynamic efficiencies
        V_eff2 = interp2(vol_eff_RPM, vol_eff_MAP_in_Pa, vol_eff, RPM, MAP);
        rho2 = MAP / (R * temp_intake_in_K);
        m_a2 = Vd * V_eff2 * rho2;
        m_f2 = m_a2 / AFR_s;
        max_aflow2 = (m_a2 * RPM / 120) * 4; % maximum air mass flow rate (kg/s)
        max_fflow2 = (m_f2 * RPM / 120) * 4; % maximum fuel mass flow rate (kg/s)
        T_eff2 = interp2(Thermo_eff_RPM, Thermo_eff_cyl_air_in_kg, Thermo_eff, RPM, m_a2);
        IMEPg2 = (m_f2 * LHV * T_eff2) / Vd;
        P_exh2 = 97708 + (7.06e4)*(max_aflow2 + max_fflow2) - 3.826e4*(max_aflow2 + max_fflow2)^2;
        PMEP2 = MAP - P_exh2;
        FMEP1 = -(0.97 + 0.15*(RPM/1000) + 0.05*(RPM/1000)^2) * 1e5;
        BMEP2 = IMEPg2 + PMEP2 + FMEP1;

        % Consider only positive BMEP points
        if BMEP2 > 0
            Brake_torque2(i,j) = ((BMEP2 * Vd) / (2 * pi * 2)) * 4;
            W_c2 = BMEP2 * Vd;
            BSFC2(i,j) = (m_f2 / W_c2) * 3.6e9;%g/kWh
            Power1(i,j) = (2 * pi * RPM * Brake_torque2(i,j)) / 60;
            Efficiency(i,j) = Power1(i,j) / (max_fflow2 * LHV);

            % BSFC-optimal torque region (250–300g/kWh)
            if BSFC2(i,j) > 250 && BSFC2(i,j) < 300
                optimal_torque(end+1) = Brake_torque2(i,j) * 0.8;%20% reserve
                optimal_speed(end+1) = RPM;
            end
        end
    end
end

% Compute max torque curve
max_torque_curve = max(Brake_torque2, [], 1, 'omitnan');

end
