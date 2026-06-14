function irf_draw = compute_irfs_pfa(Bdraw, Sigmadraw, q, p, n, nex, horizon)
%COMPUTE_IRFS_PFA  Calcula IRFs para un draw PFA.
%
%   irf_draw = COMPUTE_IRFS_PFA(Bdraw, Sigmadraw, q, p, n, nex, horizon)
%
%   Retorna slice (horizon+1, n) para el shock identificado por q.
%   Replica la formula: Ltilde(h,:) = (J' * (F')^(h-1) * J) * hSigma' * q
%
%   Entradas:
%     Bdraw       [m x n]   draw de B = [A1/A0; ...; Ap/A0; c/A0]
%     Sigmadraw   [n x n]   draw de Sigma
%     q           [n x 1]   vector optimo del PFA
%     p           scalar    numero de lags
%     n           scalar    numero de variables
%     nex         scalar    1 si hay constante, 0 si no
%     horizon     scalar    horizonte maximo
%
%   Salida:
%     irf_draw    [(horizon+1) x n]  IRFs del shock identificado

hh = @(x) chol(x)';

e      = eye(n);
J      = [e; repmat(zeros(n), p-1, 1)];
extraF = repmat(zeros(n), 1, p-1);
F      = zeros(p*n, p*n);
for l = 1:p-1
    F((l-1)*n+1:l*n, n+1:p*n) = [repmat(zeros(n),1,l-1), e, repmat(zeros(n),1,p-(l+1))];
end

hSigmadraw = hh(Sigmadraw);
A0         = hSigmadraw \ e;
Aplus      = Bdraw * A0;

for l = 1:p-1
    Al = Aplus((l-1)*n+1:l*n, 1:end);
    F((l-1)*n+1:l*n, 1:n) = Al / A0;
end
Ap = Aplus((p-1)*n+1:p*n, 1:end);
F((p-1)*n+1:p*n, :) = [Ap/A0, extraF];

irf_draw = zeros(horizon+1, n);
for h = 1:horizon+1
    irf_draw(h, :) = (J' * ((F')^(h-1)) * J) * hSigmadraw' * q;
end

end
