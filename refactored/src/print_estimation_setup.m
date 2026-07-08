function Expected = print_estimation_setup(Cfg, Dataset)
%PRINT_ESTIMATION_SETUP  Verifica que Cfg.PRIOR y Cfg.DUMMIES SI entran a la
%estimacion, con evidencia concreta (no solo eco de los campos de Cfg).
%
%   Expected = PRINT_ESTIMATION_SETUP(Cfg, Dataset)
%
%   PROPOSITO: responde la pregunta "¿de verdad se esta usando este prior /
%   estas dummies, o es codigo muerto?" mostrando:
%     - El tipo de prior REALMENTE resuelto (misma logica de default que
%       usa build_posterior.m internamente), y sus hiperparametros.
%     - Cada dummy definida en Cfg.DUMMIES: nombre, tipo, y CUANTAS
%       observaciones tiene realmente activas (~=0) — si sale "0/T", algo
%       esta mal ANTES de esperar a que corra el IS completo.
%     - La dimension m = n*p + NEX + ndummies esperada, para comparar
%       despues contra PosteriorParams.m real.
%
%   Se llama en dos momentos:
%     1) Seccion 2 (revisar config), ANTES de estimar — guardar el
%        struct Expected que devuelve para comparar despues.
%     2) Seccion 3 (estimacion), DESPUES de build_posterior — comparar
%        Expected.prior_type/ndummies/m contra PosteriorParams.prior_type/
%        ndummies/m (campos que build_posterior YA devuelve).
%
%   No modifica src/build_posterior.m, src/run_is.m ni src/run_pfa.m —
%   solo lee Cfg y llama build_dummies.m (ya existente) de forma read-only.
%   Tipo S: sin riesgo de regresion numerica.

fprintf('\n════════════════════════════════════════════\n');
fprintf('  VERIFICACION DE SETUP (prior + dummies)\n');
fprintf('════════════════════════════════════════════\n');

%% -- Prior: misma logica de resolucion que build_posterior.m ------------
% (duplicada intencionalmente: 4 lineas, no justifica tocar build_posterior.m
%  y convertir esto en Tipo R)
if isfield(Cfg, 'PRIOR') && isfield(Cfg.PRIOR, 'type')
    prior_type = lower(strtrim(Cfg.PRIOR.type));
    prior_source = 'via Cfg.PRIOR.type';
else
    prior_type = 'diffuse';
    prior_source = 'DEFAULT — Cfg.PRIOR no definido';
end
fprintf('  Prior resuelto : %s   (%s)\n', prior_type, prior_source);

if isfield(Cfg, 'PRIOR')
    flds = fieldnames(Cfg.PRIOR);
    flds = setdiff(flds, {'type'}, 'stable');
    if ~isempty(flds)
        fprintf('  Hiperparametros leidos de Cfg.PRIOR:\n');
        for i = 1:numel(flds)
            val = Cfg.PRIOR.(flds{i});
            if isnumeric(val) && isscalar(val)
                fprintf('    %-12s = %g\n', flds{i}, val);
            elseif isnumeric(val)
                fprintf('    %-12s = matriz %s\n', flds{i}, mat2str(size(val)));
            else
                fprintf('    %-12s = %s\n', flds{i}, mat2str(val));
            end
        end
    end
end

if ~strcmp(prior_type, 'diffuse')
    fprintf(['  [Nota] Prior distinto de ''diffuse'': se espera que OomegaTilde/\n' ...
             '         PphiTilde en PosteriorParams difieran de una corrida diffuse\n' ...
             '         con los mismos datos y restricciones (evidencia: Chat 12,\n' ...
             '         validate_lote5 Seccion B, comparo posterior explicitamente).\n']);
end

%% -- Dummies: llamado directo a build_dummies, evidencia real -----------
DummyMatrix = build_dummies(Cfg, Dataset.dates);
ndummies    = size(DummyMatrix, 2);

fprintf('\n  Dummies definidas : %d\n', ndummies);
if ndummies == 0
    fprintf('    (ninguna — Cfg.DUMMIES no definido o vacio)\n');
else
    for k = 1:ndummies
        d = Cfg.DUMMIES(k);
        col = DummyMatrix(:, k);
        n_active = sum(col ~= 0);
        idx_first = find(col ~= 0, 1, 'first');
        idx_last  = find(col ~= 0, 1, 'last');
        if isfield(d, 'name') && ~isempty(d.name)
            dname = d.name;
        else
            dname = sprintf('(sin nombre #%d)', k);
        end
        if n_active == 0
            fprintf('    [%d] %-20s tipo=%-9s  [ALERTA] 0/%d obs activas — revisar fechas\n', ...
                k, dname, d.type, numel(col));
        else
            fprintf('    [%d] %-20s tipo=%-9s  activa en %d/%d obs  (primera=%s, ultima=%s)\n', ...
                k, dname, d.type, n_active, numel(col), ...
                datestr(Dataset.dates(idx_first), 'mm/yyyy'), ...
                datestr(Dataset.dates(idx_last),  'mm/yyyy'));
        end
    end
end

%% -- Dimension esperada de xt --------------------------------------------
n = Dataset.nvar;
p = Cfg.NLAG;
nex_const = Cfg.NEX;
m_expected = n*p + nex_const + ndummies;

fprintf('\n  Dimension xt (m) esperada = n*p + NEX + ndummies\n');
fprintf('                            = %d*%d + %d + %d = %d\n', ...
    n, p, nex_const, ndummies, m_expected);
fprintf('  (Comparar contra PosteriorParams.m tras build_posterior — Seccion 3)\n');
fprintf('════════════════════════════════════════════\n\n');

%% -- Devolver lo esperado, para comparar despues de build_posterior -----
Expected.prior_type = prior_type;
Expected.ndummies   = ndummies;
Expected.m          = m_expected;

end
