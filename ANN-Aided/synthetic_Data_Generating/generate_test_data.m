% Génère toutes les données fictives pour tester l'implémentation FPGA

clear all;
close all;
clc;

fprintf('=== Génération des données de test ===\n\n');

%% Paramètres
data_width = 32;
frac_width = 30;
n_hidden = 5;
n_input = 3;
n_output = 2;
n_points_on = 150;
n_points_off = 500;

%% 1. Générer les transitoires fictifs
fprintf('1. Génération des transitoires IGBT fictifs...\n');
[turn_on_data, turn_off_data] = generate_fake_transients(n_points_on, n_points_off);

%% 2. Générer les poids et biais des FFNN
fprintf('2. Génération des poids et biais FFNN...\n');
[weights_on, weights_off] = generate_fake_weights(n_points_on, n_points_off, ...
                                                    n_hidden, n_input, n_output);

%% 3. Convertir en fixed-point Q1.30
fprintf('3. Conversion en format Q1.30...\n');
[weights_fixed_on, weights_fixed_off] = quantize_weights(weights_on, weights_off, ...
                                                          data_width, frac_width);

%% 4. Générer les fichiers pour FPGA
fprintf('4. Génération des fichiers pour FPGA...\n');
generate_vhdl_files(weights_fixed_on, weights_fixed_off, turn_on_data, turn_off_data);

%% 5. Générer les fichiers de test
fprintf('5. Génération des vecteurs de test...\n');
generate_test_vectors(turn_on_data, turn_off_data);

%% 6. Visualisation
fprintf('6. Génération des graphiques...\n');
plot_test_data(turn_on_data, turn_off_data);

fprintf('\n=== Génération terminée avec succès! ===\n');

%% =========================================================================
%% FONCTION 1: Générer des transitoires fictifs réalistes
%% =========================================================================
function [turn_on, turn_off] = generate_fake_transients(n_on, n_off)
    % Paramètres typiques d'un IGBT
    Vce_initial = 500;  % Volts
    Ic_final = 80;      % Ampères
    
    % Turn-ON transient
    turn_on.time = (0:n_on-1) * 5e-9;  % 5 ns par point
    
    % Modèle de tension turn-on: décroissance exponentielle
    tau_v_on = 100e-9;  % Constante de temps 100 ns
    turn_on.vce = Vce_initial * exp(-turn_on.time / tau_v_on) + 2;  % Vce_sat ≈ 2V
    
    % Modèle de courant turn-on: croissance exponentielle avec retard
    tau_i_on = 150e-9;  % Constante de temps 150 ns
    delay_i = 50e-9;    % Retard de 50 ns
    turn_on.ic = Ic_final * (1 - exp(-(turn_on.time - delay_i) / tau_i_on));
    turn_on.ic(turn_on.time < delay_i) = 0;
    
    % Turn-OFF transient
    turn_off.time = (0:n_off-1) * 5e-9;
    
    % Modèle de courant turn-off: décroissance avec tail current
    tau_i_off = 200e-9;     % Constante de temps principale
    tau_tail = 1500e-9;     % Constante de temps tail current
    I_tail = 0.1 * Ic_final; % Amplitude tail current (10%)
    
    turn_off.ic = Ic_final * exp(-turn_off.time / tau_i_off) + ...
                  I_tail * exp(-turn_off.time / tau_tail);
    
    % Modèle de tension turn-off: croissance rapide puis plateau
    tau_v_off = 180e-9;
    delay_v = 30e-9;
    turn_off.vce = Vce_initial * (1 - exp(-(turn_off.time - delay_v) / tau_v_off));
    turn_off.vce(turn_off.time < delay_v) = 2;  % Vce_sat avant le turn-off
    
    fprintf('  - Turn-ON: %d points, durée %.1f ns\n', n_on, turn_on.time(end)*1e9);
    fprintf('  - Turn-OFF: %d points, durée %.1f ns\n', n_off, turn_off.time(end)*1e9);
end

