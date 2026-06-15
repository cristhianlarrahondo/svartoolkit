function Cfg = spec_timing_4L1Z()
% spec_timing_4L1Z  Config para timing: 4 lags + 3 signs + 1 zero
%                   Replica la parte izquierda de la Tabla 4 de ARW (2018).
%                   Variables: n=5 (BNW), n=6 (+investment), n=7 (+output).
%
% USO DESDE main.m:
%   main('spec_timing_4L1Z')        → por defecto nvar=5, timing_variant=4
%   main('spec_timing_4L1Z', Cfg)   → Cfg.NVAR / Cfg.TIMING_VARIANT ya seteados
%
% TIMING_VARIANT:
%   1 → conjugate='', pesos=1, sin if-sign (Algorithm 1 sin pesos)
%   2 → conjugate='structural', pesos para TODOS (two-sided), sin if-sign
%   3 → conjugate='structural', pesos para TODOS (one-sided), sin if-sign
%   4 → conjugate='structural', pesos sólo si pasan signs (two-sided)   [***]
%   5 → conjugate='structural', pesos sólo si pasan signs (one-sided)

% ── MODELO ───────────────────────────────────────────────────────────────
Cfg.NLAG           = 4;             % número de lags
Cfg.NEX            = 1;             % constante
Cfg.SCALE_FACTOR   = 100;           % factor de escala

% ── RESTRICCIONES ────────────────────────────────────────────────────────
% Horizonte h=0: F(theta) = [L_0] → NS=1
Cfg.HORIZONS_RESTRICT = 0;          % horizonte de restricción
Cfg.NS             = 1;             % número de objetos en F (sólo L_0)
Cfg.USE_ZF         = false;         % 4L1Z usa ZIRF; 12L3Z usa ZF
% Restricciones se definen en run_timing.m dependiendo de NVAR

% ── MUESTREO ─────────────────────────────────────────────────────────────
Cfg.MODE           = 'timing';      % modo timing (despacha a run_timing.m)
Cfg.ND             = 1e4;           % draws totales
Cfg.SEED           = 0;             % semilla rng

% ── TIMING ───────────────────────────────────────────────────────────────
Cfg.TIMING_VARIANT = 4;             % variant por defecto (la más usada en papel)
Cfg.NVAR           = 5;             % número de variables endógenas (5, 6 ó 7)

% ── DATOS ────────────────────────────────────────────────────────────────
% 4L1Z usa data_bnw.xlsx (csv original); las columnas extra para n=6,7
% vienen del mismo archivo extendido (Hoja 1 col 2-8).
% El loader usa DATA_FILE_TIMING que apunta a data_bnw.xlsx
Cfg.DATA_FILE      = '';            % vacío → usa data/data_bnw.xlsx del proyecto
Cfg.DATA_SOURCE    = 'bnw_csv';     % 'bnw_csv' | 'timing_xlsx'
%   bnw_csv    → Hoja 1 de data_bnw.xlsx (BNW 5 vars + ext 6/7)
%   timing_xlsx → data_timing.xlsx (datos mensuales Tabla 4, 12L3Z)

% ── OUTPUT ───────────────────────────────────────────────────────────────
Cfg.SAVE_RESULTS   = false;
Cfg.ITER_SHOW      = 2000;

end
