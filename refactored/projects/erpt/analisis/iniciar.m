% iniciar.m -- Correr UNA VEZ por sesion. Agrega el toolkit al path de MATLAB.
%   Despues de esto, cualquier analisis_*.m corre directo (F5 o por secciones),
%   sin una sola linea de rutas en el analisis.

this_file = mfilename('fullpath');
if isempty(this_file) || contains(this_file, tempdir)
    this_file = matlab.desktop.editor.getActiveFilename;   % robusto en el Editor
end
ANALISIS_DIR = fileparts(this_file);              % .../projects/erpt/analisis
PROJ_ROOT    = fileparts(ANALISIS_DIR);           % .../projects/erpt
REF_ROOT     = fileparts(fileparts(PROJ_ROOT));   % .../refactored

addpath(fullfile(REF_ROOT,'src'));
addpath(fullfile(REF_ROOT,'helpfunctions'));
addpath(fullfile(REF_ROOT,'config'));
addpath(fullfile(REF_ROOT,'validate'));
addpath(fullfile(PROJ_ROOT,'src'));
addpath(fullfile(PROJ_ROOT,'config'));
addpath(ANALISIS_DIR);

fprintf('Toolkit ERPT listo. Ya puedes correr los analisis_*.m\n');
