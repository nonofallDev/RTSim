function ffnn_models = train_ffnn_models(X, Y_turn_on, Y_turn_off)
    % Architecture du FFNN (Figure 5 du papier)
    % Input layer: 3 neurons (T, Vce, Ic)
    % Hidden layer: 5 neurons (tanh activation)
    % Output layer: 2 neurons (ic, vce) (linear activation)
    
    net_architecture = [3, 5, 2];
    n_points_on = 150;
    n_points_off = 500;
    n_trials = 30;  % Nombre d'essais pour chaque FFNN
    
    % Initialisation
    ffnn_models.turn_on = cell(n_points_on, 1);
    ffnn_models.turn_off = cell(n_points_off, 1);
    
    fprintf('Entraînement des FFNNs pour turn-on...\n');
    for j = 1:n_points_on
        % Subdataset pour le point de temps j (équation 2)
        Y_j = [Y_turn_on.ic_norm(:, j), Y_turn_on.vce_norm(:, j)];
        
        % Entraîner plusieurs fois et garder le meilleur
        best_net = train_best_ffnn(X, Y_j, net_architecture, n_trials);
        
        % Stocker le meilleur réseau
        ffnn_models.turn_on{j} = best_net;
        
        if mod(j, 10) == 0
            fprintf('  Point %d/%d terminé\n', j, n_points_on);
        end
    end
    
    fprintf('Entraînement des FFNNs pour turn-off...\n');
    for j = 1:n_points_off
        Y_j = [Y_turn_off.ic_norm(:, j), Y_turn_off.vce_norm(:, j)];
        best_net = train_best_ffnn(X, Y_j, net_architecture, n_trials);
        ffnn_models.turn_off{j} = best_net;
        
        if mod(j, 50) == 0
            fprintf('  Point %d/%d terminé\n', j, n_points_off);
        end
    end
    
    % Sauvegarder les modèles
    save('ffnn_models.mat', 'ffnn_models', '-v7.3');
end

function best_net = train_best_ffnn(X, Y, architecture, n_trials)
    best_mse = inf;
    best_net = [];
    
    for trial = 1:n_trials
        % Créer le réseau
        net = fitnet(architecture(2));  % 5 hidden neurons
        
        % Configuration
        net.trainFcn = 'trainlm';  % Levenberg-Marquardt
        net.divideParam.trainRatio = 0.75;
        net.divideParam.valRatio = 0.15;
        net.divideParam.testRatio = 0.10;
        
        % Fonction d'activation
        net.layers{1}.transferFcn = 'tansig';  % tanh pour couche cachée
        net.layers{2}.transferFcn = 'purelin'; % linéaire pour sortie
        
        % Entraînement
        [net, tr] = train(net, X', Y');
        
        % Évaluation
        mse_current = tr.best_vperf;
        
        if mse_current < best_mse
            best_mse = mse_current;
            best_net = net;
        end
    end
end