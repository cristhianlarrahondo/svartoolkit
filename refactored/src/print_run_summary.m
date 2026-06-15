function print_run_summary(Cfg, Results, t_elapsed)
%PRINT_RUN_SUMMARY  Imprime resumen de diagnóstico al terminar un run.
%
%   PRINT_RUN_SUMMARY(Cfg, Results, t_elapsed)
%
%   Imprime en consola: spec name, modo, draws efectivos (ESS o nd),
%   tasa de aceptación (IS), tiempo transcurrido.
%
%   Entrada:
%     Cfg        struct de configuración (campos MODE, ND, SPEC_NAME)
%     Results    struct devuelta por run_pfa o run_is
%                  PFA: Results.LtildeStruct.ndraws
%                  IS:  Results.ne, Results.uw
%     t_elapsed  tiempo en segundos (obtenido con toc)
%
%   Campos de Results esperados:
%     PFA — ninguno adicional (nd ya está en Cfg.ND)
%     IS  — Results.ne (ESS), Results.uw (pesos sin normalizar)

%% ── Nombre de la spec ────────────────────────────────────────────────────
if isfield(Cfg, 'SPEC_NAME') && ~isempty(Cfg.SPEC_NAME)
    spec_name = Cfg.SPEC_NAME;
else
    spec_name = '(sin nombre)';
end

%% ── Separador visual ─────────────────────────────────────────────────────
fprintf('\n');
fprintf('══════════════════════════════════════════════\n');
fprintf('  RUN SUMMARY — %s\n', spec_name);
fprintf('══════════════════════════════════════════════\n');
fprintf('  Modo          : %s\n', upper(Cfg.MODE));

%% ── Métricas según modo ──────────────────────────────────────────────────
switch lower(Cfg.MODE)

    case 'pfa'
        %% PFA: nd draws, todos cuentan
        nd = Cfg.ND;
        fprintf('  Draws (nd)    : %d\n', nd);

    case 'is'
        %% IS: ESS, tasa de aceptación de restricciones de signo
        ne   = Results.ne;
        nd   = Cfg.ND;
        uw   = Results.uw;

        % Draws con peso > 0 satisfacen restricciones de signo
        n_accept = sum(uw > 0);
        accept_rate = n_accept / nd;

        fprintf('  Draws (nd)    : %d\n', nd);
        fprintf('  ESS (ne)      : %d\n', ne);
        fprintf('  ESS/nd        : %.4f\n', ne / nd);
        fprintf('  Tasa acept.   : %.4f  (%d / %d draws)\n', ...
                accept_rate, n_accept, nd);

    otherwise
        % Modo timing u otros: solo nd
        if isfield(Cfg, 'ND')
            fprintf('  Draws (nd)    : %d\n', Cfg.ND);
        end
end

%% ── Tiempo transcurrido ──────────────────────────────────────────────────
if t_elapsed < 60
    fprintf('  Tiempo        : %.1f s\n', t_elapsed);
elseif t_elapsed < 3600
    fprintf('  Tiempo        : %.1f min\n', t_elapsed / 60);
else
    fprintf('  Tiempo        : %.1f h\n', t_elapsed / 3600);
end

fprintf('══════════════════════════════════════════════\n');
fprintf('\n');

end
