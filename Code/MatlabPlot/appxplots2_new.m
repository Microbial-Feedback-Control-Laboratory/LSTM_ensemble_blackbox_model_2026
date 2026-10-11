%% Grouped 2-experiment MIFF plot from exported CSVs
% Uses:
%   all_prediction_data_quantiles_by_exp_with_new_mechanistic.csv
%   biomass_DO_measurements.csv
%
% Figure:
%   1 x 2 experiments
%   each experiment has Biomass/Substrate/DO stacked panels
%   one shared legend on top
%
% Requires prediction CSV columns:
%   exp_id, time, time_h, variable, true_value, mechanistic_value,
%   substrate_measurement, q05, q25, q50, q75, q95,
%   new_mechanistic_value

clear; close all; clc;

set(groot, "defaultTextInterpreter", "tex");
set(groot, "defaultAxesTickLabelInterpreter", "tex");
set(groot, "defaultLegendInterpreter", "tex");

%% Paths

output_name = "grouped_b_val_2exp";  % change this each time
ver = "v10_f1";
plotpath = "C:\Research\HybridModel\March2025\Plots";
save_plot_path = fullfile(plotpath, "BB", ver);
redo_dir = fullfile(save_plot_path, "RedoMatlab");

pred_csv_path = fullfile(save_plot_path, "all_prediction_data_quantiles_by_exp_with_new_mechanistic.csv");
meas_csv_path = fullfile(save_plot_path, "biomass_DO_measurements.csv");

P = readtable(pred_csv_path, ...
    "TextType", "string", ...
    "VariableNamingRule", "preserve");

M = readtable(meas_csv_path, ...
    "TextType", "string", ...
    "VariableNamingRule", "preserve");

disp("[INFO] Loaded:")
disp(pred_csv_path)
disp(meas_csv_path)

%% Experiments to group in one figure

target_exps = [
    "2025_W21_A2"
    "2025_W21_B2"
];

% Optional: cleaner titles
title_map = containers.Map;
title_map("2025_W21_A2") = "Experiment 2025\_W21\_A2";
title_map("2025_W21_B2") = "Experiment 2025\_W21\_B2";

feature_order = ["biomass", "substrate", "DO"];

ylabel_map = containers.Map;
ylabel_map("biomass")   = "Biomass (g/L)";
ylabel_map("substrate") = "Substrate (g/L)";
ylabel_map("DO")        = "DO (%)";

%% Colors

col_true       = [0.10, 0.20, 0.50];
col_nn         = [0.80, 0.10, 0.10];
col_ode        = [0.10, 0.55, 0.20];
col_band_light = [1.00, 0.70, 0.30];
col_band_dark  = [0.95, 0.55, 0.10];

% Re-fit mechanistic model
col_new_start  = [0.35, 0.15, 0.65];

%% Figure layout

fig = figure("Color", "w");
set(fig, "Units", "centimeters");
set(fig, "Position", [2 2 30 14]);

% Outer layout: 1 row x 2 columns of experiments
left_xs = [0.075, 0.555];
block_w = 0.385;

top_margin = 0.180;     % room for legend
bottom_margin = 0.100;

n_block_rows = 1;
n_block_cols = 2;

block_h = 1 - top_margin - bottom_margin;

row_gap = 0.012;
panel_h = (block_h - 2 * row_gap) / 3;

block_ys = zeros(numel(target_exps), 1);
block_xs = zeros(numel(target_exps), 1);

for e = 1:numel(target_exps)
    col_id = mod(e - 1, n_block_cols) + 1;
    block_xs(e) = left_xs(col_id);
    block_ys(e) = bottom_margin;
end

axes_all = gobjects(numel(target_exps), 3);

%% Plot all experiments

