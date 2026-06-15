function Results = run_pfa(PosteriorParams, Cfg)
%RUN_PFA  Loop Penalty Function Approach (PFA).
%
%   Results = RUN_PFA(PosteriorParams, Cfg)
%
%   Replica exactamente el loop de original/figure_1_panel_a/run_mainfile.m.
%   Las helpfunctions (penalty.m, mycon.m, variancedecomposition.m) deben
%   estar en el path ANTES de llamar esta funcion (main.m se encarga).
%
%   Entrada:
%     PosteriorParams  struct de build_posterior.m
%     Cfg              struct de config/spec_*.m
%
%   Salida: Results struct con campos:
%     .LtildeStruct   struct canonica (via pack_ltilde.m)
%     .FEVD           [n x nd]  forecast error variance decomposition
%     .Bdraws         {nd x 1}  draws de B
%     .Sigmadraws     {nd x 1}  draws de Sigma
%     .Qdraws         {nd x 1}  draws de Q (vector q optimo del PFA)

%% ── Extraer campos de PosteriorParams ────────────────────────────────────
n                 = PosteriorParams.n;
p                 = PosteriorParams.p;
m                 = PosteriorParams.m;
nnuTilde          = PosteriorParams.nnuTilde;
OomegaTilde       = PosteriorParams.OomegaTilde;
PpsiTilde         = PosteriorParams.PpsiTilde;
PphiTilde         = PosteriorParams.PphiTilde;
cholOomegaTilde   = PosteriorParams.cholOomegaTilde;

%% ── Extraer campos de Cfg ────────────────────────────────────────────────
nd        = Cfg.ND;
horizon   = Cfg.HORIZON;
index     = Cfg.INDEX_FEVD;
iter_show = Cfg.ITER_SHOW;
S         = Cfg.S;          % restricciones de signo
Z         = Cfg.Z;          % restricciones de cero

%% ── Globals para penalty.m y mycon.m (igual que el original) ────────────
global ssigma objective;
ssigma = PosteriorParams.ssigma;

%% ── Funcion de Cholesky (igual que el original: hh = chol(x)') ──────────
hh = @(x) chol(x)';

%% ── Definiciones de IRFs (pagina 12 de RWZ 2010) ────────────────────────
e      = eye(n);
J      = [e; repmat(zeros(n), p-1, 1)];
A_cell = cell(p, 1);
extraF = repmat(zeros(n), 1, p-1);
F      = zeros(p*n, p*n);
for l = 1:p-1
    F((l-1)*n+1:l*n, n+1:p*n) = [repmat(zeros(n),1,l-1), e, repmat(zeros(n),1,p-(l+1))];
end

%% ── Pre-alocar arrays de salida ─────────────────────────────────────────
Bdraws     = cell(nd, 1);
Sigmadraws = cell(nd, 1);
Qdraws     = cell(nd, 1);
Ltilde     = zeros(horizon+1, n, nd);
FEVD       = zeros(n, nd);

%% ── Loop PFA ─────────────────────────────────────────────────────────────
counter = 1;
record  = 1;

while record <= nd

    %% ── Draw Sigma e B|Sigma (exactamente como el original) ─────────────
    Sigmadraw     = iwishrnd(PphiTilde, nnuTilde);
    cholSigmadraw = hh(Sigmadraw)';  % upper = chol(S), igual que el original
    Bdraw         = kron(cholSigmadraw, cholOomegaTilde) * randn(m*n, 1) ...
                    + reshape(PpsiTilde, n*m, 1);
    Bdraw         = reshape(Bdraw, n*p + Cfg.NEX, n);

    % Guardar draws
    Bdraws{record,1}     = Bdraw;
    Sigmadraws{record,1} = Sigmadraw;

    %% ── PFA de Mountford y Uhlig (2009) ─────────────────────────────────
    % objective: vector fila para la restriccion de signo (stock prices > 0)
    objective = e(2,:) * hh(Sigmadraw);   % lower = chol(S)', igual que el original
    % Aeq, beq: restriccion lineal de cero (TFP = 0 en h=0)
    Aeq = e(1,:) * hh(Sigmadraw);   % lower triangular — e1*L fuerza q(1)=0
    beq = 0;
    % Punto inicial aleatorio
    q1ga = rand(n, 1);
    % Optimizacion
    [q, ~] = fmincon(@penalty, q1ga, [], [], Aeq, beq, [], [], @mycon, ...
        optimset('MaxFunEvals', 40000, 'MaxIter', 20000, ...
                 'Display', 'off', 'Algorithm', 'active-set'));

    Qdraws{record, 1} = q;

    %% ── Matriz F para IRFs (igual que el original) ───────────────────────
    hSigmadraw = hh(Sigmadraw);
    A0         = hSigmadraw \ e;
    Aplus      = Bdraw * A0;
    for l = 1:p-1
        A_cell{l} = Aplus((l-1)*n+1:l*n, 1:end);
        F((l-1)*n+1:l*n, 1:n) = A_cell{l} / A0;
    end
    A_cell{p} = Aplus((p-1)*n+1:p*n, 1:end);
    F((p-1)*n+1:p*n, :) = [A_cell{p}/A0, extraF];

    %% ── IRFs (igual que el original) ─────────────────────────────────────
    for h = 1:horizon+1
        Ltilde(h, :, record) = (J' * ((F')^(h-1)) * J) * hSigmadraw' * q;
    end

    %% ── FEVD (igual que el original) ─────────────────────────────────────
    FEVD(:, record) = variancedecomposition(F', J, Sigmadraw, hSigmadraw'*q, n, index);

    %% ── Progress display ─────────────────────────────────────────────────
    if counter == iter_show
        fprintf('Number of draws = %d\n', record);
        fprintf('Remaining draws = %d\n', nd - record);
        counter = 0;
    end
    counter = counter + 1;
    record  = record + 1;

end  % while

%% ── Empaquetar LtildeStruct ──────────────────────────────────────────────
LtildeStruct = pack_ltilde(Ltilde, 'pfa', 1, horizon, n, nd);

%% ── Empaquetar Results ───────────────────────────────────────────────────
Results.LtildeStruct = LtildeStruct;
Results.FEVD         = FEVD;
Results.Bdraws       = Bdraws;
Results.Sigmadraws   = Sigmadraws;
Results.Qdraws       = Qdraws;

end