%% =========================================================================
%% FONCTION 2: Générer des poids et biais fictifs
%% =========================================================================
function [weights_on, weights_off] = generate_fake_weights(n_on, n_off, n_h, n_i, n_o)
    % Pour chaque point de temps, générer un FFNN
    
    fprintf('  - Génération de %d FFNNs pour turn-on...\n', n_on);
    for j = 1:n_on
        % Poids couche cachée (5x3)
        weights_on(j).wh = randn(n_h, n_i) * 0.5;  % Variance réduite
        % Biais couche cachée (5x1)
        weights_on(j).bh = randn(n_h, 1) * 0.3;
        % Poids couche sortie (2x5)
        weights_on(j).wo = randn(n_o, n_h) * 0.5;
        % Biais couche sortie (2x1)
        weights_on(j).bo = randn(n_o, 1) * 0.3;
    end
    
    fprintf('  - Génération de %d FFNNs pour turn-off...\n', n_off);
    for j = 1:n_off
        weights_off(j).wh = randn(n_h, n_i) * 0.5;
        weights_off(j).bh = randn(n_h, 1) * 0.3;
        weights_off(j).wo = randn(n_o, n_h) * 0.5;
        weights_off(j).bo = randn(n_o, 1) * 0.3;
    end
end

%% =========================================================================
%% FONCTION 3: Quantifier en fixed-point
%% =========================================================================
function [w_on_fixed, w_off_fixed] = quantize_weights(w_on, w_off, width, frac)
    n_on = length(w_on);
    n_off = length(w_off);
    
    scale = 2^frac;
    
    fprintf('  - Quantification en Q1.%d...\n', frac);
    
    % Turn-on
    for j = 1:n_on
        w_on_fixed(j).wh = round(w_on(j).wh * scale);
        w_on_fixed(j).bh = round(w_on(j).bh * scale);
        w_on_fixed(j).wo = round(w_on(j).wo * scale);
        w_on_fixed(j).bo = round(w_on(j).bo * scale);
        
        % Saturation pour éviter l'overflow
        w_on_fixed(j).wh = max(min(w_on_fixed(j).wh, 2^(width-1)-1), -2^(width-1));
        w_on_fixed(j).bh = max(min(w_on_fixed(j).bh, 2^(width-1)-1), -2^(width-1));
        w_on_fixed(j).wo = max(min(w_on_fixed(j).wo, 2^(width-1)-1), -2^(width-1));
        w_on_fixed(j).bo = max(min(w_on_fixed(j).bo, 2^(width-1)-1), -2^(width-1));
    end
    
    % Turn-off
    for j = 1:n_off
        w_off_fixed(j).wh = round(w_off(j).wh * scale);
        w_off_fixed(j).bh = round(w_off(j).bh * scale);
        w_off_fixed(j).wo = round(w_off(j).wo * scale);
        w_off_fixed(j).bo = round(w_off(j).bo * scale);
        
        w_off_fixed(j).wh = max(min(w_off_fixed(j).wh, 2^(width-1)-1), -2^(width-1));
        w_off_fixed(j).bh = max(min(w_off_fixed(j).bh, 2^(width-1)-1), -2^(width-1));
        w_off_fixed(j).wo = max(min(w_off_fixed(j).wo, 2^(width-1)-1), -2^(width-1));
        w_off_fixed(j).bo = max(min(w_off_fixed(j).bo, 2^(width-1)-1), -2^(width-1));
    end
end

