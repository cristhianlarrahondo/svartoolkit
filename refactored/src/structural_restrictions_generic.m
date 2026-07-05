function y = structural_restrictions_generic(x, S, nvar, nlag, npredetermined, horizons)
%STRUCTURAL_RESTRICTIONS_GENERIC  Generalizacion de
%helpfunctions/StructuralRestrictions.m a restricciones de signo en
%CUALQUIER horizonte (no solo h=0).
%
%   y = STRUCTURAL_RESTRICTIONS_GENERIC(x, S, nvar, nlag, npredetermined, horizons)
%
%   IMPORTANTE: vive en src/, NO en helpfunctions/. No modifica
%   helpfunctions/StructuralRestrictions.m, que se preserva intacto
%   (evalua restricciones de signo unicamente en h=0, tal como el codigo
%   original de BNW). run_is.m usa esta version generalizada.
%
%   Por que hacia falta: helpfunctions/StructuralRestrictions.m construye
%   f = inv(A0)' (la respuesta de impacto en h=0) sin importar cuantos
%   horizontes declare Cfg.HORIZONS_RESTRICT. Si S{j} se construyo con
%   build_restriction_row.m para mas de un horizonte (numel(horizons)>1),
%   S{j} tiene numel(horizons)*nvar columnas pero f(:,j) solo tiene nvar
%   filas -> error de dimensiones. Esta version usa IRF_horizons.m (que
%   SI esta generalizado a cualquier horizonte) para construir la pila
%   completa de respuestas antes de aplicar S{j}.
%
%   Con horizons=0 (escalar), esta funcion reproduce EXACTAMENTE
%   helpfunctions/StructuralRestrictions.m: IRF_horizons(x,nvar,nlag,
%   npredetermined,0) devuelve inv(A0)', identico a L0 en la version
%   original.
%
%   Entradas:
%     x               parametros estructurales vectorizados [vec(A0); vec(Aplus)]
%     S               cell(nvar,1) de matrices de restriccion de signo,
%                     cada S{j} de tamano [nsj x (numel(horizons)*nvar)]
%     nvar,nlag,npredetermined,horizons   igual que IRF_horizons.m /
%                     info.nvar, info.nlag, info.npredetermined, info.horizons
%
%   Salida:
%     y   [total_signos x 1] valor de cada restriccion de signo evaluada;
%         debe ser > 0 para satisfacer la restriccion (misma convencion
%         que helpfunctions/StructuralRestrictions.m y ZeroRestrictions.m)

total_signos = 0;
for j = 1:nvar
    total_signos = total_signos + size(S{j}, 1);
end

% IRF: [numel(horizons)*nvar x nvar] — misma convencion que ZIRF.m
% (bloques apilados por horizonte; columna j = shock j)
IRF = IRF_horizons(x, nvar, nlag, npredetermined, horizons);

y  = zeros(total_signos, 1);
ib = 1;
for j = 1:nvar
    nsj = size(S{j}, 1);
    if nsj > 0
        ie = ib + nsj;
        y(ib:ie-1) = S{j} * IRF(:, j);
        ib = ie;
    end
end

end
