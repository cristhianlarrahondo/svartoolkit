function graficar_fevd(Results, Dataset, Cfg)
%GRAFICAR_FEVD  Figuras de descomposicion de varianza (FEVD) -- delega en
%   plot_fevd.m (core).
%
%   ERPT-Chat 22 (round 4), decision del usuario: post-proceso ENTERAMENTE
%   del lado ERPT (reabrir la figura recien creada, editar, re-guardar el
%   PNG con el MISMO nombre) -- NO se toca plot_fevd.m (core, compartido
%   con BNW/oil_market). Post-proceso aplicado a TODAS las figuras FEVD:
%     - Eje X/Y: "Horizon" / "Variance share explained" (core los deja en
%       espanol: "Horizonte" / "Fraccion de varianza explicada")
%     - Leyenda: ultima entrada "Resto (no identificado)" -> "Other
%       (unidentified)" (los nombres de choque ya salen en ingles porque
%       Cfg.SHOCK_NAMES se edito a ingles en la spec -- ver ERPT-Chat 22)
%     - Titulo: se ELIMINA ("no poner titulos a los graficos" -- el pie de
%       figura va en el paper, no en el PNG)
%     - Resolucion de exportacion: 300 dpi (core guarda a 150dpi; se veian
%       pixeladas)
%
%   Ver tambien: plot_fevd.m (core)

    endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
    all_labels = Dataset.var_labels(endo_mask);
    nvar       = numel(all_labels);

    response_idx = 1:nvar;
    if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
        ri = Cfg.RESP_IDX;
        response_idx = ri(ri >= 1 & ri <= nvar);
    end
    expected_labels = all_labels(response_idx);

    % -- Cerrar figuras FEVD de una corrida previa con el MISMO nombre,
    %    para que las unicas figuras con ese nombre tras llamar a
    %    plot_fevd sean las recien creadas --
    for kk = 1:numel(expected_labels)
        h = findobj('Type', 'figure', 'Name', sprintf('FEVD - %s', expected_labels{kk}));
        if ~isempty(h); close(h); end
    end

    plot_fevd(Results, Dataset, Cfg);

    if isfield(Cfg, 'OUTPUT_DIR') && ~isempty(Cfg.OUTPUT_DIR)
        fig_dir = fullfile(Cfg.OUTPUT_DIR, 'figures');
    else
        src_root  = fileparts(mfilename('fullpath'));
        proj_root = fileparts(src_root);
        fig_dir   = fullfile(proj_root, 'output', 'figures');
    end
    fig_suffix = '';
    if isfield(Cfg, 'FIG_SUFFIX') && ~isempty(Cfg.FIG_SUFFIX)
        fig_suffix = Cfg.FIG_SUFFIX;
    end

    for kk = 1:numel(expected_labels)
        v_idx = response_idx(kk);
        label_resp = expected_labels{kk};
        hFig = findobj('Type', 'figure', 'Name', sprintf('FEVD - %s', label_resp));
        if isempty(hFig)
            continue;   % variable omitida (p.ej. is_run_skipped en plot_fevd.m)
        end
        hFig = hFig(1);
        ax = findobj(hFig, 'Type', 'axes');
        if ~isempty(ax)
            ax = ax(1);
            xlabel(ax, 'Horizon');
            ylabel(ax, 'Variance share explained');
            title(ax, '');
            if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
                ax.Toolbar.Visible = 'off';
            end
        end

        leg = findobj(hFig, 'Type', 'legend');
        if ~isempty(leg)
            leg = leg(1);
            leg_str = leg.String;
            for s = 1:numel(leg_str)
                if strcmpi(leg_str{s}, 'Resto (no identificado)')
                    leg_str{s} = 'Other (unidentified)';
                end
            end
            leg.String = leg_str;
        end

        var_name_safe = regexprep(label_resp, '[^a-zA-Z0-9_]', '_');
        fname = fullfile(fig_dir, sprintf('fevd_var%d_%s%s.png', v_idx, var_name_safe, fig_suffix));
        set(hFig, 'PaperPositionMode', 'auto');
        print(hFig, fname, '-dpng', '-r300');
        fprintf('[graficar_fevd] Post-procesada y re-guardada a 300dpi: %s\n', fname);
    end
end
