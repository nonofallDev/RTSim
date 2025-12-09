% Paramètres du circuit de test (Figure 2a du papier)
clear all;
close all;
clc;
% IGBT Module: FGY160T65SPD-F085 (650V/160A)
Rg = 20;              % Gate resistance (Ohms)
Vg = 15;              % Gate voltage (V)
Vcc_range = 400:50:600;     % DC link voltage (V)
IL_range = 5:5:125;         % Load current (A)
T_range = -40:10:150;       % Junction temperature (°C)

% Paramètres de simulation
t_sim = 15e-6;        % Temps de simulation (15 µs)
t_step_max = 2e-9;    % Pas de temps maximum (2 ns)
t_resolution = 5e-9;  % Résolution désirée (5 ns)

% Événements de commutation
t_turn_on = 5e-6;     % Turn-on à 5 µs
t_turn_off = 10e-6;   % Turn-off à 10 µs