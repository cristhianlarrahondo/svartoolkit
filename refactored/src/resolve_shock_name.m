function name = resolve_shock_name(shock_names, idx)
%RESOLVE_SHOCK_NAME  Nombre de un shock para labels/leyendas/nombres de archivo.
%
%   name = RESOLVE_SHOCK_NAME(shock_names, idx)
%
%   Contexto (Chat 19, Hallazgo 9): antes de este chat, algunas funciones
%   (select_irfs.m) usaban el LABEL DE LA VARIABLE como si fuera el nombre
%   del shock (coincidencia casual en BNW porque cada shock restringido se
%   asocia 1:1 a una variable, pero no es general). Esta funcion centraliza
%   la unica logica de fallback usada en todo el toolkit para nombrar
%   shocks, evitando duplicarla en select_irfs.m/plot_irfs.m/plot_fevd.m/
%   export_results.m.
%
%   Entradas:
%     shock_names   Cfg.SHOCK_NAMES: cell array de strings, o [] / {} si
%                   no esta definido.
%     idx           indice (1-based) del shock.
%
%   Salida:
%     name   shock_names{idx} si esta definido y no vacio; si no,
%            'shock<idx>' (p.ej. 'shock1', 'shock2', ...).
%
%   Ver tambien: README_cfg_reference.md (campo SHOCK_NAMES)

if ~isempty(shock_names) && idx <= numel(shock_names) && ~isempty(shock_names{idx})
    name = shock_names{idx};
else
    name = sprintf('shock%d', idx);
end

end