for e = 1:numel(target_exps)

    exp_id = target_exps(e);
    block_x = block_xs(e);
    block_y = block_ys(e);

    for f = 1:numel(feature_order)

        feature = feature_order(f);

        % f = 1 top, f = 3 bottom
        ax_y = block_y + block_h - f * panel_h - (f - 1) * row_gap;

        ax = axes( ...
            "Parent", fig, ...
            "Position", [block_x, ax_y, block_w, panel_h] ...
        );
        hold(ax, "on");

        axes_all(e, f) = ax;

        plot_feature_from_csv(ax, P, M, exp_id, feature, ...
            ylabel_map, col_true, col_nn, col_ode, col_new_start, ...
            col_band_light, col_band_dark);

        if f == 1
            if isKey(title_map, exp_id)
                title(ax, title_map(exp_id), "FontWeight", "normal", "FontSize", 14);
            else
                title(ax, "Experiment " + exp_id, "FontWeight", "normal", "FontSize", 14);
            end
        end

        if f < numel(feature_order)
            ax.XTickLabel = [];
        else
            xlabel(ax, "Process Time (h)");
        end
    end
end

%% Shared formatting

for ax = axes_all(:)'

    ax.FontName = "Arial";
    ax.FontSize = 11;
    ax.LineWidth = 1.1;
    ax.TickDir = "in";
    ax.Box = "on";

    ax.XMinorTick = "on";
    ax.YMinorTick = "on";

    grid(ax, "on");
    ax.GridAlpha = 0.20;

    ax.YLabel.Units = "normalized";
    ax.YLabel.Position(1) = -0.105;
end

%% One shared legend on top

ax_leg = axes( ...
    "Parent", fig, ...
    "Position", [0.08, 0.900, 0.84, 0.055], ...
    "Visible", "off" ...
);
hold(ax_leg, "on");
axis(ax_leg, "off");

ax_leg.Box = "off";
ax_leg.XColor = "none";
ax_leg.YColor = "none";
ax_leg.XAxis.Visible = "off";
ax_leg.YAxis.Visible = "off";

h_band95 = fill(ax_leg, NaN, NaN, col_band_light, ...
    "FaceAlpha", 0.35, ...
    "EdgeColor", "none", ...
    "DisplayName", "LSTM 5-95% ensemble interval");

h_band75 = fill(ax_leg, NaN, NaN, col_band_dark, ...
    "FaceAlpha", 0.45, ...
    "EdgeColor", "none", ...
    "DisplayName", "LSTM 25-75% ensemble interval");

h_ref = plot(ax_leg, NaN, NaN, ...
    "Color", col_true, ...
    "LineWidth", 1.5, ...
    "DisplayName", "Preprocessed reference data");

h_lstm = plot(ax_leg, NaN, NaN, ...
    "--", ...
    "Color", col_nn, ...
    "LineWidth", 1.4, ...
    "DisplayName", "LSTM-EMP");

h_bio_meas = plot(ax_leg, NaN, NaN, ...
    ".", ...
    "Color", col_true, ...
    "MarkerSize", 8, ...
    "DisplayName", "Biomass measurements");

h_sub_meas = plot(ax_leg, NaN, NaN, ...
    "o", ...
    "Color", "none", ...
    "MarkerFaceColor", "none", ...
    "MarkerEdgeColor", col_true, ...
    "MarkerSize", 5, ...
    "DisplayName", "Substrate measurements");

h_mech = plot(ax_leg, NaN, NaN, ...
    "--", ...
    "Color", col_ode, ...
    "LineWidth", 1.2, ...
    "DisplayName", "Mech-Lit model");

h_new_mech = plot(ax_leg, NaN, NaN, ...
    "-.", ...
    "Color", col_new_start, ...
    "LineWidth", 1.2, ...
    "DisplayName", "Mech-Refit model");

lgd = legend(ax_leg, ...
    [h_band95, h_band75, h_ref, h_lstm, h_bio_meas, h_sub_meas, h_mech, h_new_mech], ...
    "Location", "north", ...
    "Orientation", "horizontal", ...
    "NumColumns", 4);

lgd.Box = "off";
lgd.FontSize = 11;
lgd.FontName = "Arial";

%% Remove MATLAB toolbar icons

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

%% Save figure

out_pdf = fullfile(redo_dir, output_name + ".pdf");

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

