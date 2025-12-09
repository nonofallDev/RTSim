function dataset = generate_igbt_dataset()
    % Initialisation
    Vcc_range = 400:50:600;     % 5 valeurs
    IL_range = 5:5:125;         % 25 valeurs
    T_range = -40:10:150;       % 20 valeurs
    % Total: 5 × 25 × 20 = 2500 conditions (simplifié vs 9225 du papier)
    
    n_conditions = length(Vcc_range) * length(IL_range) * length(T_range);
    dataset = struct('conditions', [], 'turn_on', [], 'turn_off', []);
    
    % Ouvrir le modèle
    model = 'IGBT_Transient_Test';
    load_system(model);
    
    idx = 1;
    fprintf('Génération du dataset: 0/%d\n', n_conditions);
    
    for Vcc = Vcc_range
        for IL = IL_range
            for T = T_range
                % Configurer les paramètres du modèle
                set_param([model '/Vcc'], 'Amplitude', num2str(Vcc));
                set_param([model '/Load'], 'Current', num2str(IL));
                set_param([model '/S1'], 'Temperature', num2str(T));
                
                % Exécuter la simulation
                simOut = sim(model, 'StopTime', '15e-6');
                
                % Extraire les données
                t = simOut.tout;
                vce = simOut.yout{1}.Values.Data;
                ic = simOut.yout{2}.Values.Data;
                
                % Ré-échantillonner à 5 ns
                t_resampled = 0:5e-9:15e-6;
                vce_resampled = interp1(t, vce, t_resampled);
                ic_resampled = interp1(t, ic, t_resampled);
                
                % Extraire les transitoires
                % Turn-on: 5 µs à 5.75 µs (150 points)
                idx_on_start = find(t_resampled >= 5e-6, 1);
                idx_on_end = idx_on_start + 149;
                
                % Turn-off: 10 µs à 12.5 µs (500 points)
                idx_off_start = find(t_resampled >= 10e-6, 1);
                idx_off_end = idx_off_start + 499;
                
                % Stocker les données
                dataset(idx).conditions = [T, Vcc, IL];
                dataset(idx).turn_on.vce = vce_resampled(idx_on_start:idx_on_end);
                dataset(idx).turn_on.ic = ic_resampled(idx_on_start:idx_on_end);
                dataset(idx).turn_on.Vce_initial = vce_resampled(idx_on_start);
                dataset(idx).turn_on.Ic_final = ic_resampled(idx_on_end);
                
                dataset(idx).turn_off.vce = vce_resampled(idx_off_start:idx_off_end);
                dataset(idx).turn_off.ic = ic_resampled(idx_off_start:idx_off_end);
                dataset(idx).turn_off.Vce_final = vce_resampled(idx_off_end);
                dataset(idx).turn_off.Ic_initial = ic_resampled(idx_off_start);
                
                % Affichage de progression
                if mod(idx, 100) == 0
                    fprintf('Génération du dataset: %d/%d\n', idx, n_conditions);
                end
                
                idx = idx + 1;
            end
        end
    end
    
    % Sauvegarder le dataset
    save('igbt_transient_dataset.mat', 'dataset');
    fprintf('Dataset généré avec succès!\n');
end