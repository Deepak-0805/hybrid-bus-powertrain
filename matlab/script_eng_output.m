Eng_RPM = 500:196.875:6800;
[BSFC2, RPM_grid, Brake_torque2, Power1,opt_torque,opt_RPM,max_torque_curve] = eng_output(Eng_RPM);
%max torque curve
Power_curve = Power1(end,:);
%BSFC plot
figure('Name','BSFC plot')
bsfc_levels = 200:20:1000;
contourf(RPM_grid, Brake_torque2, BSFC2, bsfc_levels); %contourf for BSFC levels
colormap(jet); colorbar;
hold on
yyaxis left
plot(Eng_RPM, Brake_torque2(15,:),'r--','LineWidth',2);
hold on
%extract representative optimal torque values
rpm = [opt_RPM(11) opt_RPM(21) opt_RPM(33) opt_RPM(47) opt_RPM(62) opt_RPM(79:95)];
opt_shift_line = [opt_torque(11) opt_torque(21) opt_torque(33) opt_torque(47) opt_torque(62) opt_torque(79:95)];
plot(rpm,opt_shift_line,'color','k','LineWidth',2);
%max power curve 
yyaxis right
plot(Eng_RPM,Power_curve,'g--','LineWidth',2);
hold off

%Transmission & vehicle parameters
gr = [5.55, 2.92, 1.95, 1.54, 1.26, 1.02];
final_drive = 3.62;
eta_trans = 0.97;
eta_dl = 0.95;
wheel_radius_m = 0.4064;

%Mask BSFC points above max torque
for i = 1:size(RPM_grid,1)
    for j = 1:size(RPM_grid,2)
        if Brake_torque2(i,j) > interp1(Eng_RPM, max_torque_curve, RPM_grid(i,j), 'linear',0)
            BSFC2(i,j) = NaN;
        end
    end
end

%Vehicle speeds and pedal position
v_mps = 0:1:60;% velocity up to 60 m/s
pedal = 0:0.05:1;% pedal positions
Nped = numel(pedal);

%Tractive effort and WOT upshift
Ftrac = zeros(numel(gr), numel(v_mps));
for g = 1:numel(gr)
    rpm_g = v_mps * gr(g) * final_drive / wheel_radius_m * 60/(2*pi);
    Tmax_g = interp1(Eng_RPM, max_torque_curve, rpm_g, 'linear',0);
    reserve = (g>=2 && g<=4)*0.8 + (g<2 || g>4);
    Ftrac(g,:) = (Tmax_g .* reserve .* gr(g) * final_drive * eta_trans * eta_dl)/wheel_radius_m;
    Ftrac(g,rpm_g<min(Eng_RPM) | rpm_g>max(Eng_RPM)) = 0;
end

%get upshifting points
shift_mps = zeros(1,5);
for g = 1:5
    dF = Ftrac(g,:) - Ftrac(g+1,:);
    k = find(dF(1:end-1)>0 & dF(2:end)<=0,1,'first');
    if isempty(k)
        k = numel(v_mps);
    end
    shift_mps(g) = v_mps(k);
end

%Economy & performance upshift map
e_up_mps = 2200*(2*pi/60)*wheel_radius_m./(gr(1:5)*final_drive);%economy upshift
perf_up_mps = shift_mps;
up_map = zeros(5,Nped);
for i = 1:5
    up_map(i,:) = e_up_mps(i) + (perf_up_mps(i)-e_up_mps(i)) .* pedal.^2;
end

%minimum gap
min_gap = 0.3;
for j = 1:Nped
    col = up_map(:,j);
    for i = 2:5
        if col(i) <= col(i-1)+min_gap
            col(i) = col(i-1)+min_gap;
        end
    end
    up_map(:,j) = col;
end

%gear number surface
[V_grid, P_grid] = meshgrid(v_mps, pedal);
GEAR = ones(size(V_grid));
for i = 1:5
    GEAR = GEAR + (V_grid > interp1(pedal, up_map(i,:), P_grid, 'linear', 'extrap'));
end
GEAR(GEAR>6) = 6;

%3D plot
figure();
surf(V_grid,P_grid,GEAR);
xlabel('Velocity (m/s)'); ylabel('Pedal Position'); zlabel('Gear');
colorbar;

%2D plot
figure();
surf(V_grid,P_grid,GEAR);
view(2);
colorbar;

