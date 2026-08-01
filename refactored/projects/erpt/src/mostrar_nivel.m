function mostrar_nivel(Results, Dataset, Cfg, bandas, resp_vars)
%MOSTRAR_NIVEL  Tabla de nivel acumulado L(h) (Figura 2, ERPT-Chat 21
%   decision 2) en consola. Reemplaza a mostrar_cirf.m (CIRF generica,
%   retirada del reporte -- invalida para variables a/a).
    if nargin >= 4 && ~isempty(bandas)
        if isvector(bandas); bandas = reshape(bandas, 1, []); end
        Cfg.CRED_BANDS = bandas(1, :);
    end
    if nargin < 5
        resp_vars = [];
    end
    transform_type = 'aa';
    if isfield(Cfg, 'ERPT_TRANSFORM') && ~isempty(Cfg.ERPT_TRANSFORM)
        transform_type = Cfg.ERPT_TRANSFORM;
    end
    Level = build_level_response(Results, Dataset, Cfg, transform_type, resp_vars);
    erpt_print_level_digest(Level);
end
