function L = accumulate_level(irf_slice, transform_type, lag)
%ACCUMULATE_LEVEL  Nivel acumulado L(h) de una respuesta al impulso.
%
%   L = ACCUMULATE_LEVEL(irf_slice, transform_type, lag)
%
%   Extraida de calculate_erpt.m (funcion local p_accumulate, ERPT-Chat
%   1 decision 2) para poder reutilizarse fuera de esa funcion -- en
%   particular desde build_level_response.m (Figura 2, ERPT-Chat 21
%   decision 2) -- SIN duplicar la logica ni cambiar el resultado
%   numerico. calculate_erpt.m ahora llama a esta misma funcion.
%
%   ── Entradas ─────────────────────────────────────────────────────────
%     irf_slice       [horizon+1 x 1 x ndraws] -- IRF de una variable
%                     bajo un choque fijo (una celda de select_irfs.m).
%     transform_type  'mm' | 'aa'
%     lag             rezago de reconstruccion a/a (ver resolve_aa_lag.m).
%                     Ignorado si transform_type = 'mm' (puede pasarse []).
%
%   ── Formula ──────────────────────────────────────────────────────────
%     'mm':  L(h) = IRF(0) + IRF(1) + ... + IRF(h)   (CIRF estandar,
%            compute_cirfs.m -- cumsum plano sobre la dimension 1;
%            NO se modifica compute_cirfs.m, se le sigue llamando igual)
%     'aa':  L(h) = IRF(h)               para h < lag
%            L(h) = IRF(h) + L(h-lag)    para h >= lag
%
%   Vive en projects/erpt/src/ (Tipo S, no toca src/ compartido). NO
%   modifica compute_cirfs.m (core, compartido) -- solo lo invoca en la
%   rama 'mm'.
%
%   Ver tambien: calculate_erpt.m, resolve_aa_lag.m, compute_cirfs.m,
%   build_level_response.m

switch transform_type
    case 'mm'
        L = compute_cirfs(irf_slice);
    case 'aa'
        H = size(irf_slice, 1);
        L = zeros(size(irf_slice));
        for h = 1:H   % h=1 <-> horizonte 0
            if h <= lag
                L(h, 1, :) = irf_slice(h, 1, :);
            else
                L(h, 1, :) = irf_slice(h, 1, :) + L(h - lag, 1, :);
            end
        end
    otherwise
        error('accumulate_level:badTransform', ...
            'transform_type debe ser ''mm'' o ''aa''. Recibido: ''%s''.', transform_type);
end

end
