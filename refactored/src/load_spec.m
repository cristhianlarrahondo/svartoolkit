function Cfg = load_spec(spec_path)
%LOAD_SPEC  Carga un archivo de configuración spec_*.m y devuelve la struct Cfg.
%
%   Cfg = LOAD_SPEC(spec_path)
%
%   Ejecuta el spec en un workspace temporal aislado y extrae la struct Cfg
%   resultante. Resuelve el error "Attempt to add Cfg to a static workspace"
%   que ocurre al llamar run() directamente dentro de una función MATLAB.
%
%   Entrada:
%     spec_path   ruta absoluta al archivo spec_*.m
%
%   Salida:
%     Cfg         struct de configuración populada por el spec

if ~isfile(spec_path)
    error('load_spec:notFound', 'load_spec: archivo no encontrado: %s', spec_path);
end

%% ── Ejecutar spec en una función anónima para aislar el workspace ────────
% Técnica: wrappear en evalin sobre base workspace NO funciona desde función.
% Alternativa correcta: usar feval con un script auxiliar temporal, o
% ejecutar con run() en una función anidada que tenga su propio workspace.
% La solución más portable: crear una función auxiliar inline con eval().

% Leer el contenido del spec
spec_code = fileread(spec_path);

% Ejecutar el código del spec en el workspace LOCAL de esta función.
% Aquí sí puede crear 'Cfg' porque load_spec tiene workspace dinámico
% (función no-anidada sin variables preasignadas estáticas).
eval(spec_code);   %#ok<EVLEQ>

% 'Cfg' ahora existe en el workspace de load_spec
if ~exist('Cfg', 'var')
    error('load_spec:noCfg', ...
        'load_spec: el spec no definió la variable Cfg: %s', spec_path);
end

end
