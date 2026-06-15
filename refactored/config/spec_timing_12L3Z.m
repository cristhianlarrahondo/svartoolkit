function Cfg = spec_timing_12L3Z()
% spec_timing_12L3Z  Config para timing: 12 lags + 3 signs + 3 zeros
%                    Replica la parte derecha de la Tabla 4 de ARW (2018).
%                    Variables: n=5,6,7 (sistema mensual macro, sin constante).
%
% TIMING_VARIANT (idéntico a spec_timing_4L1Z):
%   1 → conjugate='', pesos=1, sin if-sign
%   2 → conjugate='structural', pesos TODOS (two-sided), sin if-sign
%   3 → conjugate='structural', pesos TODOS (one-sided), sin if-sign
%   4 → conjugate='structural', pesos sólo si signs (two-sided)          [***]
%   5 → conjugate='structural', pesos sólo si signs (one-sided)

% ── MODELO ───────────────────────────────────────────────────────────────
Cfg.NLAG           = 12;            % número de lags (mensual)
Cfg.NEX            = 0;             % sin constante
Cfg.SCALE_FACTOR   = 1;             % datos ya en log×100 en el loader

% ── RESTRICCIONES ────────────────────────────────────────────────────────
% horizons = 0:0 → F(theta) = [A_0; L_0] → NS = 1 + numel(0:0) = 2
Cfg.HORIZONS_RESTRICT = 0:0;        % horizonte: 0 (incluye A_0 y L_0)
Cfg.NS             = 2;             % 1 + numel(horizons)
Cfg.USE_ZF         = true;          % 12L3Z usa ZF (no ZIRF)
% Restricciones se definen en run_timing.m dependiendo de NVAR

% ── MUESTREO ─────────────────────────────────────────────────────────────
Cfg.MODE           = 'timing';
Cfg.ND             = 1e4;
Cfg.SEED           = 0;

% ── TIMING ───────────────────────────────────────────────────────────────
Cfg.TIMING_VARIANT = 4;
Cfg.NVAR           = 5;             % 5, 6 ó 7

% ── DATOS ────────────────────────────────────────────────────────────────
Cfg.DATA_FILE      = '';            % vacío → usa data/data_timing.xlsx
Cfg.DATA_SOURCE    = 'timing_xlsx'; % 'bnw_csv' | 'timing_xlsx'
%   timing_xlsx → data_timing.xlsx (datos mensuales 12L3Z, cols ya en log×100
%                  excepto FFR que entra en % anualizado)

% ── OUTPUT ───────────────────────────────────────────────────────────────
Cfg.SAVE_RESULTS   = false;
Cfg.ITER_SHOW      = 2000;

end
