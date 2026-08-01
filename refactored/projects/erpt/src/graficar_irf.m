function graficar_irf(Results, Dataset, Cfg, bandas)
%GRAFICAR_IRF  Figuras de IRF y CIRF por choque.
    if nargin >= 4 && ~isempty(bandas); Cfg.CRED_BANDS = bandas; end
    plot_irfs(Results.LtildeStruct, Dataset, Cfg, Results);
end
