%SPEC_BNW_PFA  Configuracion BNW (examples/bnw) - modo Penalty Function Approach.
%
%   Replica Figure 1, Panel (a) de Arias, Rubio-Ramirez y Waggoner (2018).
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

% -- Overrides especificos de PFA ------------------------------------------
Cfg.MODE          = 'pfa';     % Penalty Function Approach
Cfg.ND            = 1e4;       % draws ortogonal-reduced-form
Cfg.MAX_IS_DRAWS  = 1e4;       % (no aplica en PFA; incluido por completitud)
Cfg.CONJUGATE     = 'irfs';    % 'irfs' | 'structural'  (BNW usan 'irfs')
Cfg.ITER_SHOW     = 2000;
Cfg.SPEC_NAME     = 'spec_bnw_pfa';
