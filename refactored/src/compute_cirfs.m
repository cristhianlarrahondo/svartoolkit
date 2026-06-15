function cirfs = compute_cirfs(irfs)
%COMPUTE_CIRFS  Calcula IRFs acumuladas (CIRFs) por suma parcial.
%
%   cirfs = COMPUTE_CIRFS(irfs)
%
%   Aplica cumsum a lo largo del horizonte temporal (dimensión 1).
%   Las CIRFs representan la respuesta acumulada de una variable ante
%   un shock unitario de una desviación estándar.
%
%   Entradas:
%     irfs    array de dimensión [horizon+1, nvar_resp, ndraws]
%             (salida de select_irfs o del array raw de LtildeStruct)
%
%   Salidas:
%     cirfs   array del mismo tamaño — suma acumulada por draw y variable
%
%   El cálculo es:
%     CIRF(h, v, d) = sum_{k=0}^{h} IRF(k, v, d)
%
%   Esta es la transformación estándar para analizar efectos de largo plazo
%   y niveles acumulados en modelos SVAR (Blanchard y Quah 1989,
%   Uhlig 2005, ARW 2018).
%
%   Nota: la función opera sobre cualquier array 3D [T x K x D];
%   no depende de la struct LtildeStruct — es un operador puro.

%% ── Validación ───────────────────────────────────────────────────────────
if ndims(irfs) < 2 || ndims(irfs) > 3
    error('compute_cirfs:invalidDims', ...
        'irfs debe ser un array 2D [T x K] o 3D [T x K x D]. Recibido: %dD.', ...
        ndims(irfs));
end

%% ── Suma acumulada a lo largo de la dimensión 1 (horizonte) ─────────────
cirfs = cumsum(irfs, 1);

end
