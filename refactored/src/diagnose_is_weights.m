function frac_top = diagnose_is_weights(Results, Cfg)
%DIAGNOSE_IS_WEIGHTS  Diagnóstico de pesos del Importance Sampler.
%
%   frac_top = DIAGNOSE_IS_WEIGHTS(Results, Cfg)
%
%   Diagnostica la distribución de los pesos IS:
%     - Histograma de pesos normalizados (guardado como PNG)
%     - Índice Pareto-k: ajuste GPD a la cola superior
%     - Alerta si el top-5% de draws concentra >50% del peso total
%
%   Solo aplica a modo IS. Lanza error informativo si se llama con PFA.
%
%   Entrada:
%     Results   struct devuelto por run_is.m
%     Cfg       struct de configuración (usa Cfg.SPEC_NAME)
%
%   Salida:
%     frac_top  fracción del peso total concentrada en top-5% de draws

%% ── Validar modo ─────────────────────────────────────────────────────────
if ~isfield(Results, 'LtildeStruct')
    error('diagnose_is_weights:missingField', ...
        'diagnose_is_weights: Results no contiene LtildeStruct.');
end

mode_str = Results.LtildeStruct.mode;
if ~strcmpi(mode_str, 'is')
    error('diagnose_is_weights:wrongMode', ...
        ['diagnose_is_weights: esta función solo aplica a modo IS.\n' ...
         'El Results proporcionado corresponde a modo ''%s''.\n' ...
         'Para PFA no existen pesos IS que diagnosticar.'], mode_str);
end

%% ── Validar campo uw ─────────────────────────────────────────────────────
if ~isfield(Results, 'uw')
    error('diagnose_is_weights:missingUW', ...
        'diagnose_is_weights: Results no contiene campo .uw (pesos sin normalizar).');
end

%% ── Normalizar pesos ─────────────────────────────────────────────────────
uw     = Results.uw(:);
sum_uw = sum(uw);
if sum_uw <= 0
    error('diagnose_is_weights:zeroWeights', ...
        'diagnose_is_weights: la suma de pesos es cero o negativa.');
end
w = uw / sum_uw;   % pesos normalizados [nd x 1]

nd = numel(w);

%% ── Nombre de la spec ────────────────────────────────────────────────────
if isfield(Cfg, 'SPEC_NAME') && ~isempty(Cfg.SPEC_NAME)
    spec_name = Cfg.SPEC_NAME;
else
    spec_name = 'is';
end

%% ── Índice Pareto-k ──────────────────────────────────────────────────────
% Ajuste GPD a la cola superior (top 20% de pesos positivos).
% k es el shape parameter de la GPD: k > 0.7 indica cola pesada problemática.
%   k < 0.5  → diagnóstico benigno
%   0.5 ≤ k < 0.7  → advertencia leve
%   k ≥ 0.7  → distribución inestable, resultados IS poco confiables
%
% Estimamos k con el estimador de momentos de Hill simplificado.

w_pos  = sort(w(w > 0), 'descend');   % pesos positivos, de mayor a menor
n_pos  = numel(w_pos);
n_tail = max(10, floor(n_pos * 0.20)); % top 20% como cola, mínimo 10

if n_tail >= 2
    % Estimador de Hill para el índice de la cola (shape GPD)
    tail_vals = w_pos(1:n_tail);
    threshold = w_pos(n_tail + 1);   % umbral de la cola
    exceedances = tail_vals - threshold;
    exceedances = exceedances(exceedances > 0);
    if ~isempty(exceedances)
        k_hat = mean(log(exceedances)) - log(min(exceedances));
    else
        k_hat = 0;
    end
else
    k_hat = NaN;
end

%% ── Fracción concentrada en top-5% ──────────────────────────────────────
n_top5     = max(1, floor(nd * 0.05));
[w_sorted] = sort(w, 'descend');
frac_top   = sum(w_sorted(1:n_top5));

%% ── Imprimir diagnóstico en consola ─────────────────────────────────────
sep = repmat('─', 1, 60);
fprintf('\n%s\n', sep);
fprintf('  DIAGNOSE_IS_WEIGHTS — %s\n', spec_name);
fprintf('%s\n', sep);
fprintf('  Draws totales          : %d\n', nd);
fprintf('  Draws con peso > 0     : %d (%.1f%%)\n', sum(w > 0), 100*sum(w>0)/nd);
fprintf('  Peso máximo individual : %.6f\n', max(w));
fprintf('  Peso mínimo (positivo) : %.6f\n', min(w(w > 0)));
fprintf('  ESS (1/sum(w^2))       : %.0f\n', 1/sum(w.^2));

% Pareto-k
if ~isnan(k_hat)
    if k_hat < 0.5
        k_label = 'OK (cola ligera)';
    elseif k_hat < 0.7
        k_label = 'ADVERTENCIA (cola moderada)';
    else
        k_label = 'PROBLEMA (cola pesada)';
    end
    fprintf('  Índice Pareto-k        : %.3f  %s\n', k_hat, k_label);
else
    fprintf('  Índice Pareto-k        : N/A (insuficientes puntos en cola)\n');
end

% Concentración en top-5%
fprintf('  Peso top-5%% draws     : %.4f (%.1f%% del total)\n', frac_top, 100*frac_top);
if frac_top > 0.50
    fprintf('\n  [ADVERTENCIA] El top-5%% de draws concentra %.1f%% del peso IS.\n', 100*frac_top);
    fprintf('               Los resultados pueden ser sensibles a pocos draws.\n');
    fprintf('               Considera aumentar ND o revisar las restricciones.\n');
end
fprintf('%s\n\n', sep);

%% ── Histograma de pesos ──────────────────────────────────────────────────
fig = figure('Visible', 'off');

% Solo pesos positivos para el histograma (los cero distorsionan la escala)
w_hist = w(w > 0);

histogram(w_hist, 50, 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.75);
hold on;

% Línea vertical en el umbral top-5%
thr_val = w_sorted(n_top5);
xline(thr_val, 'r--', 'LineWidth', 1.5, 'Label', 'Top 5%', 'LabelVerticalAlignment', 'bottom');

xlabel('Peso IS normalizado (draws con w > 0)', 'FontSize', 10);
ylabel('Frecuencia', 'FontSize', 10);
title(sprintf('Distribución de pesos IS — %s\nPareto-k = %.3f  |  Top-5%% concentra %.1f%% del peso', ...
    strrep(spec_name, '_', '\_'), k_hat, 100*frac_top), 'FontSize', 11);
set(gca, 'FontSize', 9);
grid on; box off;

%% ── Guardar figura ───────────────────────────────────────────────────────
% Ruta de salida relativa a la ubicación de esta función
this_dir  = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
fig_dir   = fullfile(proj_root, 'output', 'figures');
if ~exist(fig_dir, 'dir')
    mkdir(fig_dir);
end

fig_path = fullfile(fig_dir, sprintf('is_weights_%s.png', spec_name));
exportgraphics(fig, fig_path, 'Resolution', 150);
close(fig);

fprintf('  Histograma guardado en: output/figures/is_weights_%s.png\n\n', spec_name);

end
