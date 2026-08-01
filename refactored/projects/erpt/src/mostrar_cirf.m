function mostrar_cirf(Results, Dataset, Cfg, bandas)
%MOSTRAR_CIRF  Tabla de respuestas acumuladas (IRF acumulada / CIRF).
    if nargin >= 4 && ~isempty(bandas); Cfg.CRED_BANDS = bandas; end
    erpt_print_cirf_digest(Results.LtildeStruct, Dataset, Cfg);
end
