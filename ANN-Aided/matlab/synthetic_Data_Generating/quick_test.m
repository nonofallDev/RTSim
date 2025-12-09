% quick_test.m
% Script de test rapide - Tout-en-un

clear all;
close all;
clc;

fprintf('╔════════════════════════════════════════════╗\n');
fprintf('║   Test Rapide FFNN IGBT sur FPGA          ║\n');
fprintf('╚════════════════════════════════════════════╝\n\n');

%% Étape 1: Générer les données
fprintf('[1/3] Génération des données...\n');
generate_test_data();
fprintf('      ✓ Terminé\n\n');

%% Étape 2: Vérifier le calcul
fprintf('[2/3] Vérification du calcul FFNN...\n');
verify_ffnn_computation();
fprintf('      ✓ Terminé\n\n');

%% Étape 3: Afficher un résumé
fprintf('[3/3] Résumé des fichiers générés:\n');
files = {'test_data.mat', 'coefficients.coe', 'coefficients.mem', ...
         'test_vectors.txt', 'expected_results.txt', 'transient_waveforms.png'};

for i = 1:length(files)
    if exist(files{i}, 'file')
        info = dir(files{i});
        fprintf('      ✓ %s (%.1f KB)\n', files{i}, info.bytes/1024);
    else
        fprintf('      ✗ %s (MANQUANT)\n', files{i});
    end
end

fprintf('\n╔════════════════════════════════════════════╗\n');
fprintf('║   Prochaines étapes:                       ║\n');
fprintf('║   1. Copier coefficients.mem dans Vivado   ║\n');
fprintf('║   2. Lancer la simulation                  ║\n');
fprintf('║   3. Exécuter compare_results.m            ║\n');
fprintf('╚════════════════════════════════════════════╝\n');