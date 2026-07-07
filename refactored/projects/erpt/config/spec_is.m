%SPEC_BNW_IS

% -- Ruta a este proyecto (projects/bnw/), NUNCA pwd/cd/'..' -------------
cfg_dir   = fileparts(mfilename('fullpath'));   % .../projects/bnw/config/
ex_dir    = fileparts(cfg_dir);                 % .../projects/bnw/
base_path = fullfile(cfg_dir, 'spec_base.m');

% -- Incluir campos comunes (usa ex_dir definido arriba) -----------------
eval(fileread(base_path));

% -- Overrides especificos de IS -------------------------------------------
Cfg.MODE          = 'is';          % Importance Sampler (Algorithm 3)
Cfg.ND            = 3e5;           % draws ortogonal-reduced-form (igual que original)
Cfg.MAX_IS_DRAWS  = 1e5;           % max draws efectivos del IS tras resampling
Cfg.CONJUGATE     = 'structural';  % 'structural' | 'irfs' (original usa 'structural')
Cfg.ITER_SHOW     = 1000;
Cfg.SPEC_NAME     = 'spec_is';