%% =========================================================================
%% FONCTION 4: Générer les fichiers VHDL
%% =========================================================================
function generate_vhdl_files(w_on, w_off, data_on, data_off)
    
    %% 4.1 Fichier COE pour BRAM des coefficients
    fprintf('  - Génération du fichier COE pour BRAM...\n');
    fid = fopen('coefficients.coe', 'w');
    fprintf(fid, 'memory_initialization_radix=10;\n');  % Décimal signé
    fprintf(fid, 'memory_initialization_vector=\n');
    
    % Turn-on (150 FFNNs)
    for j = 1:length(w_on)
        % wh: 5x3 = 15 coefficients
        for i = 1:size(w_on(j).wh, 1)
            for k = 1:size(w_on(j).wh, 2)
                fprintf(fid, '%d,\n', w_on(j).wh(i,k));
            end
        end
        % bh: 5 coefficients
        for i = 1:length(w_on(j).bh)
            fprintf(fid, '%d,\n', w_on(j).bh(i));
        end
        % wo: 2x5 = 10 coefficients
        for i = 1:size(w_on(j).wo, 1)
            for k = 1:size(w_on(j).wo, 2)
                fprintf(fid, '%d,\n', w_on(j).wo(i,k));
            end
        end
        % bo: 2 coefficients
        for i = 1:length(w_on(j).bo)
            if j == length(w_on) && i == length(w_on(j).bo) && isempty(w_off)
                fprintf(fid, '%d;\n', w_on(j).bo(i));  % Dernier élément
            else
                fprintf(fid, '%d,\n', w_on(j).bo(i));
            end
        end
    end
    
    % Turn-off (500 FFNNs)
    for j = 1:length(w_off)
        % wh
        for i = 1:size(w_off(j).wh, 1)
            for k = 1:size(w_off(j).wh, 2)
                fprintf(fid, '%d,\n', w_off(j).wh(i,k));
            end
        end
        % bh
        for i = 1:length(w_off(j).bh)
            fprintf(fid, '%d,\n', w_off(j).bh(i));
        end
        % wo
        for i = 1:size(w_off(j).wo, 1)
            for k = 1:size(w_off(j).wo, 2)
                fprintf(fid, '%d,\n', w_off(j).wo(i,k));
            end
        end
        % bo
        for i = 1:length(w_off(j).bo)
            if j == length(w_off) && i == length(w_off(j).bo)
                fprintf(fid, '%d;\n', w_off(j).bo(i));  % Dernier élément
            else
                fprintf(fid, '%d,\n', w_off(j).bo(i));
            end
        end
    end
    
    fclose(fid);
    
    %% 4.2 Fichier MEM (format hexadécimal pour simulation)
    fprintf('  - Génération du fichier MEM...\n');
    fid = fopen('coefficients.mem', 'w');
    
    % Turn-on
    for j = 1:length(w_on)
        % wh
        for i = 1:numel(w_on(j).wh)
            fprintf(fid, '%08X\n', typecast(int32(w_on(j).wh(i)), 'uint32'));
        end
        % bh
        for i = 1:numel(w_on(j).bh)
            fprintf(fid, '%08X\n', typecast(int32(w_on(j).bh(i)), 'uint32'));
        end
        % wo
        for i = 1:numel(w_on(j).wo)
            fprintf(fid, '%08X\n', typecast(int32(w_on(j).wo(i)), 'uint32'));
        end
        % bo
        for i = 1:numel(w_on(j).bo)
            fprintf(fid, '%08X\n', typecast(int32(w_on(j).bo(i)), 'uint32'));
        end
    end
    
    % Turn-off
    for j = 1:length(w_off)
        for i = 1:numel(w_off(j).wh)
            fprintf(fid, '%08X\n', typecast(int32(w_off(j).wh(i)), 'uint32'));
        end
        for i = 1:numel(w_off(j).bh)
            fprintf(fid, '%08X\n', typecast(int32(w_off(j).bh(i)), 'uint32'));
        end
        for i = 1:numel(w_off(j).wo)
            fprintf(fid, '%08X\n', typecast(int32(w_off(j).wo(i)), 'uint32'));
        end
        for i = 1:numel(w_off(j).bo)
            fprintf(fid, '%08X\n', typecast(int32(w_off(j).bo(i)), 'uint32'));
        end
    end
    
    fclose(fid);
    
    fprintf('    Fichiers générés: coefficients.coe, coefficients.mem\n');
end

