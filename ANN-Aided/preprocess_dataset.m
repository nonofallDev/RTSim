function [X, Y_turn_on, Y_turn_off] = preprocess_dataset(dataset)
    n_samples = length(dataset);
    n_points_on = 150;
    n_points_off = 500;
    
    % Matrice d'entrée X: [T, Vce, Ic]
    X = zeros(n_samples, 3);
    
    % Matrices de sortie
    Y_turn_on = struct('ic', zeros(n_samples, n_points_on), ...
                       'vce', zeros(n_samples, n_points_on));
    Y_turn_off = struct('ic', zeros(n_samples, n_points_off), ...
                        'vce', zeros(n_samples, n_points_off));
    
    for i = 1:n_samples
        % Turn-on
        X(i, :) = [dataset(i).conditions(1), ...  % Temperature
                   dataset(i).turn_on.Vce_initial, ...  % Vce initial
                   dataset(i).turn_on.Ic_final];        % Ic final
        Y_turn_on.ic(i, :) = dataset(i).turn_on.ic;
        Y_turn_on.vce(i, :) = dataset(i).turn_on.vce;
        
        % Turn-off (on pourrait créer un X différent)
        % Pour simplifier, on utilise le même format
    end
    
    % Normalisation (équation 5 du papier)
    [X_norm, norm_params.X] = normalize_data(X);
    [Y_turn_on.ic_norm, norm_params.Y_on_ic] = normalize_data(Y_turn_on.ic);
    [Y_turn_on.vce_norm, norm_params.Y_on_vce] = normalize_data(Y_turn_on.vce);
    
    % Sauvegarder les paramètres de normalisation
    save('normalization_params.mat', 'norm_params');
    
    function [data_norm, params] = normalize_data(data)
        params.min = min(data(:));
        params.max = max(data(:));
        % Normalisation [-1, 1] selon équation (5)
        data_norm = 2 * (data - params.min) / (params.max - params.min) - 1;
    end
end