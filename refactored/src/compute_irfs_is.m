function LIRF_matrix = compute_irfs_is(structpara, n, p, m, horizon)
%COMPUTE_IRFS_IS  IRFs para un draw IS individual.
%
%   LIRF_matrix = COMPUTE_IRFS_IS(structpara, n, p, m, horizon)
%
%   Calcula las IRFs completas (todos los shocks) para un draw del IS
%   usando la helpfunction IRF_horizons de ARW (2018).
%
%   Entrada:
%     structpara  [n*n + m*n x 1]  parametros estructurales [vec(A0); vec(Aplus)]
%     n           scalar            numero de variables endogenas
%     p           scalar            numero de lags
%     m           scalar            m = n*p + nex
%     horizon     scalar            horizonte maximo
%
%   Salida:
%     LIRF_matrix  [(horizon+1) x n x n]  IRFs completas
%                  LIRF_matrix(h+1, i, j) = IRF de variable i al shock j en h
%
%   Nota: Esta funcion es un wrapper delgado sobre IRF_horizons.
%   IRF_horizons debe estar en el path (helpfunctions/).

% Calcular IRFs en todos los horizontes de una vez
% IRF_horizons devuelve [(horizon+1)*n x n] con filas ordenadas por horizonte
LIRF_flat = IRF_horizons(structpara, n, p, m, 0:horizon);

% Reorganizar a 3D: [horizon+1, n, n]
LIRF_matrix = zeros(horizon+1, n, n);
for h = 0:horizon
    % Bloque de filas correspondiente al horizonte h
    LIRF_matrix(h+1, :, :) = LIRF_flat(1 + h*n:(h+1)*n, :);
end

end
