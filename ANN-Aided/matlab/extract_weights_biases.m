function coefficients = extract_weights_biases(ffnn_models)
    n_on = length(ffnn_models.turn_on);
    n_off = length(ffnn_models.turn_off);
    
    % Structure pour stocker tous les coefficients
    coefficients.turn_on = struct('wh', [], 'bh', [], 'wo', [], 'bo', []);
    coefficients.turn_off = struct('wh', [], 'bh', [], 'wo', [], 'bo', []);
    
    % Extraction pour turn-on
    for j = 1:n_on
        net = ffnn_models.turn_on{j};
        
        % Poids et biais de la couche cachée (5×3 et 5×1)
        coefficients.turn_on(j).wh = net.IW{1,1};  % 5×3
        coefficients.turn_on(j).bh = net.b{1};      % 5×1
        
        % Poids et biais de la couche de sortie (2×5 et 2×1)
        coefficients.turn_on(j).wo = net.LW{2,1};  % 2×5
        coefficients.turn_on(j).bo = net.b{2};      % 2×1
    end
    
    % Extraction pour turn-off
    for j = 1:n_off
        net = ffnn_models.turn_off{j};
        coefficients.turn_off(j).wh = net.IW{1,1};
        coefficients.turn_off(j).bh = net.b{1};
        coefficients.turn_off(j).wo = net.LW{2,1};
        coefficients.turn_off(j).bo = net.b{2};
    end
    
    % Sauvegarder
    save('ffnn_coefficients.mat', 'coefficients');
    
    % Afficher les statistiques
    fprintf('Nombre total de coefficients par FFNN: 32\n');
    fprintf('  wh: 15, bh: 5, wo: 10, bo: 2\n');
    fprintf('Total turn-on: %d FFNNs = %d coefficients\n', n_on, n_on*32);
    fprintf('Total turn-off: %d FFNNs = %d coefficients\n', n_off, n_off*32);
end