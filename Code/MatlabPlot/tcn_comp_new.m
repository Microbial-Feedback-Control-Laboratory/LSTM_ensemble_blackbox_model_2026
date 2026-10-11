%% Reproduce LSTM vs TCN two-experiment stacked plot from CSVs
%
% Reads:
%   RedoMatlab/lstm_tcn_two_exp_curves_uw4800.csv
%   RedoMatlab/lstm_tcn_two_exp_measurements_uw4800.csv
%
% Changes:
%   1) Use 5--95% ensemble intervals for both LSTM and TCN
%   2) Panel labels: (a), (b)
%   3) Right bar panel uses RMSE, not MSE
%   4) Right bar panel uses linear x-axis
%   5) Legend uses "ensemble interval", not "band"

clear; close all; clc;

set(groot, "defaultTextInterpreter", "tex");
set(groot, "defaultAxesTickLabelInterpreter", "tex");
set(groot, "defaultLegendInterpreter", "tex");

%% Paths

ver = "v10_f1";
plotpath = "C:\Research\HybridModel\March2025\Plots";
save_plot_path = fullfile(plotpath, "BB", ver);

uw = 4800;
redo_dir = fullfile(save_plot_path, "RedoMatlab");

curves_path = fullfile(redo_dir, "lstm_tcn_two_exp_curves_uw" + string(uw) + ".csv");
measurements_path = fullfile(redo_dir, "lstm_tcn_two_exp_measurements_uw" + string(uw) + ".csv");

C = readtable(curves_path, "TextType", "string");
M = readtable(measurements_path, "TextType", "string");

disp("[INFO] Loaded:")
disp(curves_path)
disp(measurements_path)

%% Settings

target_exp_ids = ["2024_W43_A2", "2024_W49_B2"];
panel_labels = ["(a)", "(b)"];

feature_order = ["Biomass", "Substrate", "DO"];

ylabel_map = containers.Map;
ylabel_map("Biomass")   = "Biomass (g/L)";
ylabel_map("Substrate") = "Substrate (g/L)";
ylabel_map("DO")        = "DO (%)";

% Colors matched to Python style
col_true = [0.00, 0.00, 0.00];

col_lstm = [0.80, 0.10, 0.10];
col_lstm_band = [0.95, 0.55, 0.10];

col_tcn = [0.55, 0.10, 0.75];
col_pooled = [0.10, 0.65, 0.65];

%% Figure layout

fig = figure("Color", "w");

% Match side-by-side format from the reference code
try
    set_fig_size(2400, 1150);
catch
    set(fig, "Units", "centimeters");
    set(fig, "Position", [2 2 42 20]);
end

% Side-by-side experiment blocks.
% Each block has 3 stacked curve axes + 1 right RMSE axis.
left_xs = [0.08, 0.58];

curveW = 0.345;

% Keep a small fixed gap between curve panels and RMSE bar panel
bar_offset = 0.350;
barW = 0.060;

top_margin = 0.18;      % room for legend
bottom_margin = 0.08;

blockBottom = bottom_margin;
blockH = 1 - top_margin - bottom_margin;

rowGap = 0.020;
curveH = (blockH - 2 * rowGap) / 3;

block_y_offsets = [
    blockH - curveH
    blockH - 2*curveH - rowGap
    0
];

axes_all = gobjects(numel(target_exp_ids) * numel(feature_order), 1);
bar_axes = gobjects(numel(target_exp_ids), 1);

all_stats = struct();

%% Plot both experiments

