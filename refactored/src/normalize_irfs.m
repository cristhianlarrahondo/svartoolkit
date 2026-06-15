function [irfs_norm, scale_factors] = normalize_irfs(irfs, type, Cfg, Dataset)
%NORMALIZE_IRFS  Normalización draw-by-draw de IRFs.
%
%   [irfs_norm, scale_factors] = NORMALIZE_IRFS(irfs, type, Cfg, Dataset)
%
%   Aplica la normalización especificada por TYPE a un array de IRFs,
%   draw a draw. Los factores de escala se guardan para trazabilidad.
%
%   Entradas:
%     irfs      [horizon+1, nvar_resp, ndraws]
%               — array de IRFs (salida de select_irfs o raw de LtildeStruct)
%     type      char — tipo de normalización:
%                 'none'     sin normalización (default, pasa irfs sin cambio)
%                 '1sd'      escala por sqrt(Sigma(j,j)) draw a draw
%                            Requiere: Cfg.NORM_SHOCK_IDX (índice j del shock)
%                                      Results.Sigmadraws {nd x 1}
%                            Se pasa Results dentro de Dataset por convención:
%                            llamar con Dataset.Sigmadraws o pasar Results.
%                 'unit'     fija la respuesta de var r en horizonte h a valor v
%                            Requiere: Cfg.NORM_VAR     (índice fila en irfs)
%                                      Cfg.NORM_HORIZON (índice 0-based)
%                                      Cfg.NORM_VALUE   (valor objetivo, default 1)
%                 'own_unit' respuesta diagonal en h=0 normalizada a 1
%                            Requiere que nvar_resp == nvar completo (o al menos
%                            que la diagonal [i,i] esté presente).
%                            En select_irfs, shock j → var j debe estar en
%                            response_idx. Se normaliza cada columna k por
%                            irfs(1, k, d).
%     Cfg       struct de config — campos opcionales leídos según TYPE
%     Dataset   struct de load_data — se usa para Sigmadraws si TYPE='1sd'
%               Alternativa: pasar Results directamente como 4to argumento
%
%   Salidas:
%     irfs_norm      [horizon+1, nvar_resp, ndraws] — IRFs normalizadas
%     scale_factors  [nvar_resp, ndraws] — factor aplicado a cada (var, draw)
%                    Para 'none': scale_factors = ones(nvar_resp, ndraws)
%                    Para '1sd':  scale_factors(k, d) = 1/sqrt(Sigma_d(j,j))
%                    Para 'unit': scale_factors(k, d) = NORM_VALUE / raw(h0,k,d)
%                    Para 'own_unit': scale_factors(k, d) = 1 / irfs(1,k,d)
%
%   Uso típico (desde main o un script de post-proceso):
%
%     irfs_raw = select_irfs(Results.LtildeStruct, shock_idx, response_idx);
%     [irfs_norm, sf] = normalize_irfs(irfs_raw, Cfg.IRF_NORM, Cfg, Results);
%     Results.scale_factors = sf;

%% ── Default de type ──────────────────────────────────────────────────────
if nargin < 2 || isempty(type)
    type = 'none';
end
if nargin < 3
    Cfg = struct();
end
if nargin < 4
    Dataset = struct();
end

%% ── Dimensiones ──────────────────────────────────────────────────────────
sz      = size(irfs);
ntime   = sz(1);          % horizon + 1
nresp   = sz(2);          % número de variables de respuesta
ndraws  = sz(3);          % número de draws

irfs_norm     = irfs;                           % copia de trabajo
scale_factors = ones(nresp, ndraws);            % default: sin escala