%% =========================================================================
%% FONCTION 5: Générer les vecteurs de test
%% =========================================================================
function generate_test_vectors(data_on, data_off)
    
    %% Paramètres de normalisation
    scale = 2^30;
    
    % Normalisation Temperature [-40°C, 150°C] → [-1, 1]
    T = 20;  % 20°C
    T_norm = 2 * (T - (-40)) / (150 - (-40)) - 1;
    T_fixed = round(T_norm * scale);
    
    % Normalisation Vce [0V, 700V] → [-1, 1]
    Vce_init = 500;
    Vce_norm = 2 * Vce_init / 700 - 1;
    Vce_fixed = round(Vce_norm * scale);
    
    % Normalisation Ic [0A, 160A] → [-1, 1]
    Ic_final = 80;
    Ic_norm = 2 * Ic_final / 160 - 1;
    Ic_fixed = round(Ic_norm * scale);
    
    %% Générer fichier de stimuli pour testbench
    fid = fopen('test_vectors.txt', 'w');
    fprintf(fid, '-- Vecteurs de test pour ffnn_top_tb\n');
    fprintf(fid, '-- Format: Temps(ns) | Gate | Temp | Vce | Ic\n');
    fprintf(fid, '-- Valeurs en Q1.30 (decimal signé)\n\n');
    
    t = 0;
    dt = 5;  % 5 ns par cycle
    
    % Phase IDLE
    for i = 1:20
        fprintf(fid, '%d 0 %d %d %d\n', t, T_fixed, Vce_fixed, 0);
        t = t + dt;
    end
    
    % Phase TURN-ON
    fprintf(fid, '\n-- TURN-ON START\n');
    for i = 1:length(data_on.ic)
        fprintf(fid, '%d 1 %d %d %d\n', t, T_fixed, Vce_fixed, Ic_fixed);
        t = t + dt;
    end
    
    % Phase ON
    fprintf(fid, '\n-- ON STATE\n');
    for i = 1:100
        fprintf(fid, '%d 1 %d %d %d\n', t, T_fixed, 0, Ic_fixed);
        t = t + dt;
    end
    
    % Phase TURN-OFF
    fprintf(fid, '\n-- TURN-OFF START\n');
    for i = 1:length(data_off.ic)
        fprintf(fid, '%d 0 %d %d %d\n', t, T_fixed, Vce_fixed, Ic_fixed);
        t = t + dt;
    end
    
    % Phase OFF
    fprintf(fid, '\n-- OFF STATE\n');
    for i = 1:100
        fprintf(fid, '%d 0 %d %d %d\n', t, T_fixed, Vce_fixed, 0);
        t = t + dt;
    end
    
    fclose(fid);
    
    %% Générer fichier de référence pour comparaison
    fid = fopen('expected_results.txt', 'w');
    fprintf(fid, '-- Résultats attendus\n');
    fprintf(fid, '-- Format: Temps(ns) | Ic(A) | Vce(V)\n\n');
    
    t = 0;
    
    % IDLE
    for i = 1:20
        fprintf(fid, '%d 0.0 %.2f\n', t, Vce_init);
        t = t + dt;
    end
    
    % TURN-ON
    fprintf(fid, '\n-- TURN-ON\n');
    for i = 1:length(data_on.ic)
        fprintf(fid, '%d %.2f %.2f\n', t, data_on.ic(i), data_on.vce(i));
        t = t + dt;
    end
    
    % ON
    fprintf(fid, '\n-- ON STATE\n');
    for i = 1:100
        fprintf(fid, '%d %.2f 2.0\n', t, Ic_final);
        t = t + dt;
    end
    
    % TURN-OFF
    fprintf(fid, '\n-- TURN-OFF\n');
    for i = 1:length(data_off.ic)
        fprintf(fid, '%d %.2f %.2f\n', t, data_off.ic(i), data_off.vce(i));
        t = t + dt;
    end
    
    % OFF
    fprintf(fid, '\n-- OFF STATE\n');
    for i = 1:100
        fprintf(fid, '%d 0.0 %.2f\n', t, Vce_init);
        t = t + dt;
    end
    
    fclose(fid);
    
    fprintf('    Fichiers générés: test_vectors.txt, expected_results.txt\n');
end

%% =========================================================================
%% FONCTION 6: Visualisation
%% =========================================================================
function plot_test_data(data_on, data_off)
    
    figure('Position', [100 100 1200 800]);
    
    % Turn-ON
    subplot(2,2,1);
    plot(data_on.time * 1e9, data_on.ic, 'b-', 'LineWidth', 2);
    grid on;
    xlabel('Temps (ns)');
    ylabel('Courant (A)');
    title('Turn-ON: Courant collecteur');
    
    subplot(2,2,2);
    plot(data_on.time * 1e9, data_on.vce, 'r-', 'LineWidth', 2);
    grid on;
    xlabel('Temps (ns)');
    ylabel('Tension (V)');
    title('Turn-ON: Tension Vce');
    
    % Turn-OFF
    subplot(2,2,3);
    plot(data_off.time * 1e9, data_off.ic, 'b-', 'LineWidth', 2);
    grid on;
    xlabel('Temps (ns)');
    ylabel('Courant (A)');
    title('Turn-OFF: Courant collecteur (avec tail)');
    
    subplot(2,2,4);
    plot(data_off.time * 1e9, data_off.vce, 'r-', 'LineWidth', 2);
    grid on;
    xlabel('Temps (ns)');
    ylabel('Tension (V)');
    title('Turn-OFF: Tension Vce');
    
    saveas(gcf, 'transient_waveforms.png');
    fprintf('    Graphique sauvegardé: transient_waveforms.png\n');
end