function lag = resolve_aa_lag(Dataset)
%RESOLVE_AA_LAG  Rezago de reconstruccion a/a segun Dataset.freq.
%
%   lag = RESOLVE_AA_LAG(Dataset)
%
%   Extraida de calculate_erpt.m (ERPT-Chat 22) para poder reutilizarse
%   fuera de esa funcion -- en particular desde build_level_response.m
%   (Figura 2, ERPT-Chat 21 decision 2), sin duplicar la logica.
%
%   Lag devuelto segun Dataset.freq: 12 si 'M', 4 si 'Q', 1 si 'A'. Error
%   explicito si Dataset.freq no existe o no es reconocido -- no se
%   asume ningun default silencioso.
%
%   Vive en projects/erpt/src/ (Tipo S, no toca src/ compartido).
%
%   Ver tambien: calculate_erpt.m, accumulate_level.m, build_level_response.m

if ~isfield(Dataset, 'freq')
    error('resolve_aa_lag:missingFreq', 'Dataset.freq no existe.');
end
switch Dataset.freq
    case 'M'
        lag = 12;
    case 'Q'
        lag = 4;
    case 'A'
        lag = 1;
    otherwise
        error('resolve_aa_lag:unknownFreq', ...
            ['No se pudo derivar el rezago de reconstruccion a/a: ' ...
             'Dataset.freq = ''%s'' no reconocido (esperado M/Q/A).'], ...
            Dataset.freq);
end

end