%% ── Dispatching por tipo ─────────────────────────────────────────────────
switch lower(type)

    %% ── 'none' ── sin normalización ─────────────────────────────────────
    case 'none'
        % irfs_norm ya es irfs; scale_factors ya es unos
        % Nada que hacer

    %% ── '1sd' ── escala por sqrt(Sigma(j,j)) draw a draw ────────────────
    case '1sd'
        % Requiere Results.Sigmadraws (cell {nd x 1}) y
        % Cfg.NORM_SHOCK_IDX (índice 1-based del shock en la matriz Sigma)

        % Resolver fuente de Sigmadraws
        if isfield(Dataset, 'Sigmadraws') && ~isempty(Dataset.Sigmadraws)
            Sigmadraws = Dataset.Sigmadraws;
        else
            error('normalize_irfs:missingSigma', ...
                ['normalize_irfs: type=''1sd'' requiere Sigmadraws. ', ...
                 'Pásalos en el 4to argumento (Results.Sigmadraws).']);
        end

        % Índice del shock en la diagonal de Sigma
        if isfield(Cfg, 'NORM_SHOCK_IDX')
            j = Cfg.NORM_SHOCK_IDX;
        else
            j = 1;   % default: primer shock
            warning('normalize_irfs:defaultShockIdx', ...
                'Cfg.NORM_SHOCK_IDX no definido; usando j=1 (primer shock).');
        end

        if numel(Sigmadraws) < ndraws
            error('normalize_irfs:sizeMismatch', ...
                'Sigmadraws tiene %d entradas pero irfs tiene %d draws.', ...
                numel(Sigmadraws), ndraws);
        end

        for d = 1:ndraws
            Sigma_d = Sigmadraws{d};
            sd_j    = sqrt(Sigma_d(j, j));   % desviación estándar del shock j
            if sd_j == 0
                warning('normalize_irfs:zeroSd', ...
                    'sqrt(Sigma(%d,%d)) = 0 en draw %d. Escala no aplicada.', j, j, d);
                sd_j = 1;
            end
            scale_d = 1 / sd_j;   % escala: dividir por std = multiplicar por 1/std
            for k = 1:nresp
                irfs_norm(:, k, d)  = irfs(:, k, d) * scale_d;
                scale_factors(k, d) = scale_d;
            end
        end

    %% ── 'unit' ── respuesta de var r en horizonte h fijada a valor v ─────
    case 'unit'
        % Requiere:
        %   Cfg.NORM_VAR     — índice (1-based) en response_idx de la var de ref
        %   Cfg.NORM_HORIZON — horizonte (0-based) en el que se fija la respuesta
        %   Cfg.NORM_VALUE   — valor objetivo (default 1)

        if ~isfield(Cfg, 'NORM_VAR')
            error('normalize_irfs:missingField', ...
                'normalize_irfs: type=''unit'' requiere Cfg.NORM_VAR.');
        end
        if ~isfield(Cfg, 'NORM_HORIZON')
            error('normalize_irfs:missingField', ...
                'normalize_irfs: type=''unit'' requiere Cfg.NORM_HORIZON.');
        end

        r      = Cfg.NORM_VAR;        % índice fila en irfs (1-based)
        h0     = Cfg.NORM_HORIZON + 1;  % horizonte 0-based → índice 1-based
        v_tgt  = 1;
        if isfield(Cfg, 'NORM_VALUE') && ~isempty(Cfg.NORM_VALUE)
            v_tgt = Cfg.NORM_VALUE;
        end

        if r < 1 || r > nresp
            error('normalize_irfs:outOfRange', ...
                'Cfg.NORM_VAR = %d fuera de rango [1, %d].', r, nresp);
        end
        if h0 < 1 || h0 > ntime
            error('normalize_irfs:outOfRange', ...
                'Cfg.NORM_HORIZON = %d fuera de rango [0, %d].', ...
                Cfg.NORM_HORIZON, ntime - 1);
        end

        for d = 1:ndraws
            raw_val = irfs(h0, r, d);
            if raw_val == 0
                warning('normalize_irfs:zeroPivot', ...
                    'IRF(%d,%d) = 0 en draw %d. Escala no aplicada.', ...
                    h0, r, d);
                scale_d = 1;
            else
                scale_d = v_tgt / raw_val;
            end
            irfs_norm(:, :, d)    = irfs(:, :, d) * scale_d;
            scale_factors(:, d)   = scale_d;   % mismo factor para todas las vars
        end

    %% ── 'own_unit' ── respuesta diagonal en h=0 normalizada a 1 ──────────
    case 'own_unit'
        % Normaliza cada variable de respuesta k por su propio impacto en h=0:
        %   irfs_norm(h, k, d) = irfs(h, k, d) / irfs(1, k, d)
        % Donde pivot = 0 (variable con restriccion de cero exacto en h=0),
        % la escala no se aplica (scale_factor = 1, IRF sin cambio).
        % En lugar de emitir un warning por draw, se imprime un resumen unico.

        % pivot_mat: [nresp x ndraws] — impacto en h=0 de cada (var, draw)
        pivot_mat = reshape(irfs(1, :, :), nresp, ndraws);

        zero_mask = (pivot_mat == 0);   % [nresp x ndraws]
        n_zero    = sum(zero_mask(:));

        % Factores de escala: 1/pivot donde pivot!=0, 1 donde pivot==0
        safe_pivot    = pivot_mat;
        safe_pivot(zero_mask) = 1;          % evitar division por cero
        scale_factors = 1 ./ safe_pivot;   % [nresp x ndraws]

        % Aplicar draw-by-draw (solo donde pivot != 0)
        for d = 1:ndraws
            for k = 1:nresp
                if ~zero_mask(k, d)
                    irfs_norm(:, k, d) = irfs(:, k, d) * scale_factors(k, d);
                end
                % pivot==0: irfs_norm ya contiene irfs(:,k,d) sin cambio
            end
        end

        % Resumen unico si hubo pivots cero
        if n_zero > 0
            zero_vars = find(any(zero_mask, 2));
            fprintf(['[normalize_irfs] own_unit: %d casos (var,draw) con pivot=0 ' ...
                     '(vars: %s) — escala no aplicada.\n'], ...
                n_zero, num2str(zero_vars(:)'));
        end


    otherwise
        error('normalize_irfs:unknownType', ...
            ['normalize_irfs: tipo desconocido ''%s''. ', ...
             'Opciones: ''none'', ''1sd'', ''unit'', ''own_unit''.'], type);
end

end

