% compare_results.m
% Compare les résultats FPGA avec les valeurs attendues

function compare_results()
    
    fprintf('=== Comparaison des résultats ===\n\n');
    
    % Lire les résultats attendus
    expected = read_results_file('expected_results.txt');
    
    % Lire les résultats de simulation FPGA
    fpga = read_results_file('simulation_results.txt');
    
    % Convertir en valeurs physiques
    scale = 2^30;
    
    % Dénormaliser Ic: [-1,1] → [0,160]A
    fpga.ic_real = (double(fpga.ic) / scale + 1) * 160 / 2;
    
    % Dénormaliser Vce: [-1,1] → [0,700]V
    fpga.vce_real = (double(fpga.vce) / scale + 1) * 700 / 2;
    
    % Calculer les erreurs
    error_ic = abs(fpga.ic_real - expected.ic);
    error_vce = abs(fpga.vce_real - expected.vce);
    
    % Statistiques
    fprintf('Erreur Ic:\n');
    fprintf('  Moyenne: %.4f A\n', mean(error_ic));
    fprintf('  Max: %.4f A\n', max(error_ic));
    fprintf('  RMS: %.4f A\n', rms(error_ic));
    
    fprintf('\nErreur Vce:\n');
    fprintf('  Moyenne: %.4f V\n', mean(error_vce));
    fprintf('  Max: %.4f V\n', max(error_vce));
    fprintf('  RMS: %.4f V\n', rms(error_vce));
    
    % Graphiques
    figure('Position', [100 100 1200 800]);
    
    subplot(2,2,1);
    plot(expected.time, expected.ic, 'b-', 'LineWidth', 2);
    hold on;
    plot(fpga.time, fpga.ic_real, 'r--', 'LineWidth', 1.5);
    legend('Attendu', 'FPGA');
    xlabel('Temps (ns)');
    ylabel('Courant (A)');
    title('Comparaison Ic');
    grid on;
    
    subplot(2,2,2);
    plot(expected.time, expected.vce, 'b-', 'LineWidth', 2);
    hold on;
    plot(fpga.time, fpga.vce_real, 'r--', 'LineWidth', 1.5);
    legend('Attendu', 'FPGA');
    xlabel('Temps (ns)');
    ylabel('Tension (V)');
    title('Comparaison Vce');
    grid on;
    
    subplot(2,2,3);
    plot(expected.time, error_ic, 'g-', 'LineWidth', 1.5);
    xlabel('Temps (ns)');
    ylabel('Erreur (A)');
    title('Erreur absolue Ic');
    grid on;
    
    subplot(2,2,4);
    plot(expected.time, error_vce, 'g-', 'LineWidth', 1.5);
    xlabel('Temps (ns)');
    ylabel('Erreur (V)');
    title('Erreur absolue Vce');
    grid on;
    
    saveas(gcf, 'comparison_results.png');
    fprintf('\nGraphique sauvegardé: comparison_results.png\n');
end

function data = read_results_file(filename)
    fid = fopen(filename, 'r');
    
    time = [];
    ic = [];
    vce = [];
    
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line) || isempty(line) || line(1) == '-'
            continue;
        end
        
        values = sscanf(line, '%f %f %f');
        if length(values) >= 3
            time = [time; values(1)];
            ic = [ic; values(2)];
            vce = [vce; values(3)];
        end
    end
    
    fclose(fid);
    
    data.time = time;
    data.ic = ic;
    data.vce = vce;
end