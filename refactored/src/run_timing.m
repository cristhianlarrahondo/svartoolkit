function Results = run_timing(Cfg, Dataset, Posterior)
% run_timing  Loop IS con medición de tiempo para replicar Tabla 4 de ARW (2018).
%
% Implementa los 5 "Timings" via switch Cfg.TIMING_VARIANT:
%
%  Timing 1 (T1): sin pesos IS (conjugate=''); uw=1 si pasa signs, 0 si no.
%                 Mide sólo el tiempo base del algoritmo sin cómputo de volumen.
%  Timing 2 (T2): conjugate='structural', two-sided; computa pesos para TODOS
%                 los draws (sin if-sign). Cota superior de costo.
%  Timing 3 (T3): como T2 pero one-sided (LogVolumeElementOneSidedND).
%  Timing 4 (T4): conjugate='structural', two-sided; pesos sólo si pasan signs. [***]
%  Timing 5 (T5): como T4 pero one-sided.
%
% Dos configuraciones de modelo:
%   4L1Z : NLAG=4, NEX=1, NS=1, USE_ZF=false → ZIRF, StructuralRestrictions
%   12L3Z: NLAG=12, NEX=0, NS=2, USE_ZF=true  → ZF, SF

%==========================================================================
%% Extraer params
%==========================================================================
nlag     = Cfg.NLAG;
nvar     = Cfg.NVAR;
nex      = Cfg.NEX;
m        = nvar * nlag + nex;
nd       = Cfg.ND;
seed     = Cfg.SEED;
tv       = Cfg.TIMING_VARIANT;
horizons = Cfg.HORIZONS_RESTRICT;
NS       = Cfg.NS;
use_zf   = Cfg.USE_ZF;

PphiTilde       = Posterior.PphiTilde;
nnuTilde        = Posterior.nnuTilde;
PpsiTilde       = Posterior.PpsiTilde;
OomegaTilde     = Posterior.OomegaTilde;

%==========================================================================
%% Semilla
%==========================================================================
rng('default');
rng(seed);

%==========================================================================
%% Restricciones de signo y cero
%==========================================================================
S = cell(nvar, 1);
for ii = 1:nvar
    S{ii} = zeros(0, nvar * NS);
end
ns1 = 3;
S{1} = zeros(ns1, nvar * NS);

Z = cell(nvar, 1);
for i = 1:nvar
    Z{i} = zeros(0, nvar * NS);
end

if ~use_zf
    %── 4L1Z ───────────────────────────────────────────────────────────────
    % F(theta) = [L_0], NS=1
    % Sign: columna 1 del shock → L_0[2,1]>0, L_0[3,1]>0, L_0[4,1]>0
    S{1}(1, 2) = 1;   % Stock Prices positivo
    S{1}(2, 3) = 1;   % Consumption positivo
    S{1}(3, 4) = 1;   % Real Int Rate positivo
    % Zero: TFP (fila 1) no responde en h=0
    Z{1} = zeros(1, nvar * NS);
    Z{1}(1, 1) = 1;
else
    %── 12L3Z ──────────────────────────────────────────────────────────────
    % F(theta) = [A_0; L_0], NS=2, horizons=0:0
    % Sign: A_0[4,1]<0 (M2), A_0[5,1]>0 (FFR), L_0[5,1]>0 (FFR)
    S{1}(1, 4)        = -1;
    S{1}(2, 5)        =  1;
    S{1}(3, nvar + 5) =  1;
    % Zero: filas 1-3 (GDP, Deflator, PCOM) en A_0
    Z{1} = zeros(3, nvar * NS);
    Z{1}(1, 1) = 1;
    Z{1}(2, 2) = 1;
    Z{1}(3, 3) = 1;
end

%==========================================================================
%% Setup info
%==========================================================================
hh   = @(x) chol(x);
info = SetupInfo(nvar, m, Z, hh);
info.nlag     = nlag;
info.horizons = horizons;

if use_zf
    info.ZF = @(x, y) ZF(x, y);
else
    info.ZF = @(x, y) ZIRF(x, y);
end

iw_info = info;
fs = @(x) ff_h(x, iw_info);
r  = @(x) ZeroRestrictions(x, iw_info);

% Función de check de sign restrictions
if use_zf
    e = eye(nvar);
    fh_S_restrictions = @(x) SF(x, iw_info, S);
else
    fh_S_restrictions = @(y) StructuralRestrictions(y, S);
end

%==========================================================================
%% Selección de modo según TIMING_VARIANT
%==========================================================================
% T1: conjugate='', if_sign=true   → uw=1 si pasa, 0 si no
% T2: conjugate='structural', two-sided, computa para TODOS
% T3: conjugate='structural', one-sided, computa para TODOS
% T4: conjugate='structural', two-sided, sólo si pasan signs
% T5: conjugate='structural', one-sided, sólo si pasan signs
switch tv
    case 1
        conjugate  = '';
        use_onesid = false;
        if_sign    = true;
    case 2
        conjugate  = 'structural';
        use_onesid = false;
        if_sign    = false;   % sin if-sign: siempre computa peso
    case 3
        conjugate  = 'structural';
        use_onesid = true;
        if_sign    = false;
    case 4
        conjugate  = 'structural';
        use_onesid = false;
        if_sign    = true;
    case 5
        conjugate  = 'structural';
        use_onesid = true;
        if_sign    = true;
    otherwise
        error('run_timing: TIMING_VARIANT debe ser 1-5 (valor: %d)', tv);