for e = 1:numel(target_exp_ids)

    exp_id = target_exp_ids(e);

    leftX = left_xs(e);
    barX = leftX + bar_offset;

    axes_curves = gobjects(3, 1);

    for f = 1:numel(feature_order)

        feature = feature_order(f);
        y0 = blockBottom + block_y_offsets(f);

        ax = axes( ...
            "Parent", fig, ...
            "Position", [leftX, y0, curveW, curveH] ...
        );
        hold(ax, "on");

        axes_curves(f) = ax;
        axes_all((e-1)*3 + f) = ax;

        plot_curve_feature_from_csv( ...
            ax, C, M, exp_id, feature, ylabel_map, ...
            col_true, col_lstm, col_lstm_band, col_tcn, col_pooled ...
        );

        if f < 3
            ax.XTickLabel = [];
        else
            xlabel(ax, "Process time (h)");
        end
    end

    % Panel label
    label_x = -0.22;

    text(axes_curves(1), label_x, 1.06, panel_labels(e), ...
        "Units", "normalized", ...
        "Interpreter", "none", ...
        "FontSize", 24, ...
        "FontWeight", "bold", ...
        "FontName", "Arial", ...
        "VerticalAlignment", "top", ...
        "HorizontalAlignment", "left", ...
        "Clipping", "off");

    % Right RMSE bar axis
    ax_bar = axes( ...
        "Parent", fig, ...
        "Position", [barX, blockBottom, barW, blockH] ...
    );
    hold(ax_bar, "on");
    bar_axes(e) = ax_bar;

    stats_i = plot_rmse_bar_panel_from_csv( ...
        ax_bar, C, exp_id, feature_order, ...
        col_lstm_band, col_tcn, col_pooled ...
    );

    % Keep both RMSE panels formatted consistently.
    set(ax_bar, "XScale", "log");
    
    % Use log scale with readable ticks.
    xlim(ax_bar, [0.1, 50]);
    
    ax_bar.XTick = [1, 10];
    ax_bar.XTickLabel = ["1", "10"];
    ax_bar.XTickLabelRotation = 0;
    
    ax_bar.TickDir = "in";
    ax_bar.LineWidth = 1.5;
    ax_bar.FontSize = 12;
    ax_bar.FontName = "Arial";
    
    hx = xlabel(ax_bar, ["RMSE"; "(log scale)"]);
    hx.FontSize = 11;
    
    grid(ax_bar, "off");
    box(ax_bar, "on");

    all_stats.(matlab.lang.makeValidName(exp_id)) = stats_i;

end

%% Embedded legend

ax_leg = axes( ...
    "Parent", fig, ...
    "Position", [0.04, 0.962, 0.94, 0.035], ...
    "Visible", "off" ...
);
hold(ax_leg, "on");
axis(ax_leg, "off");
ax_leg.Box = "off";
ax_leg.XColor = "none";
ax_leg.YColor = "none";

h_ref = plot(ax_leg, NaN, NaN, ...
    "Color", col_true, ...
    "LineWidth", 1.5, ...
    "DisplayName", "Preprocessed reference data");

h_lstm_int = fill(ax_leg, NaN, NaN, col_lstm_band, ...
    "FaceAlpha", 0.35, ...
    "EdgeColor", "none", ...
    "DisplayName", "LSTM 5-95% ensemble interval");

h_lstm = plot(ax_leg, NaN, NaN, ...
    "--", ...
    "Color", col_lstm, ...
    "LineWidth", 2.0, ...
    "DisplayName", "LSTM-EMP");

h_tcn_int = fill(ax_leg, NaN, NaN, col_tcn, ...
    "FaceAlpha", 0.20, ...
    "EdgeColor", "none", ...
    "DisplayName", "TCN 5-95% ensemble interval");

h_tcn = plot(ax_leg, NaN, NaN, ...
    "-.", ...
    "Color", col_tcn, ...
    "LineWidth", 1.8, ...
    "DisplayName", "TCN-EMP");

h_pool = plot(ax_leg, NaN, NaN, ...
    "-", ...
    "Color", col_pooled, ...
    "LineWidth", 1.8, ...
    "DisplayName", "Pooled LSTM-TCN-EMP");

h_bio_meas = plot(ax_leg, NaN, NaN, ...
    "o", ...
    "Color", "none", ...
    "MarkerFaceColor", "none", ...
    "MarkerEdgeColor", col_true, ...
    "MarkerSize", 4, ...
    "LineWidth", 0.5, ...
    "DisplayName", "Biomass measurements");

h_sub_meas = plot(ax_leg, NaN, NaN, ...
    "o", ...
    "Color", "none", ...
    "MarkerFaceColor", "none", ...
    "MarkerEdgeColor", col_true, ...
    "MarkerSize", 8, ...
    "LineWidth", 1.5, ...
    "DisplayName", "Substrate measurements");

h_lstm_rmse = patch(ax_leg, NaN, NaN, col_lstm_band, ...
    "FaceAlpha", 0.65, ...
    "EdgeColor", "k", ...
    "DisplayName", "LSTM-EMP RMSE");

h_tcn_rmse = patch(ax_leg, NaN, NaN, col_tcn, ...
    "FaceAlpha", 0.65, ...
    "EdgeColor", "k", ...
    "DisplayName", "TCN-EMP RMSE");

h_pool_rmse = patch(ax_leg, NaN, NaN, col_pooled, ...
    "FaceAlpha", 0.65, ...
    "EdgeColor", "k", ...
    "DisplayName", "Pooled LSTM-TCN-EMP RMSE");

