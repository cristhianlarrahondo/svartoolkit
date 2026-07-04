%SPEC_BNW_IS  Configuracion BNW (examples/bnw) - modo Importance Sampler (IS).
%
%   Replica Figure 1, Panel (b) de Arias, Rubio-Ramirez y Waggoner (2018).
%   Misma identificacion que spec_bnw_pfa.m.
%   Hereda todos los campos comunes de spec_bnw_base.m via
%   eval(fileread(...)) y sobreescribe unicamente MODE, ND, MAX_IS_DRAWS,
%   CONJUGATE, ITER_SHOW y SPEC_NAME.
%
%   Este script es ejecutado por pipeline_bnw.m via run(cfg_path).
%   Popula la struct Cfg en el workspace del caller.

% -- Ruta a este proyecto (examples/bnw/), NUNCA pwd/cd/'..' -------------
cfg_dir   = fileparts(mfilename('fullpath'));   % .../examples/bnw/config/
ex_dir    = fileparts(cfg_dir);                 % .../examples/bnw/
base_path = fullfile(cfg_dir, 'spec_bnw_base.m');

% -- Incluir campos comunes (usa ex_dir definido arriba) -----------------
eval(fileread(base_path));

% -- Overrides especificos de IS -------------------------------------------
Cfg.MODE          = 'is';          % Importance Sampler (Algorithm 3)
Cfg.ND            = 3e4;           % draws ortogonal-reduced-form (igual que original)
Cfg.MAX_IS_DRAWS  = 1e4;           % max draws efectivos del IS tras resampling
Cfg.CONJUGATE     = 'structural';  % 'structural' | 'irfs' (original usa 'structural')
Cfg.ITER_SHOW     = 1000;
Cfg.SPEC_NAME     = 'spec_bnw_is';