end

%==========================================================================
%% Preparación
%==========================================================================
cholOomegaTilde = hh(OomegaTilde)';

uw          = zeros(nd, 1);
storevefh   = zeros(nd, 1);
storevegfhZ = zeros(nd, 1);
Bdraws      = cell([nd, 1]);
Sigmadraws  = cell([nd, 1]);
Qdraws      = cell([nd, 1]);

record = 1;
count  = 0;

%==========================================================================
%% Loop principal
%==========================================================================
tStart = tic;

while record <= nd

    %── Paso 1: draw (B, Sigma) ────────────────────────────────────────────
    Sigmadraw     = iwishrnd(PphiTilde, nnuTilde);
    cholSigmadraw = hh(Sigmadraw)';
    Bdraw = kron(cholSigmadraw, cholOomegaTilde) * randn(m * nvar, 1) ...
            + reshape(PpsiTilde, nvar * m, 1);
    Bdraw = reshape(Bdraw, nvar * nlag + nex, nvar);

    Bdraws{record, 1}     = Bdraw;
    Sigmadraws{record, 1} = Sigmadraw;

    %── Pasos 2-4: draw Q satisfaciendo ceros (Algorithm 2) ───────────────
    w          = DrawW(iw_info);
    x          = [vec(Bdraw); vec(Sigmadraw); w];
    structpara = ff_h_inv(x, iw_info);

    Qdraw             = SpheresToQ(w, iw_info, Bdraw, Sigmadraw);
    Qdraws{record, 1} = reshape(Qdraw, nvar, nvar);

    %── Check de sign restrictions ─────────────────────────────────────────
    signs = fh_S_restrictions(structpara);

    if use_zf
        pass_signs = (sum(signs{1} * e(:, 1) > 0)) == size(signs{1} * e(:, 1), 1);
    else
        pass_signs = (sum(signs > 0)) == size(signs, 1);
    end

    %── Lógica de peso según variant ───────────────────────────────────────
    if if_sign
        %── T1, T4, T5: computa pesos sólo si pasan signs ─────────────────
        if pass_signs
            count = count + 1;
            if strcmp(conjugate, 'structural')
                storevefh(record, 1) = (nvar * (nvar + 1) / 2) * log(2) ...
                    - (2 * nvar + m + 1) * ...
                    LogAbsDet(reshape(structpara(1:nvar*nvar), nvar, nvar));
                if use_onesid
                    storevegfhZ(record, 1) = LogVolumeElementOneSidedND(fs, structpara, r);
                else
                    storevegfhZ(record, 1) = LogVolumeElement(fs, structpara, r);
                end
                uw(record, 1) = exp(storevefh(record, 1) - storevegfhZ(record, 1));
            else
                % T1: sin IS real → uw = 1 si pasa signs (como en original)
                uw(record, 1) = 1;
            end
        else
            uw(record, 1) = 0;   % no pasa signs
        end

    else
        %── T2, T3: computa pesos para TODOS (sin if-sign) ─────────────────
        % En el original T2/T3 el if-sign está COMENTADO:
        % siempre computa el peso, nunca pone uw=0
        if pass_signs
            count = count + 1;
        end
        if strcmp(conjugate, 'structural')
            storevefh(record, 1) = (nvar * (nvar + 1) / 2) * log(2) ...
                - (2 * nvar + m + 1) * ...
                LogAbsDet(reshape(structpara(1:nvar*nvar), nvar, nvar));
            if use_onesid
                storevegfhZ(record, 1) = LogVolumeElementOneSidedND(fs, structpara, r);
            else
                storevegfhZ(record, 1) = LogVolumeElement(fs, structpara, r);
            end
            uw(record, 1) = exp(storevefh(record, 1) - storevegfhZ(record, 1));
        else
            uw(record, 1) = 1;
        end
    end

    record = record + 1;

    if mod(record, Cfg.ITER_SHOW) == 0
        fprintf('  [T%d] draw %d/%d | signs OK: %d\n', tv, record, nd, count);
    end

end % while

tElapsed = toc(tStart);

%==========================================================================
%% Effective Sample Size
%==========================================================================
imp_w = uw / sum(uw);
ne    = floor(1 / sum(imp_w .^ 2));

%==========================================================================
%% Resultados
%==========================================================================
Results.tElapsed       = tElapsed;
Results.count          = count;
Results.nd             = nd;
Results.ne             = ne;
Results.uw             = uw;
Results.timing_variant = tv;

end % function