lgd = legend(ax_leg, ...
    [h_ref, h_lstm_int, h_lstm, h_tcn_int, h_tcn, h_pool, ...
     h_bio_meas, h_sub_meas, h_lstm_rmse, h_tcn_rmse, h_pool_rmse], ...
    "Location", "north", ...
    "Orientation", "horizontal", ...
    "NumColumns", 4);

lgd.Box = "off";
lgd.EdgeColor = "none";
lgd.Color = "none";

ax_leg.Box = "off";
ax_leg.Visible = "off";
ax_leg.XColor = "none";
ax_leg.YColor = "none";
ax_leg.XAxis.Visible = "off";
ax_leg.YAxis.Visible = "off";
lgd.FontSize = 14;
lgd.FontName = "Arial";

%% Final formatting

for ax = axes_all(:)'
    ax.FontName = "Arial";
    ax.FontSize = 12;
    ax.LineWidth = 1.5;
    ax.TickDir = "in";
    ax.Box = "on";
    ax.XMinorTick = "on";
    ax.YMinorTick = "on";
    ax.GridAlpha = 0.25;
end

for ax = bar_axes(:)'
    ax.FontName = "Arial";
    ax.FontSize = 12;
    ax.LineWidth = 1.5;
    ax.TickDir = "in";
    ax.Box = "on";
end

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

%% Save

out_pdf = fullfile(redo_dir, "matlab_recreated_lstm_tcn_two_exp_stacked_uw" + string(uw) + ".pdf");

exportgraphics(fig, char(out_pdf), ...
    "ContentType", "vector", ...
    "BackgroundColor", "white");

disp("[OK] Saved:")
disp(out_pdf)

disp(" ")
disp("RMSE values used in right bars:")
disp(all_stats)

%% Local functions

function plot_curve_feature_from_csv( ...
    ax, C, M, exp_id, feature, ylabel_map, ...
    col_true, col_lstm, col_lstm_band, col_tcn, col_pooled)

    d = C(C.experiment_id == exp_id & C.feature == feature, :);
    d = sortrows(d, "ProcTime_h");

    if isempty(d)
        text(ax, 0.5, 0.5, sprintf("No data\n%s\n%s", exp_id, feature), ...
            "Units", "normalized", ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "middle");
        return
    end

    t = d.ProcTime_h;

    % ----------------------------
    % Preprocessed reference
    % ----------------------------
    plot(ax, t, d.reference, ...
        "Color", col_true, ...
        "LineWidth", 1.5, ...
        "DisplayName", "Preprocessed reference data");

    % ----------------------------
    % LSTM 5--95% interval
    % ----------------------------
    fill(ax, ...
        [t; flipud(t)], ...
        [d.lstm_q05; flipud(d.lstm_q95)], ...
        col_lstm_band, ...
        "FaceAlpha", 0.35, ...
        "EdgeColor", "none", ...
        "DisplayName", "LSTM 5-95% ensemble interval");

    plot(ax, t, d.lstm_median, ...
        "--", ...
        "Color", col_lstm, ...
        "LineWidth", 2.0, ...
        "DisplayName", "LSTM-EMP");

    % ----------------------------
    % TCN 5--95% interval
    % ----------------------------
    fill(ax, ...
        [t; flipud(t)], ...
        [d.tcn_q05; flipud(d.tcn_q95)], ...
        col_tcn, ...
        "FaceAlpha", 0.20, ...
        "EdgeColor", "none", ...
        "DisplayName", "TCN 5-95% ensemble interval");

    plot(ax, t, d.tcn_median, ...
        "-.", ...
        "Color", col_tcn, ...
        "LineWidth", 1.8, ...
        "DisplayName", "TCN-EMP");

    % ----------------------------
    % Pooled median
    % ----------------------------
    plot(ax, t, d.pooled_lstm_tcn_median, ...
        "-", ...
        "Color", col_pooled, ...
        "LineWidth", 1.8, ...
        "DisplayName", "Pooled LSTM-TCN-EMP");

    % ----------------------------
    % Measurements: biomass/substrate only
    % ----------------------------
    m = M(M.experiment_id == exp_id & M.feature == feature, :);
    m = sortrows(m, "ProcTime_h");

    if ~isempty(m)
        if feature == "Biomass"
            % sc = scatter(ax, m.ProcTime_h, m.measurement, ...
            %     4, ...
            %     "MarkerEdgeColor", col_true, ...
            %     "MarkerFaceColor", "none", ...
            %     "LineWidth", 0.4, ...
            %     "DisplayName", "Biomass measurements");

            keep_every = 4;
            keep_idx = 1:keep_every:height(m.measurement);
            
            sc = scatter(ax, ...
                m.ProcTime_h(keep_idx), ...
                m.measurement(keep_idx), ...
                5, ...
                "MarkerEdgeColor", col_true, ...
                "MarkerFaceColor", "none", ...
                "LineWidth", 0.6, ...
                "DisplayName", "Biomass measurements");
            try
                sc.MarkerEdgeAlpha = 0.30;
            catch
            end

        elseif feature == "Substrate"
            scatter(ax, m.ProcTime_h, m.measurement, ...
                40, ...
                "MarkerEdgeColor", col_true, ...
                "MarkerFaceColor", "none", ...
                "LineWidth", 1.5, ...
                "DisplayName", "Substrate measurements");
        end
    end

    ylabel(ax, ylabel_map(feature));
    ax.YLabel.Units = "normalized";
    ax.YLabel.Position(1) = -0.080;

    grid(ax, "off");

    format_curve_axis(ax, exp_id, feature);

