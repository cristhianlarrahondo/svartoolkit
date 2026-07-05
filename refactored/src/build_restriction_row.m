function row = build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
%BUILD_RESTRICTION_ROW  Construye una fila de Cfg.S{k}/Cfg.Z{k} con el
%offset de columna correcto, generalizado a cualquier numero de
%horizontes en Cfg.HORIZONS_RESTRICT.
%
%   row = BUILD_RESTRICTION_ROW(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
%
%   CONVENCION (verificada contra original/helpfunctions/ZIRF.m,
%   IRF_horizons.m, y original/figure_1_panel_b/run_mainfile1.m):
%
%   Las columnas de S{k}/Z{k} se organizan en numel(Cfg.HORIZONS_RESTRICT)
%   bloques de n_vars columnas cada uno, en el mismo orden que
%   Cfg.HORIZONS_RESTRICT (bloque 1 = horizons(1), bloque 2 = horizons(2),
%   ...). Dentro de cada bloque, la columna j corresponde a la variable
%   endogena j (orden ordinal, igual que Dataset.var_names tras aplicar
%   el filtro de endogenas).
%
%   columna activada = (horizon_idx - 1) * n_vars + var_idx
%
%   Entradas:
%     var_idx      indice ordinal de la variable endogena (1..n_vars)
%     horizon_idx  indice ORDINAL dentro de Cfg.HORIZONS_RESTRICT (NO es
%                  el valor del horizonte). Ej.: si
%                  Cfg.HORIZONS_RESTRICT = [0 4 8], horizon_idx=2 se
%                  refiere al horizonte=4 (el segundo elemento del vector).
%     n_vars       numero de variables endogenas (Dataset.nvar)
%     n_horizons   numel(Cfg.HORIZONS_RESTRICT)
%     sign_val     +1  -> restriccion de signo POSITIVO (para S)
%                  -1  -> restriccion de signo NEGATIVO (para S)
%                  +1  -> restriccion de CERO (para Z; el signo no importa,
%                         se usa +1 por convencion)
%
%   Salida:
%     row   vector fila [1 x (n_vars*n_horizons)] con un unico valor
%           distinto de cero en la posicion calculada.
%
%   EJEMPLO — BNW (horizonte unico h=0, n_vars=5, horizon_idx siempre 1):
%     n_vars = 5; n_horizons = 1;
%     Cfg.Z{1} = build_restriction_row(1, 1, n_vars, n_horizons, 1);  % tfp=0 en h=0
%     Cfg.S{1} = build_restriction_row(2, 1, n_vars, n_horizons, 1);  % sp positivo en h=0
%
%   EJEMPLO — multi-horizonte (n_vars=4, Cfg.HORIZONS_RESTRICT=[0 1 2]):
%     n_vars = 4; n_horizons = 3;
%     % var 3 responde NEGATIVO en el segundo horizonte declarado (h=1):
%     fila = build_restriction_row(3, 2, n_vars, n_horizons, -1);
%
%   Ver tambien: parse_restriction_row (inversa, usada internamente por
%   run_pfa.m para reconstruir variable/horizonte/signo desde una fila).

%% ── Validaciones ─────────────────────────────────────────────────────────
if var_idx < 1 || var_idx > n_vars || var_idx ~= round(var_idx)
    error('build_restriction_row:badVarIdx', ...
        'var_idx debe ser un entero en [1, %d]. Recibido: %g.', n_vars, var_idx);
end
if horizon_idx < 1 || horizon_idx > n_horizons || horizon_idx ~= round(horizon_idx)
    error('build_restriction_row:badHorizonIdx', ...
        ['horizon_idx debe ser un entero en [1, %d] (numel(Cfg.HORIZONS_RESTRICT)). ' ...
         'Recibido: %g.'], n_horizons, horizon_idx);
end
if sign_val == 0
    error('build_restriction_row:badSign', 'sign_val no puede ser 0.');
end

%% ── Construccion ─────────────────────────────────────────────────────────
row = zeros(1, n_vars * n_horizons);
col = (horizon_idx - 1) * n_vars + var_idx;
row(col) = sign_val;

end
