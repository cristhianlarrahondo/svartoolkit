function frac_stable = check_stability(Results, Cfg)
%CHECK_STABILITY  Fracción de draws con VAR estable.
%
%   frac_stable = CHECK_STABILITY(Results, Cfg)
%
%   Para cada draw de B y Sigma, construye la companion matrix del VAR
%   y verifica que todos sus eigenvalores caigan dentro del círculo unitario
%   (|lambda| < 1). Imprime la fracción en consola y emite advertencia si
%   la fracción es menor que 0.99.
%
%   Soporta PFA y IS transparentemente (usa Bdraws y Sigmadraws de Results).
%
%   Entrada:
%     Results   struct devuelto por run_pfa.m o run_is.m
%     Cfg       struct de configuración (usa Cfg.SPEC_NAME)
%
%   Salida:
%     frac_stable  escalar en [0,1]: fracción de draws estables

%% ── Guard: corrida omitida (p.ej. PFA con >1 choque restringido) ────────
[skip_run, skip_reason] = is_run_skipped(Results);
if skip_run
    fprintf('[check_stability] Omitido: %s\n', skip_reason);
    frac_stable = NaN;
    return;
end

%% ── Validar campos requeridos ────────────────────────────────────────────
required = {'Bdraws', 'Sigmadraws', 'LtildeStruct'};
for ii = 1:numel(required)
    if ~isfield(Results, required{ii})
        error('check_stability:missingField', ...
            'check_stability: Results no contiene campo .%s.', required{ii});
    end
end

%% ── Extraer parámetros ───────────────────────────────────────────────────
Bdraws     = Results.Bdraws;
nd         = numel(Bdraws);
mode_str   = Results.LtildeStruct.mode;
n          = Results.LtildeStruct.nvar;

% Nombre de la spec
if isfield(Cfg, 'SPEC_NAME') && ~isempty(Cfg.SPEC_NAME)
    spec_name = Cfg.SPEC_NAME;
else
    spec_name = mode_str;
end

% Número de lags: inferir desde dimensiones de B
% B tiene dimensiones [n*p + nex, n]; nex suele ser 1 (constante)
B_example = Bdraws{1};
m_rows    = size(B_example, 1);
% m_rows = n*p + nex  →  p = (m_rows - nex) / n
% nex se puede inferir desde Cfg si está disponible
if isfield(Cfg, 'NEX')
    nex = Cfg.NEX;
else
    nex = 0;   % default conservador; sobreestima p si hay exógenas
end
p = (m_rows - nex) / n;
if p ~= floor(p) || p < 1
    % Fallback: asumir nex=1 (constante)
    nex = 1;
    p   = (m_rows - nex) / n;
    if p ~= floor(p) || p < 1
        error('check_stability:badDims', ...
            'check_stability: no se puede inferir el número de lags desde Bdraws.');
    end
end
p = round(p);

%% ── Construir companion matrix template ─────────────────────────────────
% La companion matrix de orden p para un VAR(p) con n variables:
%   F = [A1 A2 ... Ap]
%       [I  0  ... 0 ]
%       [0  I  ... 0 ]
%       ...
% donde Ai son los coeficientes de lag i.
% F es [p*n x p*n].

np = p * n;
F_lower = [eye(np - n), zeros(np - n, n)];   % bloques identidad inferiores

%% ── Loop sobre draws ─────────────────────────────────────────────────────
n_stable = 0;

for s = 1:nd

    B_s = Bdraws{s};   % [n*p + nex, n]

    % Extraer coeficientes de lags (primeras n*p filas, excluyendo exógenas)
    B_lags = B_s(1:n*p, :);   % [n*p, n]

    % Fila superior de F: [A1 ... Ap] donde Ai = B_lags((i-1)*n+1:i*n, :)'
    % En la parametrización A+ B: cada columna j de B_lags es el vector de
    % coeficientes de la ecuación j. La companion necesita la traspuesta.
    %
    % Notación: si y_t = A1*y_{t-1} + ... + Ap*y_{t-p} + ...
    % entonces B = [A1'; A2'; ...; Ap'; c'] (filas = lags)
    % y F = [A1 A2 ... Ap; I 0 ... 0; ...]
    %      = [B_lags(1:n,:)' | B_lags(n+1:2n,:)' | ... | B_lags((p-1)*n+1:p*n,:)']
    %
    % Construir fila superior de la companion
    F_top = zeros(n, np);
    for l = 1:p
        col_start = (l-1)*n + 1;
        col_end   = l*n;
        F_top(:, col_start:col_end) = B_lags((l-1)*n+1:l*n, :)';
    end

    F = [F_top; F_lower];

    % Eigenvalores de la companion
    ev        = eig(F);
    max_modulus = max(abs(ev));

    if max_modulus < 1
        n_stable = n_stable + 1;
    end

end

frac_stable = n_stable / nd;

%% ── Imprimir resultado ───────────────────────────────────────────────────
sep = repmat('─', 1, 60);
fprintf('\n%s\n', sep);
fprintf('  CHECK_STABILITY — %s  [%s]\n', upper(mode_str), spec_name);
fprintf('%s\n', sep);
fprintf('  Draws totales        : %d\n', nd);
fprintf('  Draws estables       : %d\n', n_stable);
fprintf('  Fraccion estable     : %.4f (%.2f%%)\n', frac_stable, 100*frac_stable);

if frac_stable < 0.99
    fprintf('\n  [ADVERTENCIA] Solo el %.2f%% de los draws son estables.\n', 100*frac_stable);
    fprintf('               Considera revisar la especificacion o aumentar ND.\n');
else
    fprintf('  Estabilidad: OK (>= 99%%)\n');
end
fprintf('%s\n\n', sep);

end

