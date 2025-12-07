% verify_ffnn_computation.m
% Vérifie le calcul du FFNN avec les poids générés

function verify_ffnn_computation()
    
    fprintf('=== Vérification du calcul FFNN ===\n\n');
    
    % Charger les données générées
    load('test_data.mat');
    
    % Paramètres de test
    T = 20;     % 20°C
    Vce = 500;  % 500V
    Ic = 80;    % 80A
    
    % Normalisation
    T_norm = 2 * (T - (-40)) / (150 - (-40)) - 1;
    Vce_norm = 2 * Vce / 700 - 1;
    Ic_norm = 2 * Ic / 160 - 1;
    
    input_vec = [T_norm; Vce_norm; Ic_norm];
    
    % Test avec le premier FFNN de turn-on
    fprintf('Test avec FFNN turn-on point 0:\n');
    [ic_out, vce_out] = compute_ffnn(input_vec, weights_on(1));
    fprintf('  Sortie brute: ic_norm=%.4f, vce_norm=%.4f\n', ic_out, vce_out);
    
    % Dénormalisation
    ic_denorm = (ic_out + 1) * 160 / 2;
    vce_denorm = (vce_out + 1) * 700 / 2;
    fprintf('  Sortie dénormalisée: ic=%.2f A, vce=%.2f V\n', ic_denorm, vce_denorm);
    
    % Test avec quantification
    fprintf('\nTest avec quantification Q1.30:\n');
    [ic_fixed, vce_fixed] = compute_ffnn_fixed(input_vec, weights_fixed_on(1));
    fprintf('  Sortie fixed-point: ic=%.2f A, vce=%.2f V\n', ic_fixed, vce_fixed);
    
    % Erreur de quantification
    error_ic = abs(ic_denorm - ic_fixed);
    error_vce = abs(vce_denorm - vce_fixed);
    fprintf('  Erreur de quantification: ic=%.4f A, vce=%.4f V\n', error_ic, error_vce);
end

function [y1, y2] = compute_ffnn(x, weights)
    % Calcul FFNN en virgule flottante
    
    % Couche cachée: h = tanh(W_h * x + b_h)
    h = tanh(weights.wh * x + weights.bh);
    
    % Couche de sortie: y = W_o * h + b_o
    y = weights.wo * h + weights.bo;
    
    y1 = y(1);
    y2 = y(2);
end

function [y1_denorm, y2_denorm] = compute_ffnn_fixed(x, weights_fixed)
    % Calcul FFNN en fixed-point Q1.30
    
    scale = 2^30;
    
    % Convertir l'entrée en fixed-point
    x_fixed = round(x * scale);
    
    % Couche cachée
    h_sum = zeros(5, 1);
    for i = 1:5
        sum_val = weights_fixed.bh(i);
        for j = 1:3
            % Multiplication et shift
            product = weights_fixed.wh(i,j) * x_fixed(j);
            sum_val = sum_val + floor(product / scale);
        end
        h_sum(i) = sum_val;
    end
    
    % Activation tanh (approximation)
    h_act = zeros(5, 1);
    for i = 1:5
        h_act(i) = tanh_fixed(h_sum(i), scale);
    end
    
    % Couche de sortie
    y_sum = zeros(2, 1);
    for i = 1:2
        sum_val = weights_fixed.bo(i);
        for j = 1:5
            product = weights_fixed.wo(i,j) * h_act(j);
            sum_val = sum_val + floor(product / scale);
        end
        y_sum(i) = sum_val;
    end
    
    % Dénormalisation
    y1_norm = double(y_sum(1)) / scale;
    y2_norm = double(y_sum(2)) / scale;
    
    y1_denorm = (y1_norm + 1) * 160 / 2;  % Ic
    y2_denorm = (y2_norm + 1) * 700 / 2;  % Vce
end

function y = tanh_fixed(x, scale)
    % Approximation tanh en fixed-point
    x_float = double(x) / scale;
    
    % Saturation
    if x_float > 4
        y_float = 1;
    elseif x_float < -4
        y_float = -1;
    else
        y_float = tanh(x_float);
    end
    
    y = round(y_float * scale);
end