exportgraphics(fig, char(out_pdf), ...
    "ContentType", "image", ...
    "Resolution", 300, ...
    "BackgroundColor", "white");

disp("[OK] Saved grouped plot:")
disp(out_pdf)

%% Local functions

function plot_feature_from_csv(ax, P, M, exp_id, feature, ...
    ylabel_map, col_true, col_nn, col_ode, col_new_start, ...
    col_band_light, col_band_dark)

    d = P(P.exp_id == exp_id & P.variable == feature, :);
    d = sortrows(d, "time");

    if isempty(d)
        text(ax, 0.5, 0.5, "No data: " + exp_id + newline + feature, ...
            "Units", "normalized", ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "middle", ...
            "FontSize", 10);
        ylabel(ax, ylabel_map(feature));
        return
    end

    % Match Python plotting logic: shift time so prediction axis starts at 0.
    t0 = min(d.time);

    if t0 > 0
        t_h = (d.time - t0) / 3600.0;
    else
        t_h = d.time / 3600.0;
    end

    xmax_data = max(t_h, [], "omitnan") + 0.5;

    % 5--95% interval
    fill(ax, ...
        [t_h; flipud(t_h)], ...
        [d.q05; flipud(d.q95)], ...
        col_band_light, ...
        "FaceAlpha", 0.35, ...
        "EdgeColor", "none");

    % 25--75% interval
    fill(ax, ...
        [t_h; flipud(t_h)], ...
        [d.q25; flipud(d.q75)], ...
        col_band_dark, ...
        "FaceAlpha", 0.45, ...
        "EdgeColor", "none");

    % Reference
    plot(ax, t_h, d.true_value, ...
        "Color", col_true, ...
        "LineWidth", 1.5);

    % LSTM median
    plot(ax, t_h, d.q50, ...
        "--", ...
        "Color", col_nn, ...
        "LineWidth", 1.3);

    % Mechanistic model, if available
    if ismember("mechanistic_value", P.Properties.VariableNames) && ...
            ismember("mechanistic_value", d.Properties.VariableNames)

        mech = d.mechanistic_value;
        valid_mech = isfinite(mech);

        if sum(valid_mech) > 1
            plot(ax, t_h(valid_mech), mech(valid_mech), ...
                "--", ...
                "Color", col_ode, ...
                "LineWidth", 1.1);
        end
    end

    % Re-fit mechanistic model, if available
    if ismember("new_mechanistic_value", P.Properties.VariableNames) && ...
            ismember("new_mechanistic_value", d.Properties.VariableNames)

        new_mech = d.new_mechanistic_value;
        valid_new_mech = isfinite(new_mech);

        if sum(valid_new_mech) > 1
            plot(ax, t_h(valid_new_mech), new_mech(valid_new_mech), ...
                "-.", ...
                "Color", col_new_start, ...
                "LineWidth", 1.1);
        end
    end

    % Measurements
    if feature == "biomass"

        bio_col = get_first_existing_col(M, ["biomass measurements", "biomass_measurements"]);

        m = M(M.exp_id == exp_id & isfinite(M.(bio_col)), :);
        m = sortrows(m, "time");

        if ~isempty(m)
            if t0 > 0
                mt_h = (m.time - t0) / 3600.0;
            else
                mt_h = m.time / 3600.0;
            end

            % Downsample dense online measurements for readability
            keep_every = 5;
            keep_idx = 1:keep_every:height(m);

            sc = scatter(ax, ...
                mt_h(keep_idx), ...
                m.(bio_col)(keep_idx), ...
                3, ...
                "MarkerEdgeColor", col_true, ...
                "MarkerFaceColor", "none", ...
                "LineWidth", 0.5);

            try
                sc.MarkerEdgeAlpha = 0.4;
            catch
            end
        end

    elseif feature == "substrate"

        % Substrate measurements are stored in P as snapped values.
        m = d(isfinite(d.substrate_measurement), :);

        if ~isempty(m)
            if t0 > 0
                mt_h = (m.time - t0) / 3600.0;
            else
                mt_h = m.time / 3600.0;
            end

            scatter(ax, mt_h, m.substrate_measurement, ...
                12, ...
                "MarkerEdgeColor", col_true, ...
                "MarkerFaceColor", "none", ...
                "LineWidth", 0.7);
        end

    elseif feature == "DO"

        do_col = get_first_existing_col(M, ["DO measurements", "DO_measurements"]);

        m = M(M.exp_id == exp_id & isfinite(M.(do_col)), :);
        m = sortrows(m, "time");

        if ~isempty(m)
            if t0 > 0
                mt_h = (m.time - t0) / 3600.0;
            else
                mt_h = m.time / 3600.0;
            end

            % Downsample dense online measurements for readability
            keep_every = 2;
            keep_idx = 1:keep_every:height(m);

            sc = scatter(ax, ...
                mt_h(keep_idx), ...
                m.(do_col)(keep_idx), ...
                3, ...
                "MarkerEdgeColor", col_true, ...
                "MarkerFaceColor", "none", ...
                "LineWidth", 0.5);

            try
                sc.MarkerEdgeAlpha = 0.24;
            catch
            end
        end
    end

    ylabel(ax, ylabel_map(feature));

    format_axis_by_feature(ax, exp_id, feature, xmax_data);

