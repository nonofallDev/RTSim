function coeff_fixed = quantize_coefficients(coefficients)
    % Format: 32-bit fixed-point (1 bit sign, 1 bit integer, 30 bits fraction)
    word_length = 32;
    fraction_length = 30;
    
    % Turn-on
    n_on = length(coefficients.turn_on);
    coeff_fixed.turn_on = struct('wh', [], 'bh', [], 'wo', [], 'bo', []);
    
    for j = 1:n_on
        coeff_fixed.turn_on(j).wh = fi(coefficients.turn_on(j).wh, ...
            1, word_length, fraction_length);
        coeff_fixed.turn_on(j).bh = fi(coefficients.turn_on(j).bh, ...
            1, word_length, fraction_length);
        coeff_fixed.turn_on(j).wo = fi(coefficients.turn_on(j).wo, ...
            1, word_length, fraction_length);
        coeff_fixed.turn_on(j).bo = fi(coefficients.turn_on(j).bo, ...
            1, word_length, fraction_length);
    end
    
    % Turn-off (similaire)
    % ...
    
    % Générer les fichiers COE pour Block RAM
    generate_coe_files(coeff_fixed);
end

function generate_coe_files(coeff_fixed)
    % Générer fichiers .coe pour initialiser les BRAM dans Vivado
    
    % Turn-on weights hidden layer
    fid = fopen('wh_turn_on.coe', 'w');
    fprintf(fid, 'memory_initialization_radix=16;\n');
    fprintf(fid, 'memory_initialization_vector=\n');
    
    for j = 1:length(coeff_fixed.turn_on)
        wh = coeff_fixed.turn_on(j).wh;
        for i = 1:numel(wh)
            hex_val = hex(wh(i));
            fprintf(fid, '%s,\n', hex_val);
        end
    end
    fclose(fid);
    
    % Répéter pour bh, wo, bo...
end