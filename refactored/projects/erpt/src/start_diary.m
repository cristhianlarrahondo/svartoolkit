function log_path = start_diary(output_root, tag)
%START_DIARY  Inicia un diary con nombre timestamped bajo <root>/output/_logs/.
%   Persiste toda la salida de consola de una corrida validate/reproduce a
%   texto plano, evitando depender del buffer de scrollback de la Command
%   Window en corridas largas o detalladas.
%
%   USO (al inicio de un script validate_*/reproduce_*):
%       PROJ_ROOT      = fileparts(mfilename('fullpath'));
%       addpath(fullfile(PROJ_ROOT, 'src'));
%       log_path_diary = start_diary(PROJ_ROOT, mfilename);
%   ... y al final del CUERPO del script (antes de cualquier 'function'
%   local): diary('off');
%
%   NOTA (por que no onCleanup): en un script ejecutado en el workspace
%   base (F5 / por secciones) las variables NO se destruyen al terminar el
%   script, por lo que un onCleanup(@() diary('off')) no se disparia al
%   cerrar la corrida (y peor: se disparia tarde, apagando el diary de una
%   corrida posterior). Patron robusto: 'diary off' defensivo al inicio
%   (aqui) + 'diary off' explicito al final del cuerpo del script.
%
%   INPUTS
%     output_root : carpeta base del proyecto (p.ej. PROJ_ROOT). El log va
%                   a <output_root>/output/_logs/.
%     tag         : etiqueta del script (p.ej. mfilename).
%   OUTPUT
%     log_path    : ruta absoluta del .log creado.

    if nargin < 2 || isempty(tag)
        tag = 'run';
    end

    % Cierre defensivo de cualquier diary previo que haya quedado abierto
    % (p.ej. si un run anterior fallo antes de su 'diary off' explicito).
    diary('off');

    log_dir = fullfile(output_root, 'output', '_logs');
    if ~isfolder(log_dir)
        mkdir(log_dir);
    end

    stamp    = datestr(now, 'yyyymmdd_HHMMSS');
    log_path = fullfile(log_dir, sprintf('%s_%s.log', tag, stamp));

    diary(log_path);

    fprintf('\n[start_diary] Consola de esta corrida persistida en:\n');
    fprintf('              %s\n\n', log_path);
end