end


function format_axis_by_feature(ax, exp_id, feature, xmax_data)

    % Generic x limits: max plotted time + 0.5 h
    xlim(ax, [0, xmax_data]);

    xtop = floor(xmax_data / 2) * 2;
    ax.XTick = 0:2:xtop;

    % ------------------------------------------------------------
    % Automatic y-limit from all plotted data in this axis
    % This includes reference, LSTM, mechanistic, re-fit mechanistic,
    % uncertainty bands, and measurements.
    % ------------------------------------------------------------
    y_all = [];

    objs = findobj(ax, "-property", "YData");

    for ii = 1:numel(objs)
        y = objs(ii).YData;
        y = double(y(:));
        y = y(isfinite(y));
        y_all = [y_all; y];
    end

    if isempty(y_all)
        y_min = 0;
        y_max = 1;
    else
        y_min = min(y_all);
        y_max = max(y_all);
    end

    % Usually these variables should not go below zero.
    y_min = min(0, y_min);

    if y_max <= y_min
        y_max = y_min + 1;
    end

    y_pad = 0.08 * (y_max - y_min);

    y_low = max(0, y_min - y_pad);
    y_high = y_max + y_pad;

    % Feature-specific minimum upper limits, so normal plots do not shrink too much.
    if feature == "biomass"
        y_high = max(y_high, 22);

        tick_step = choose_tick_step(y_high);
        y_high_tick = ceil(y_high / tick_step) * tick_step;

        ylim(ax, [0, y_high_tick]);
        ax.YTick = 0:tick_step:y_high_tick;

    elseif feature == "substrate"
        y_high = max(y_high, 22);

        tick_step = choose_tick_step(y_high);
        y_high_tick = ceil(y_high / tick_step) * tick_step;

        ylim(ax, [0, y_high_tick]);
        ax.YTick = 0:tick_step:y_high_tick;

    elseif feature == "DO"
        y_high = max(y_high, 100);

        tick_step = choose_tick_step(y_high);
        y_high_tick = ceil(y_high / tick_step) * tick_step;

        ylim(ax, [0, y_high_tick]);
        ax.YTick = 0:tick_step:y_high_tick;
    end

end

function tick_step = choose_tick_step(y_high)

    if y_high <= 10
        tick_step = 2;
    elseif y_high <= 25
        tick_step = 5;
    elseif y_high <= 60
        tick_step = 10;
    elseif y_high <= 120
        tick_step = 20;
    elseif y_high <= 250
        tick_step = 50;
    elseif y_high <= 600
        tick_step = 100;
    else
        tick_step = 200;
    end

end


function col = get_first_existing_col(T, candidates)

    names = string(T.Properties.VariableNames);

    for i = 1:numel(candidates)
        c = string(candidates(i));

        if any(names == c)
            col = c;
            return
        end
    end

    error("None of these columns were found: %s", strjoin(candidates, ", "));

end