% compare_results.m
% Compare les résultats FPGA avec les valeurs attendues

function compare_results()
    
    fprintf('=== Comparaison des résultats ===\n\n');
    
    % Vérifier que les fichiers existent
    if ~exist('expected_results.txt', 'file')
        error('Fichier expected_results.txt introuvable. Exécutez d''abord generate_test_data.m');
    end
    
    if ~exist('simulation_results.txt', 'file')
        error('Fichier simulation_results.txt introuvable. Lancez d''abord la simulation Vivado.');
    end
    
    % Lire les résultats attendus
    fprintf('Lecture des résultats attendus...\n');
    expected = read_results_file('expected_results.txt');
    fprintf('  - %d points lus\n', length(expected.time));
    
    % Lire les résultats de simulation FPGA
    fprintf('Lecture des résultats FPGA...\n');
    fpga_raw = read_results_file('simulation_results.txt');
    fprintf('  - %d points lus\n', length(fpga_raw.time));
    
    % Convertir les valeurs FPGA (Q1.30) en valeurs physiques
    scale = 2^30;
    
    % Dénormaliser Ic: [-1,1] → [0,160]A
    fpga_raw.ic_real = (double(fpga_raw.ic) / scale + 1) * 160 / 2;
    
    % Dénormaliser Vce: [-1,1] → [0,700]V
    fpga_raw.vce_real = (double(fpga_raw.vce) / scale + 1) * 700 / 2;
    
    % Synchroniser les deux datasets (même taille)
    fprintf('\nSynchronisation des données...\n');
    [expected_sync, fpga_sync] = synchronize_data(expected, fpga_raw);
    fprintf('  - %d points communs\n', length(expected_sync.time));
    
    % Calculer les erreurs
    error_ic = abs(fpga_sync.ic_real - expected_sync.ic);
    error_vce = abs(fpga_sync.vce_real - expected_sync.vce);
    
    % Filtrer les NaN et Inf
    valid_idx = ~isnan(error_ic) & ~isinf(error_ic) & ...
                ~isnan(error_vce) & ~isinf(error_vce);
    
    error_ic = error_ic(valid_idx);
    error_vce = error_vce(valid_idx);
    time_valid = expected_sync.time(valid_idx);
    
    % Statistiques
    fprintf('\n=== Statistiques d''erreur ===\n');
    fprintf('Erreur Ic:\n');
    fprintf('  Moyenne: %.4f A\n', mean(error_ic));
    fprintf('  Médiane: %.4f A\n', median(error_ic));
    fprintf('  Max: %.4f A\n', max(error_ic));
    fprintf('  RMS: %.4f A\n', rms(error_ic));
    fprintf('  Écart-type: %.4f A\n', std(error_ic));
    
    fprintf('\nErreur Vce:\n');
    fprintf('  Moyenne: %.4f V\n', mean(error_vce));
    fprintf('  Médiane: %.4f V\n', median(error_vce));
    fprintf('  Max: %.4f V\n', max(error_vce));
    fprintf('  RMS: %.4f V\n', rms(error_vce));
    fprintf('  Écart-type: %.4f V\n', std(error_vce));
    
    % Erreur relative
    fprintf('\nErreur relative:\n');
    rel_error_ic = mean(error_ic ./ (expected_sync.ic(valid_idx) + 1e-6)) * 100;
    rel_error_vce = mean(error_vce ./ (expected_sync.vce(valid_idx) + 1e-6)) * 100;
    fprintf('  Ic: %.2f%%\n', rel_error_ic);
    fprintf('  Vce: %.2f%%\n', rel_error_vce);
    
    % Graphiques
    fprintf('\nGénération des graphiques...\n');
    plot_comparison(expected_sync, fpga_sync, error_ic, error_vce, time_valid);
    
    fprintf('\n=== Comparaison terminée ===\n');
end

%% =========================================================================
%% FONCTION: Synchroniser les données
%% =========================================================================
function [exp_sync, fpga_sync] = synchronize_data(expected, fpga)
    % Trouver les temps communs ou interpoler
    
    % Méthode 1: Si les temps correspondent exactement
    if length(expected.time) == length(fpga.time) && ...
       all(abs(expected.time - fpga.time) < 1e-6)
        % Temps identiques
        exp_sync = expected;
        fpga_sync = fpga;
        return;
    end
    
    % Méthode 2: Interpolation sur la grille temporelle commune
    % Prendre l'intersection des plages temporelles
    t_min = max(min(expected.time), min(fpga.time));
    t_max = min(max(expected.time), max(fpga.time));
    
    % Créer une grille temporelle commune (pas de 5 ns)
    t_common = (t_min:5:t_max)';
    
    % Interpoler les données attendues
    exp_sync.time = t_common;
    exp_sync.ic = interp1(expected.time, expected.ic, t_common, 'linear', 'extrap');
    exp_sync.vce = interp1(expected.time, expected.vce, t_common, 'linear', 'extrap');
    
    % Interpoler les données FPGA
    fpga_sync.time = t_common;
    fpga_sync.ic_real = interp1(fpga.time, fpga.ic_real, t_common, 'linear', 'extrap');
    fpga_sync.vce_real = interp1(fpga.time, fpga.vce_real, t_common, 'linear', 'extrap');
    
    % Méthode alternative si l'interpolation échoue
    if any(isnan(exp_sync.ic)) || any(isnan(fpga_sync.ic_real))
        % Utiliser le minimum de longueur
        n_min = min(length(expected.time), length(fpga.time));
        
        exp_sync.time = expected.time(1:n_min);
        exp_sync.ic = expected.ic(1:n_min);
        exp_sync.vce = expected.vce(1:n_min);
        
        fpga_sync.time = fpga.time(1:n_min);
        fpga_sync.ic_real = fpga.ic_real(1:n_min);
        fpga_sync.vce_real = fpga.vce_real(1:n_min);
    end
