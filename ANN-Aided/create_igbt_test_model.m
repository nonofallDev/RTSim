% create_igbt_test_model.m
function create_igbt_test_model()
    % Créer un nouveau modèle Simulink
    model_name = 'IGBT_Transient_Test';
    new_system(model_name);
    open_system(model_name);
    
    % Ajouter les composants Simscape Power Systems
    add_block('powerlib/Electrical Sources/DC Voltage Source', ...
              [model_name '/Vcc']);
    add_block('powerlib/Electrical Sources/DC Current Source', ...
              [model_name '/Load']);
    add_block('powerlib/Power Electronics/IGBT', ...
              [model_name '/S1']);
    add_block('powerlib/Power Electronics/IGBT', ...
              [model_name '/S2']);
    
    % Configurer le solver
    set_param(model_name, 'Solver', 'ode23tb');
    set_param(model_name, 'MaxStep', '2e-9');
    set_param(model_name, 'RelTol', '1e-6');
    
    % Ajouter les mesures
    add_block('powerlib/Measurements/Voltage Measurement', ...
              [model_name '/V_measure']);
    add_block('powerlib/Measurements/Current Measurement', ...
              [model_name '/I_measure']);
end