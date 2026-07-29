function Cfg = cargar_spec(spec_name)
%CARGAR_SPEC  Corre el archivo de configuracion <spec_name>.m y devuelve Cfg.
%   El spec debe estar en el path (lo agrega iniciar.m). Uso:
%       Cfg = cargar_spec('spec_C_rob_aa_diffuse_lag4_imp_v0');
    Cfg = struct();
    run([spec_name '.m']);   % el .m del spec rellena los campos de Cfg
end
