function [var_idx, horizon_idx, sign_val] = parse_restriction_row(row, n_vars)
%PARSE_RESTRICTION_ROW  Inversa de build_restriction_row.m — extrae la
%variable, el horizonte (ordinal) y el signo codificados en una fila de
%Cfg.S{k}/Cfg.Z{k}.
%
%   [var_idx, horizon_idx, sign_val] = PARSE_RESTRICTION_ROW(row, n_vars)
%
%   Requiere que la fila tenga EXACTAMENTE una entrada distinta de cero
%   (una restriccion = una variable, un horizonte). Esto es lo que exige
%   la normalizacion por ssigma del metodo de Mountford-Uhlig (PFA) y es,
%   ademas, la practica estandar para restricciones de signo/cero en la
%   literatura (Kilian & Murphy 2012, Uhlig 2005, etc.). Si tu caso de uso
%   requiere combinaciones lineales de variables en una sola fila, esta
%   funcion (y por tanto run_pfa.m) no lo soporta — usa Cfg.MODE='is'.
%
%   Entradas:
%     row      vector fila [1 x (n_vars*n_horizons)] de S{k} o Z{k}
%     n_vars   numero de variables endogenas
%
%   Salidas:
%     var_idx      indice ordinal de la variable (1..n_vars)
%     horizon_idx  indice ORDINAL dentro de Cfg.HORIZONS_RESTRICT
%     sign_val     valor no-cero encontrado (tipicamente +1 o -1)

nz = find(row ~= 0);

if numel(nz) ~= 1
    error('parse_restriction_row:notSingleVariable', ...
        ['Esta fila tiene %d entradas distintas de cero; se esperaba ' ...
         'exactamente 1 (una restriccion = una variable, un horizonte). ' ...
         'PFA no soporta restricciones que combinen varias variables u ' ...
         'horizontes en una misma fila — usa Cfg.MODE=''is'' para ese caso.'], ...
        numel(nz));
end

horizon_idx = ceil(nz / n_vars);
var_idx     = nz - (horizon_idx - 1) * n_vars;
sign_val    = row(nz);

end