end


function stats = plot_rmse_bar_panel_from_csv( ...
    ax, C, exp_id, feature_order, col_lstm_band, col_tcn, col_pooled)

    stats = struct();

    feature_labels = ["Biomass", "Substrate", "DO"];

    model_names = ["LSTM-EMP", "TCN-EMP", "Pooled LSTM-TCN-EMP"];

    pred_cols = ["lstm_median", "tcn_median", "pooled_lstm_tcn_median"];
    
    bar_colors = {
        col_lstm_band;
        col_tcn;
        col_pooled;
    };

    % More spacing within each feature group
    y_base = (0:numel(feature_order)-1) * 1.45;
    
    bar_h = 0.14;        % narrower bars
    bar_gap = 0.22;      % center-to-center spacing between colored bars
    
    n_models = numel(pred_cols);
    offsets = ((0:n_models-1) - (n_models-1)/2) * bar_gap;

    max_rmse = 0;

    for i = 1:n_models

        pred_col = pred_cols(i);
        face_col = bar_colors{i};

        vals = nan(numel(feature_order), 1);

        for f = 1:numel(feature_order)

            feature = feature_order(f);

            d = C(C.experiment_id == exp_id & C.feature == feature, :);

            if isempty(d)
                continue
            end

            y_true = d.reference;
            y_pred = d.(pred_col);

            rmse_val = calc_rmse(y_true, y_pred);
            vals(f) = rmse_val;

            stat_name = matlab.lang.makeValidName(feature + "_" + pred_col + "_RMSE");
            stats.(stat_name) = rmse_val;

            if isfinite(rmse_val)
                max_rmse = max(max_rmse, rmse_val);
            end
        end

        valid = isfinite(vals);

        barh(ax, ...
            y_base(valid) + offsets(i), ...
            vals(valid), ...
            bar_h, ...
            "FaceColor", face_col, ...
            "FaceAlpha", 0.65, ...
            "EdgeColor", "k", ...
            "LineWidth", 0.8);

    end

    ax.YTick = y_base;
    ax.YTickLabel = [];
    ax.TickLength = [0.01, 0.01];

    ax.YDir = "reverse";
    ylim(ax, [min(y_base) - 0.55, max(y_base) + 0.55]);

    xlabel(ax, "RMSE");
    xlim(ax, [0, max_rmse * 1.15]);

    % Linear axis, no log scale.
    ax.XScale = "linear";

    % Reasonable integer-ish ticks where possible.
    if max_rmse <= 5
        ax.XTick = 0:1:ceil(max_rmse * 1.15);
    elseif max_rmse <= 15
        ax.XTick = 0:5:ceil(max_rmse * 1.15);
    else
        xmax = ceil(max_rmse * 1.15 / 10) * 10;
        ax.XTick = 0:10:xmax;
        xlim(ax, [0, xmax]);
    end

    grid(ax, "off");

end


function rmse_val = calc_rmse(y_true, y_pred)

    y_true = double(y_true);
    y_pred = double(y_pred);

    valid = isfinite(y_true) & isfinite(y_pred);

    if sum(valid) == 0
        rmse_val = NaN;
        return
    end

    err = y_true(valid) - y_pred(valid);
    rmse_val = sqrt(mean(err.^2));

end


function format_curve_axis(ax, exp_id, feature)

    % Match earlier Python behavior: W43/W49 use 2-hour x ticks and 5-unit
    % y ticks for biomass/substrate.
    if any(exp_id == ["2024_W43_A2", "2024_W49_B2"])

        if feature == "Biomass"
            ax.YTick = 0:5:25;
        elseif feature == "Substrate"
            ax.YTick = 0:5:25;
        elseif feature == "DO"
            % Keep automatic y-limits for DO unless you prefer fixed limits.
        end

        ax.XTick = 0:2:20;
    end

end