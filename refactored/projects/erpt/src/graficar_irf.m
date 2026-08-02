function graficar_irf(Results, Dataset, Cfg, bandas)
%GRAFICAR_IRF  Figuras de IRF (y, si Cfg.IRF_TYPE lo pide, CIRF generica)
%   por choque -- delega en plot_irfs.m (core).
%
%   ERPT-Chat 22, decision del usuario: TODO el post-proceso visual de
%   Figura 1 se resuelve ENTERAMENTE del lado ERPT (reabrir la figura
%   recien creada, editar, re-guardar el PNG con el MISMO nombre) -- NO se
%   toca plot_irfs.m (core, compartido con BNW/oil_market). Post-proceso
%   aplicado (solo si Cfg.RESP_IDX esta restringido a variables de
%   inflacion, unico caso en que TODOS los paneles comparten unidad):
%     - Eje Y: "p.p. of annual inflation" (round 4, texto exacto pedido)
%     - Titulo de cada panel: se quita el sufijo " Inflation" (Imports
%       Inflation -> Imports; Producer Inflation -> Producer; etc.)
%     - Titulo general de la figura (tiledlayout): se ELIMINA (round 4,
%       "no poner titulos a los graficos" -- el pie de figura va en el
%       paper, no en el PNG)
%     - Resolucion de exportacion: 300 dpi (round 4, se veian pixeladas)
%     - Grid del eje: apagado (round 5 -- se veia como una cuadricula a
%       traves de la banda semi-transparente)
%
%   Si Cfg.RESP_IDX no esta definido (todas las variables, incluye ea/ir),
%   no se aplica ningun post-proceso (paneles de unidades distintas).
%
%   Ver tambien: plot_irfs.m (core)

    if nargin >= 4 && ~isempty(bandas); Cfg.CRED_BANDS = bandas; end

    price_var_names = {'imp_inf', 'pro_inf', 'con_inf'};
    do_relabel = false;
    if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
        endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
        var_names  = Dataset.var_names(endo_mask);
        resp_names = var_names(Cfg.RESP_IDX);
        do_relabel = all(ismember(resp_names, price_var_names));
    end

    % -- Cerrar figuras IRF de una corrida previa con el MISMO nombre, para
    %    no reetiquetar ni resobreescribir por error un PNG de otra corrida
    %    que quedo abierta en la sesion de MATLAB --
    if do_relabel
        p_close_existing_irf_figs(Results.LtildeStruct, Cfg);
    end

    plot_irfs(Results.LtildeStruct, Dataset, Cfg, Results);

    if do_relabel
        p_relabel_irf_y(Results.LtildeStruct, Cfg, 'p.p. of annual inflation');
    end
end


%% ── Helpers locales (post-proceso, sin tocar plot_irfs.m) ────────────────

function shock_idx = p_resolve_shock_idx(LtildeStruct, Cfg)
    shock_idx = LtildeStruct.shock_idx;
    if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
        shock_idx = Cfg.SHOCK_IDX;
    end
    if (ischar(shock_idx) || isstring(shock_idx)) && strcmpi(shock_idx, 'all')
        shock_idx = 1:LtildeStruct.nvar;
    end
    shock_idx = shock_idx(:)';
end

function shock_names = p_resolve_shock_names(Cfg)
    shock_names = {};
    if isfield(Cfg, 'SHOCK_NAMES') && ~isempty(Cfg.SHOCK_NAMES)
        shock_names = Cfg.SHOCK_NAMES;
    end
end

function fig_dir = p_resolve_fig_dir(Cfg)
    if isfield(Cfg, 'OUTPUT_DIR') && ~isempty(Cfg.OUTPUT_DIR)
        fig_dir = fullfile(Cfg.OUTPUT_DIR, 'figures');
    else
        src_root  = fileparts(mfilename('fullpath'));
        proj_root = fileparts(src_root);
        fig_dir   = fullfile(proj_root, 'output', 'figures');
    end
