function mostrar_irf(Results, Dataset, Cfg, bandas)
%MOSTRAR_IRF  Tabla de respuestas al impulso (IRF) en consola.
    if nargin >= 4 && ~isempty(bandas); Cfg.CRED_BANDS = bandas; end
    print_summary(Results.LtildeStruct, Dataset, Cfg);
end
