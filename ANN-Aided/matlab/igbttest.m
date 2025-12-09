%% ------------------------------------------------------------------------
% Creation automatique d’un modèle Simulink pour tester un IGBT/Diode
% selon le schéma fourni
% -------------------------------------------------------------------------
% 
% clear; clc; close all;
% 
% model = 'Test_IGBT_Diode';
% new_system(model);
% open_system(model);
% 
% %% ------------------------------------------------------------------------
% % 0. Ajout du bloc powergui (obligatoire pour les blocs Simscape Power Systems)
% %% ------------------------------------------------------------------------
% add_block('powerlib/powergui', [model '/powergui'], ...
%     'Position',[100 50 160 100]);
% 
% %% ------------------------------------------------------------------------
% % 1. Ajout des blocs
% % -------------------------------------------------------------------------
% 
% % Position helper
% x = @(a,b)[a b];
% dx = 120; dy = 80;
% 
% % Source DC Vcc
% add_block('powerlib/Electrical Sources/DC Voltage Source', [model '/Vcc'], ...
%     'Position',[30 150 90 210]);
% 
% % IGBT S1 (DUT)
% add_block('powerlib/Power Electronics/IGBT', [model '/S1'], ...
%     'Position',[250 150 330 250]);
% 
% % Diode D1
% add_block('powerlib/Power Electronics/Diode', [model '/D1'], ...
%     'Position',[330 260 380 320]);
% 
% % Gate pulse
% add_block('simulink/Sources/Pulse Generator', [model '/Gate'], ...
%     'PulseType','Time based', ... 
%     'Period','5e-6', ...
%     'PulseWidth','50', ...       % en %
%     'Amplitude','15', ...
%     'Position',[50 300 120 340]);
% 
% 
% % Gate resistor Rg
% add_block('powerlib/Elements/Series RLC Branch',[model '/Rg'],...
%     'BranchType','R','Resistance','20','Inductance','0','Capacitance','0',...
%     'Position',[150 300 220 340]);
% 
% %% Load current IL
% add_block('powerlib/Electrical Sources/Controlled Current Source',[model '/IL'], ...
%     'Position',[450 50 510 110]);
% 
% add_block('simulink/Sources/Constant',[model '/IL_value'], ...
%     'Value','50','Position',[350 50 400 90]);
% 
% % Upper switch S2 (IGBT)
% add_block('powerlib/Power Electronics/IGBT',[model '/S2'],...
%     'Position',[400 150 480 250]);
% 
% % Upper diode D2
% add_block('powerlib/Power Electronics/Diode',[model '/D2'], ...
%     'Position',[480 70 530 130]);
% 
% % Ground
% add_block('powerlib/Elements/Ground',[model '/GND'], ...
%     'Position',[30 250 60 280]);
% 
% % Scopes
% add_block('simulink/Sinks/To Workspace',[model '/Ic'],...
%     'VariableName','Ic','Position',[600 200 650 230]);
% add_block('simulink/Sinks/To Workspace',[model '/Vce'],...
%     'VariableName','Vce','Position',[600 260 650 290]);
% 
% %% ------------------------------------------------------------------------
% % 2. Connexions entre blocs
% % ------------------------------------------------------------------------
% 
% % --- Source Vcc vers le collecteur du IGBT S2
% add_line(model,'Vcc/RConn1','S2/Lconn1','autorouting','on');
% 
% % --- Collecteur de S2 vers source de courant IL
% add_line(model,'S2/Rconn1','IL/Rconn1','autorouting','on');
% 
% % --- Source IL pilotée par IL_value (entrée de commande)
% add_line(model,'IL_value/1','IL/1','autorouting','on');
% 
% % --- IL vers collecteur de S1 (DUT)
% add_line(model,'IL/Rconn1','S1/Lconn1','autorouting','on');
% 
% % --- Diode D2 en parallèle avec S2
% add_line(model,'D2/Rconn1','S2/Lconn1','autorouting','on');
% add_line(model,'D2/Lconn1','S2/Rconn1','autorouting','on');
% 
% % --- Diode D1 en parallèle avec S1
% add_line(model,'D1/Rconn1','S1/Lconn1','autorouting','on');
% add_line(model,'D1/Lconn1','S1/Rconn1','autorouting','on');
% 
% % --- Gate signal (Pulse Generator → Rg → Gate de S1)
% % add_line(model,'Gate/1','Rg/Rconn1','autorouting','on');
% % add_line(model,'Rg/Rconn2','S1/1','autorouting','on');
% add_line(model,'Gate/1','S1/1','autorouting','on');
% 
% % --- Masse
% add_line(model,'Vcc/LConn1','GND/Lconn1','autorouting','on');
% 
% 
% add_block('powerlib/Measurements/Current Measurement',[model '/I_MEAS'], ...
%     'Position',[350 150 380 180]);
% 
% add_block('powerlib/Measurements/Voltage Measurement',[model '/VCE_MEAS'], ...
%     'Position',[350 200 380 230]);
% 
% add_line(model,'S2/Rconn1','I_MEAS/+');
% add_line(model,'I_MEAS/-','S1/Lconn1');
% 
% add_line(model,'S1/Lconn1','VCE_MEAS/1');
% add_line(model,'GND/1','VCE_MEAS/2');
% 
% % --- Mesure du courant Ic (relié au collecteur de S1)
% add_line(model,'S1/Lconn1','Ic/1','autorouting','on');
% 
% % --- Mesure de Vce (entre collecteur et émetteur du S1)
% add_line(model,'S1/Rconn1','Vce/1','autorouting','on');
% 

%% ------------------------------------------------------------------------
% 3. Configuration des paramètres
% -------------------------------------------------------------------------

Vcc_value = 500;   % entre 400 et 600
IL_value  = 5;    % entre 5 et 125

set_param([model '/Vcc'],'Amplitude',num2str(Vcc_value));
set_param([model '/IL'],'Amplitude', num2str(IL_value));

set_param(model,'StopTime','20e-6');

%% ------------------------------------------------------------------------
% 4. Lancement de la simulation
% -------------------------------------------------------------------------

sim(model);

%% ------------------------------------------------------------------------
% 5. Post-traitement
% -------------------------------------------------------------------------


Ic = out.Ic;
Vce = out.Vce;
t = Ic.time;

Ic_val = Ic.signals.values;
Vce_val = Vce.signals.values;

figure; plot(t, Ic_val); grid on;
xlabel('Temps (s)'); ylabel('Courant Ic (A)');
title('Courant collecteur');

figure; plot(t, Vce_val); grid on;
xlabel('Temps (s)'); ylabel('Vce (V)');
title('Tension collecteur-émetteur');