end

%% =========================================================================
%% FONCTION: Lire fichier de résultats
%% =========================================================================
function data = read_results_file(filename)
    fid = fopen(filename, 'r');
    
    if fid == -1
        error('Impossible d''ouvrir le fichier: %s', filename);
    end
    
    time = [];
    ic = [];
    vce = [];
    
    line_num = 0;
    while ~feof(fid)
        line = fgetl(fid);
        line_num = line_num + 1;
        
        % Ignorer les lignes vides et commentaires
        if ~ischar(line) || isempty(strtrim(line))
            continue;
        end
        
        line_trimmed = strtrim(line);
        if isempty(line_trimmed) || line_trimmed(1) == '-'
            continue;
        end
        
        % Essayer de parser la ligne
        try
            values = sscanf(line, '%f %f %f');
            if length(values) >= 3
                time = [time; values(1)];
                ic = [ic; values(2)];
                vce = [vce; values(3)];
            end
        catch
            % Ignorer les lignes qui ne peuvent pas être parsées
            continue;
        end
    end
    
    fclose(fid);
    
    if isempty(time)
        error('Aucune donnée valide trouvée dans %s', filename);
    end
    
    data.time = time;
    data.ic = ic;
    data.vce = vce;
    
    fprintf('  Fichier %s: %d points\n', filename, length(time));
end

%% =========================================================================
%% FONCTION: Tracer les graphiques de comparaison
%% =========================================================================
function plot_comparison(expected, fpga, error_ic, error_vce, time_valid)
    
    figure('Position', [100 100 1400 900], 'Name', 'Comparaison FPGA vs Attendu');
    
    % Subplot 1: Courant Ic
    subplot(3,2,1);
    plot(expected.time, expected.ic, 'b-', 'LineWidth', 2, 'DisplayName', 'Attendu');
    hold on;
    plot(fpga.time, fpga.ic_real, 'r--', 'LineWidth', 1.5, 'DisplayName', 'FPGA');
    legend('Location', 'best');
    xlabel('Temps (ns)');
    ylabel('Courant (A)');
    title('Comparaison Ic - Vue complète');
    grid on;
    
    % Subplot 2: Tension Vce
    subplot(3,2,2);
    plot(expected.time, expected.vce, 'b-', 'LineWidth', 2, 'DisplayName', 'Attendu');
    hold on;
    plot(fpga.time, fpga.vce_real, 'r--', 'LineWidth', 1.5, 'DisplayName', 'FPGA');
    legend('Location', 'best');
    xlabel('Temps (ns)');
    ylabel('Tension (V)');
    title('Comparaison Vce - Vue complète');
    grid on;
    
    % Subplot 3: Zoom sur turn-on (Ic)
    subplot(3,2,3);
    idx_on = find(expected.time >= 100 & expected.time <= 1000);
    if ~isempty(idx_on)
        plot(expected.time(idx_on), expected.ic(idx_on), 'b-', 'LineWidth', 2);
        hold on;
        plot(fpga.time(idx_on), fpga.ic_real(idx_on), 'r--', 'LineWidth', 1.5);
        xlabel('Temps (ns)');
        ylabel('Courant (A)');
        title('Zoom Turn-ON - Ic');
        grid on;
    end
    
    % Subplot 4: Zoom sur turn-on (Vce)
    subplot(3,2,4);
    if ~isempty(idx_on)
        plot(expected.time(idx_on), expected.vce(idx_on), 'b-', 'LineWidth', 2);
        hold on;
        plot(fpga.time(idx_on), fpga.vce_real(idx_on), 'r--', 'LineWidth', 1.5);
        xlabel('Temps (ns)');
        ylabel('Tension (V)');
        title('Zoom Turn-ON - Vce');
        grid on;
    end
    
    % Subplot 5: Erreur absolue Ic
    subplot(3,2,5);
    plot(time_valid, error_ic, 'g-', 'LineWidth', 1.5);
    xlabel('Temps (ns)');
    ylabel('Erreur absolue (A)');
    title(sprintf('Erreur Ic (Moy: %.3f A, Max: %.3f A)', mean(error_ic), max(error_ic)));
    grid on;
    
    % Subplot 6: Erreur absolue Vce
    subplot(3,2,6);
    plot(time_valid, error_vce, 'g-', 'LineWidth', 1.5);
    xlabel('Temps (ns)');
    ylabel('Erreur absolue (V)');
    title(sprintf('Erreur Vce (Moy: %.3f V, Max: %.3f V)', mean(error_vce), max(error_vce)));
    grid on;
    
    % Sauvegarder
    saveas(gcf, 'comparison_results.png');
    fprintf('  Graphique sauvegardé: comparison_results.png\n');
    
    % Figure 2: Histogrammes d'erreur
    figure('Position', [150 150 1000 500], 'Name', 'Distribution des erreurs');
    
    subplot(1,2,1);
    histogram(error_ic, 50, 'FaceColor', 'b', 'EdgeColor', 'none');
    xlabel('Erreur (A)');
    ylabel('Nombre d''occurrences');
    title('Distribution de l''erreur Ic');
    grid on;
    
    subplot(1,2,2);
    histogram(error_vce, 50, 'FaceColor', 'r', 'EdgeColor', 'none');
    xlabel('Erreur (V)');
    ylabel('Nombre d''occurrences');
    title('Distribution de l''erreur Vce');
    grid on;
    
    saveas(gcf, 'error_distribution.png');
    fprintf('  Graphique sauvegardé: error_distribution.png\n');
end