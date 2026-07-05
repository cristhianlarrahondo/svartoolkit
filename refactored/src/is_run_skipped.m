function [skipped, reason] = is_run_skipped(x)
%IS_RUN_SKIPPED  Detecta si un struct Results o LtildeStruct proviene de
%una corrida que run_pfa.m omitio deliberadamente (p.ej. una spec con mas
%de un choque restringido, que PFA/Mountford-Uhlig no puede resolver).
%
%   [skipped, reason] = IS_RUN_SKIPPED(x)
%
%   Entrada:
%     x   struct Results (de run_pfa.m/run_is.m) o LtildeStruct (de
%         pack_ltilde.m). Ambos pueden portar los campos .skipped y
%         .skip_reason cuando la corrida fue omitida.
%
%   Salida:
%     skipped   true/false
%     reason    mensaje explicativo (cadena vacia si skipped=false)
%
%   Uso tipico al inicio de funciones de post-proceso:
%
%     [skip, reason] = is_run_skipped(Results);
%     if skip
%         fprintf('[nombre_funcion] Omitido: %s\n', reason);
%         return;
%     end

skipped = isfield(x, 'skipped') && x.skipped;

if skipped && isfield(x, 'skip_reason')
    reason = x.skip_reason;
elseif skipped
    reason = 'Corrida omitida (sin detalle adicional).';
else
    reason = '';
end

end