end

function p_close_existing_irf_figs(LtildeStruct, Cfg)
%P_CLOSE_EXISTING_IRF_FIGS  Cierra figuras 'IRF - <label>' abiertas de una
%   corrida anterior en la misma sesion de MATLAB, para que las unicas
%   figuras con ese nombre tras llamar a plot_irfs sean las recien creadas.
    shock_idx   = p_resolve_shock_idx(LtildeStruct, Cfg);
    shock_names = p_resolve_shock_names(Cfg);
    for k = 1:numel(shock_idx)
        label_shock = resolve_shock_name(shock_names, shock_idx(k));
        h = findobj('Type', 'figure', 'Name', sprintf('IRF - %s', label_shock));
        if ~isempty(h)
            close(h);
        end
    end
end

function p_relabel_irf_y(LtildeStruct, Cfg, ylabel_text)
%P_RELABEL_IRF_Y  Post-proceso de Figura 1 (round 4): eje Y uniforme,
%   titulo general eliminado, titulos de panel acortados (sin "Inflation"),
%   export a 300 dpi. Re-guarda el PNG SOBRESCRIBIENDO el mismo archivo
%   (mismo nombre/ruta que plot_irfs.m ya uso).
    shock_idx   = p_resolve_shock_idx(LtildeStruct, Cfg);
    shock_names = p_resolve_shock_names(Cfg);
    fig_dir     = p_resolve_fig_dir(Cfg);
    fig_suffix  = '';
    if isfield(Cfg, 'FIG_SUFFIX') && ~isempty(Cfg.FIG_SUFFIX)
        fig_suffix = Cfg.FIG_SUFFIX;
    end

    for k = 1:numel(shock_idx)
        sidx        = shock_idx(k);
        label_shock = resolve_shock_name(shock_names, sidx);
        hFig = findobj('Type', 'figure', 'Name', sprintf('IRF - %s', label_shock));
        if isempty(hFig)
            continue;   % shock omitido (p.ej. is_run_skipped en plot_irfs.m)
        end
        hFig = hFig(1);

        % -- Ejes: ylabel uniforme + titulo de panel acortado + sin grid +
        %    toolbar off. El grid (core lo deja 'on' con GridAlpha=0.05) se
        %    ve como una cuadricula a traves de la banda semi-transparente
        %    (FaceAlpha 0.5) -- round 5, se retira.
        ax_all = findall(hFig, 'Type', 'axes');
        for a = 1:numel(ax_all)
            ylabel(ax_all(a), ylabel_text);
            current_title = get(get(ax_all(a), 'Title'), 'String');
            if ischar(current_title) || iscellstr(current_title)
                short_title = regexprep(current_title, '\s*Inflation\s*$', '');
                title(ax_all(a), short_title, 'Interpreter', 'none');
            end
            grid(ax_all(a), 'off');
            if isprop(ax_all(a), 'Toolbar') && ~isempty(ax_all(a).Toolbar)
                ax_all(a).Toolbar.Visible = 'off';
            end
        end

        % -- Titulo general (tiledlayout): eliminar (round 4, "no poner
        %    titulos a los graficos" -- el pie de figura va en el paper) --
        tl_all = findobj(hFig, '-isa', 'matlab.graphics.layout.TiledChartLayout');
        for t = 1:numel(tl_all)
            title(tl_all(t), '');
        end

        shock_name_safe = regexprep(label_shock, '[^a-zA-Z0-9_]', '_');
        shock_tag       = sprintf('shock%d_%s', sidx, shock_name_safe);
        fname = fullfile(fig_dir, ['irf_', shock_tag, fig_suffix, '.png']);
        set(hFig, 'PaperPositionMode', 'auto');
        print(hFig, fname, '-dpng', '-r300');
        fprintf('[graficar_irf] Post-procesada y re-guardada a 300dpi: %s\n', fname);
    end
end
