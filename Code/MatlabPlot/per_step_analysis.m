function RecreatePerStepBoxplots_FromCSV()

    clear; close all; clc;

    set(groot, "defaultTextInterpreter", "tex");
    set(groot, "defaultAxesTickLabelInterpreter", "tex");
    set(groot, "defaultLegendInterpreter", "tex");

    %% Paths

    ver = "v10_f1";
    plotpath = "C:\Research\HybridModel\March2025\Plots";
    save_plot_path = fullfile(plotpath, "BB", ver);
    redo_dir = fullfile(save_plot_path, "RedoMatlab");

    stats_path = fullfile(redo_dir, "per_step_boxplot_stats.csv");
    meta_path  = fullfile(redo_dir, "per_step_boxplot_meta.csv");

    stats = readtable(stats_path, "TextType", "string");
    meta  = readtable(meta_path, "TextType", "string");

    plot_one_split(stats, meta, "training", redo_dir);
    plot_one_split(stats, meta, "validation", redo_dir);

end


function plot_one_split(stats, meta, split_name, redo_dir)

    feature_keys = ["Biomass (g/L)", "Substrate (g/L)", "DO (%)"];

    fig = figure("Color", "w");
    set(fig, "Units", "centimeters");
    set(fig, "Position", [2 2 28 17]);

    % Manual stacked layout, no vertical gaps
    left = 0.13;
    bottom0 = 0.12;
    width = 0.80;
    total_h = 0.78;
    panel_h = total_h / 3;

    axes_list = gobjects(3, 1);

    for i = 1:3

        ax_bottom = bottom0 + (3 - i) * panel_h;

        ax = axes( ...
            "Parent", fig, ...
            "Position", [left, ax_bottom, width, panel_h] ...
        );

        axes_list(i) = ax;
        hold(ax, "on");

        feature = feature_keys(i);

        d = stats( ...
            stats.split == split_name & ...
            stats.feature == feature, : ...
        );

        d = sortrows(d, "step");

        m = meta( ...
            meta.split == split_name & ...
            meta.feature == feature, : ...
        );

        % Draw compact boxplot stats manually
        draw_box_stats( ...
            ax, ...
            d.step, ...
            d.whis_low, ...
            d.q25, ...
            d.median, ...
            d.q75, ...
            d.whis_high, ...
            0.5 ...
        );

        % Global dashed p5/p95 lines
        yline(ax, m.global_p5(1), "--", "LineWidth", 1.2);
        yline(ax, m.global_p95(1), "--", "LineWidth", 1.2);

        n_steps_out = max(d.step);

        xlim(ax, [0.5, n_steps_out + 0.5]);
        set(ax, "YScale", "log");

        apply_y_ticks(ax, split_name, feature);

        ylabel(ax, sprintf("%s\nRMSE\n(log scale)", feature), ...
            "FontName", "Arial");

        ax.TickDir = "in";
        ax.LineWidth = 1.5;
        ax.FontSize = 14;
        ax.FontName = "Arial";
        ax.Box = "off";

        ax.XMinorTick = "on";
        ax.YMinorTick = "on";

        if i < 3
            ax.XTickLabel = [];
        else
            keep = 10:10:n_steps_out;
            ax.XTick = keep;
            ax.XTickLabel = string(keep);
            xlabel(ax, sprintf("Forecast step (1-%d)", n_steps_out), ...
                "FontName", "Arial");
        end

    end

    % Align y-labels approximately
    for i = 1:3
        axes_list(i).YLabel.Units = "normalized";
        axes_list(i).YLabel.Position(1) = -0.065;
    end

    % Remove MATLAB toolbar icons before saving
    all_axes = findall(fig, "Type", "axes");

    for ii = 1:numel(all_axes)
        try
            all_axes(ii).Toolbar.Visible = "off";
        catch
        end

        try
            disableDefaultInteractivity(all_axes(ii));
        catch
        end
    end

    out_pdf = fullfile( ...
        redo_dir, ...
        "matlab_recreated_ensemble_per_step_rmse_stacked_" + split_name + ".pdf" ...
    );

    exportgraphics(fig, char(out_pdf), ...
        "ContentType", "vector", ...
        "BackgroundColor", "white");

    disp("[OK] Saved:")
    disp(out_pdf)

end


function draw_box_stats(ax, x, whis_low, q25, med, q75, whis_high, box_width)

    x = double(x);
    whis_low = double(whis_low);
    q25 = double(q25);
    med = double(med);
    q75 = double(q75);
    whis_high = double(whis_high);

    half_w = box_width / 2;
    cap_w = box_width * 0.65;

    for i = 1:numel(x)

        xi = x(i);

        if any(~isfinite([whis_low(i), q25(i), med(i), q75(i), whis_high(i)]))
            continue
        end

        % Box
        rectangle(ax, ...
            "Position", [xi - half_w, q25(i), box_width, q75(i) - q25(i)], ...
            "EdgeColor", "k", ...
            "LineWidth", 1.2);

        % Median
        line(ax, ...
            [xi - half_w, xi + half_w], ...
            [med(i), med(i)], ...
            "Color", [0.95, 0.55, 0.10], ...
            "LineWidth", 1.5);

        % Lower whisker: from lower whisker to q25
        line(ax, ...
            [xi, xi], ...
            [whis_low(i), q25(i)], ...
            "Color", "k", ...
            "LineWidth", 1.2);
        
        % Upper whisker: from q75 to upper whisker
        line(ax, ...
            [xi, xi], ...
            [q75(i), whis_high(i)], ...
            "Color", "k", ...
            "LineWidth", 1.2);

        % Lower cap
        line(ax, ...
            [xi - cap_w / 2, xi + cap_w / 2], ...
            [whis_low(i), whis_low(i)], ...
            "Color", "k", ...
            "LineWidth", 1.2);

        % Upper cap
        line(ax, ...
            [xi - cap_w / 2, xi + cap_w / 2], ...
            [whis_high(i), whis_high(i)], ...
            "Color", "k", ...
            "LineWidth", 1.2);

    end

end


function apply_y_ticks(ax, split_name, feature)

    if split_name == "training"

        switch feature
            case "Biomass (g/L)"
                ylim(ax, [0.07, 2]);
                ax.YTick = [0.1, 1];
                ax.YTickLabel = ["0.1", "1"];

            case "Substrate (g/L)"
                ylim(ax, [0.06, 1.2]);
                ax.YTick = [0.1, 1];
                ax.YTickLabel = ["0.1", "1"];

            case "DO (%)"
                ylim(ax, [0.6, 11]);
                ax.YTick = [1, 10];
                ax.YTickLabel = ["1", "10"];
        end

    elseif split_name == "validation"

        switch feature
            case "Biomass (g/L)"
                ylim(ax, [0.7, 11]);
                ax.YTick = [1, 10];
                ax.YTickLabel = ["1", "10"];

            case "Substrate (g/L)"
                ylim(ax, [0.7, 11]);
                ax.YTick = [1, 10];
                ax.YTickLabel = ["1", "10"];

            case "DO (%)"
                ylim(ax, [5, 38]);
                ax.YTick = [5, 10];
                ax.YTickLabel = ["5", "10"];
        end

    else
        error("Unknown split_name: %s", split_name);
    end

end