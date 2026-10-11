%% Reproduce W23 controlled/unregulated DO A-B-C plot from CSVs
%
% Reads:
%   w23_do_curves_with_new_mech_and_mid_uw4800.csv
%   w23_do_measurements_uw4800.csv
%   uncertainty_summary_validation.csv
%
% Plot:
%   (a) Controlled DO curves
%   (b) Unregulated DO curves
%   (c) RMSE bar plots
%
% Features:
%   - LSTM 5--95% ensemble band
%   - CCPI = conformal-calibrated 90% prediction interval
%   - Preprocessed reference data
%   - LSTM-EMP median
%   - Old mechanistic model for Biomass/Substrate
%   - New mechanistic model from start
%   - LSTM-EMP median from mid-start file
%   - New mechanistic model from mid-start
%   - Vertical mid-start reference line
%   - Measurements
%   - RMSE bars calculated from curve CSV

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

curves_path = fullfile(redo_dir, "w23_do_curves_with_new_mech_and_mid_uw" + string(uw) + ".csv");
measurements_path = fullfile(redo_dir, "w23_do_measurements_uw" + string(uw) + ".csv");
validation_loo_path = fullfile(redo_dir, ...
        "validation_logo_fold_results.csv");

V = readtable(validation_loo_path, ...
    "TextType", "string");

C = readtable(curves_path, "TextType", "string");
M = readtable(measurements_path, "TextType", "string");

disp("[INFO] Loaded:")
disp(curves_path)
disp(measurements_path)

%% Settings

exp_A = "2025_W23_A2";
exp_B = "2025_W23_B2";

target_exps = [exp_A, exp_B];
condition_labels = ["Controlled DO", "Unregulated DO"];

feature_order = ["Biomass", "Substrate", "DO"];

ylabel_map = containers.Map;
ylabel_map("Biomass")   = "Biomass (g/L)";
ylabel_map("Substrate") = "Substrate (g/L)";
ylabel_map("DO")        = "DO (%)";

summary_feature_map = containers.Map;
summary_feature_map("Biomass")   = "biomass";
summary_feature_map("Substrate") = "substrate";
summary_feature_map("DO")        = "DO";

% Colors matched to Python
col_true       = [0.00, 0.00, 0.00];
col_nn         = [0.80, 0.10, 0.10];
col_ode        = [0.10, 0.55, 0.20];
col_band_light = [1.00, 0.70, 0.30];
col_ccpi       = [0.75, 0.75, 0.75];

col_nn_bar = [0.95, 0.55, 0.10];
col_mn_bar = [0.10, 0.55, 0.20];

% Added colors
col_new_start = [0.35, 0.15, 0.65];
col_lstm_mid  = [0.55, 0.00, 0.00];
col_new_mid   = [0.00, 0.45, 0.70];
col_mid_line  = [0.25, 0.25, 0.25];

%% Calculate RMSE summary from curve CSV

rmse_rows = table( ...
    strings(0,1), strings(0,1), strings(0,1), ...
    zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    'VariableNames', { ...
        'experiment_id', ...
        'condition', ...
        'feature', ...
        'rmse_lstm', ...
        'rmse_mech', ...
        'rmse_new_full', ...
        'rmse_lstm_mid', ...
        'rmse_new_mid', ...
        'mid_start_h' ...
    } ...
);

for e = 1:numel(target_exps)

    exp_id = target_exps(e);
    cond = condition_labels(e);

    for f = 1:numel(feature_order)

        feature = feature_order(f);

        d = C(C.experiment_id == exp_id & C.feature == feature, :);
        d = sortrows(d, "ProcTime_h");

        if isempty(d)
            continue
        end

        mid_start_h = get_mid_start_h(d);

        if isfinite(mid_start_h)
            mid_mask = d.ProcTime_h >= mid_start_h;
        else
            mid_mask = isfinite(d.placeholder_mid_median) | isfinite(d.new_mechanistic_mid_start);
        end

        rmse_lstm = calc_rmse(d.reference, d.pred_median);
        rmse_mech = calc_rmse(d.reference, d.mechanistic_model);
        rmse_new_full = calc_rmse(d.reference, d.new_mechanistic_full_start);
        rmse_lstm_mid = calc_rmse(d.reference(mid_mask), d.pred_median(mid_mask));
        rmse_new_mid = calc_rmse(d.reference(mid_mask), d.new_mechanistic_mid_start(mid_mask));

        rmse_rows = [rmse_rows; table( ...
            exp_id, cond, feature, ...
            rmse_lstm, rmse_mech, rmse_new_full, rmse_lstm_mid, rmse_new_mid, mid_start_h, ...
            'VariableNames', rmse_rows.Properties.VariableNames ...
        )];
    end
end

disp(" ")
disp("============================================================")
disp("RMSE summary calculated from curve CSV")
disp("============================================================")
disp(rmse_rows)

%% Figure layout

fig = figure("Color", "w");
set(fig, "Units", "centimeters");
set(fig, "Position", [2 2 42 20]);

left_x  = 0.070;
right_x = 0.445;

% Widen A and B, and move them slightly right
curve_w = 0.340;

% Move panel C right a little
bar_x = 0.820;
bar_w = 0.110;

% Keep current vertical layout
top_y = 0.635;
mid_y = 0.385;
bot_y = 0.115;
curve_h = 0.210;

% No bottom panel now.
% RMSE bar plots use the same y positions as the curve rows.

axes_A = gobjects(3,1);
axes_B = gobjects(3,1);
axes_C = gobjects(3,1);

local_rmse_lstm_A = nan(3,1);
local_rmse_mech_A = nan(3,1);
local_rmse_lstm_B = nan(3,1);
local_rmse_mech_B = nan(3,1);

y_positions = [top_y, mid_y, bot_y];

%% Plot curve panels A and B

for c = 1:2

    exp_id = target_exps(c);

    if c == 1
        x0 = left_x;
        show_ylabels = true;
        axes_this = axes_A;
    else
        x0 = right_x;
        show_ylabels = false;
        axes_this = axes_B;
    end

    for r = 1:3

        feature = feature_order(r);

        ax = axes( ...
            "Parent", fig, ...
            "Position", [x0, y_positions(r), curve_w, curve_h] ...
        );
        hold(ax, "on");

        plot_curve_axis_from_csv( ...
            ax, C, M, V, ...
            exp_id, feature, ...
            summary_feature_map, ...
            col_true, col_nn, col_ode, col_band_light, col_ccpi, ...
            col_new_start, col_lstm_mid, col_new_mid, col_mid_line, ...
            col_nn_bar, ...
            show_ylabels, ylabel_map ...
        );

        if r < 3
            ax.XTickLabel = [];
        else
            xlabel(ax, "Process Time (h)");
        end

        if c == 1
            axes_A(r) = ax;
        else
            axes_B(r) = ax;
        end
    end

    % Panel labels
    if c == 1
        panel_label = "(a)";
        label_x = -0.18;
    else
        panel_label = "(b)";
        label_x = -0.09;
    end

    text(get_axis_handle(c, axes_A, axes_B, 1), label_x, 1.02, panel_label, ...
        "Units", "normalized", ...
        "Interpreter", "none", ...
        "FontSize", 28, ...
        "FontWeight", "bold", ...
        "FontName", "Arial", ...
        "VerticalAlignment", "top", ...
        "HorizontalAlignment", "left", ...
        "Clipping", "off");
end

% Right-column y ticks visible but labels hidden
for r = 1:3
    axes_B(r).YTickLabel = [];
    axes_B(r).YLabel.String = "";
end

%% Collect local RMSE values for inset bars

for r = 1:numel(feature_order)

    feature = feature_order(r);

    rowA = rmse_rows( ...
        rmse_rows.experiment_id == exp_A & ...
        rmse_rows.feature == feature, : ...
    );

    rowB = rmse_rows( ...
        rmse_rows.experiment_id == exp_B & ...
        rmse_rows.feature == feature, : ...
    );

    if ~isempty(rowA)
        local_rmse_lstm_A(r) = rowA.rmse_lstm_mid(1);
        local_rmse_mech_A(r) = rowA.rmse_new_mid(1);
    end

    if ~isempty(rowB)
        local_rmse_lstm_B(r) = rowB.rmse_lstm_mid(1);
        local_rmse_mech_B(r) = rowB.rmse_new_mid(1);
    end
end

%% Plot right-side RMSE panels: panel C
% Three vertically aligned bar plots, one per feature.
% Shared x-axis: only bottom RMSE panel shows x tick labels.

for f = 1:numel(feature_order)

    feature = feature_order(f);

    ax = axes( ...
        "Parent", fig, ...
        "Position", [bar_x, y_positions(f), bar_w, curve_h] ...
    );
    hold(ax, "on");

    axes_C(f) = ax;

    show_xticklabels = (f == numel(feature_order));

    plot_rmse_bar_axis_rightside( ...
        ax, rmse_rows, feature, condition_labels, ...
        col_nn_bar, col_mn_bar, col_new_start, ...
        show_xticklabels ...
    );

end

% Panel label C
text(axes_C(1), -0.28, 1.02, "(c)", ...
    "Units", "normalized", ...
    "Interpreter", "none", ...
    "FontSize", 28, ...
    "FontWeight", "bold", ...
    "FontName", "Arial", ...
    "VerticalAlignment", "top", ...
    "HorizontalAlignment", "left", ...
    "Clipping", "off");


%% Overlay local RMSE inset bars on upper curve panels
% Created after all main and bottom axes, so they stay visible.

for r = 1:numel(feature_order)

    add_local_rmse_inset_visible( ...
        axes_A(r), ...
        feature_order(r), ...
        local_rmse_lstm_A(r), ...
        local_rmse_mech_A(r), ...
        col_nn_bar, ...
        col_new_mid ...
    );

    add_local_rmse_inset_visible( ...
        axes_B(r), ...
        feature_order(r), ...
        local_rmse_lstm_B(r), ...
        local_rmse_mech_B(r), ...
        col_nn_bar, ...
        col_new_mid ...
    );

end

%% Top legend for curve panels

ax_leg_top = axes( ...
    "Parent", fig, ...
    "Position", [0.04, 0.935, 0.94, 0.055], ...
    "Visible", "off" ...
);
hold(ax_leg_top, "on");
axis(ax_leg_top, "off");
ax_leg_top.Box = "off";
ax_leg_top.XColor = "none";
ax_leg_top.YColor = "none";
ax_leg_top.XAxis.Visible = "off";
ax_leg_top.YAxis.Visible = "off";

h_band = fill(ax_leg_top, NaN, NaN, col_band_light, ...
    "FaceAlpha", 0.35, ...
    "EdgeColor", "none", ...
    "DisplayName", "5-95% LSTM ensemble interval");

h_ref = plot(ax_leg_top, NaN, NaN, ...
    "Color", col_true, ...
    "LineWidth", 1.3, ...
    "DisplayName", "Preprocessed reference data");

h_lstm = plot(ax_leg_top, NaN, NaN, ...
    "--", ...
    "Color", col_nn, ...
    "LineWidth", 1.3, ...
    "DisplayName", "LSTM-EMP");

h_ccpi = fill(ax_leg_top, NaN, NaN, col_ccpi, ...
    "FaceAlpha", 0.28, ...
    "EdgeColor", "none", ...
    "DisplayName", "Conformal-calibrated 90% prediction intervals");

h_mech = plot(ax_leg_top, NaN, NaN, ...
    "--", ...
    "Color", col_ode, ...
    "LineWidth", 1.3, ...
    "DisplayName", "Mech-Lit model");

h_new_start = plot(ax_leg_top, NaN, NaN, ...
    "-.", ...
    "Color", col_new_start, ...
    "LineWidth", 1.3, ...
    "DisplayName", "Mech-Refit model");

h_mid_line = plot(ax_leg_top, NaN, NaN, ...
    "--", ...
    "Color", [0.00, 0.00, 0.00], ...
    "LineWidth", 1.4, ...
    "DisplayName", "Cutoff time");

h_new_mid = plot(ax_leg_top, NaN, NaN, ...
    ":", ...
    "Color", col_new_mid, ...
    "LineWidth", 1.6, ...
    "DisplayName", "Mech-Refit model, post-cutoff");

h_meas = plot(ax_leg_top, NaN, NaN, ...
    "o", ...
    "Color", "none", ...
    "MarkerFaceColor", "none", ...
    "MarkerEdgeColor", col_true, ...
    "MarkerSize", 6, ...
    "DisplayName", "Measurements");

h_bar_lstm_local = bar(ax_leg_top, NaN, NaN, ...
    "FaceColor", col_nn_bar, ...
    "FaceAlpha", 0.80, ...
    "EdgeColor", "k", ...
    "LineWidth", 0.6, ...
    "DisplayName", "LSTM-EMP RMSE, post-cutoff");

h_bar_refit_local = bar(ax_leg_top, NaN, NaN, ...
    "FaceColor", col_new_mid, ...
    "FaceAlpha", 0.80, ...
    "EdgeColor", "k", ...
    "LineWidth", 0.6, ...
    "DisplayName", "Mech-Refit model RMSE, post-cutoff");


h_mn_bar = bar(ax_leg_top, NaN, NaN, ...
    "FaceColor", col_mn_bar, ...
    "FaceAlpha", 0.90, ...
    "EdgeColor", "none", ...
    "DisplayName", "Mech-Lit Model");

h_nn_bar = bar(ax_leg_top, NaN, NaN, ...
    "FaceColor", col_nn_bar, ...
    "FaceAlpha", 0.80, ...
    "EdgeColor", "none", ...
    "DisplayName", "LSTM-EMP");

h_new_full_bar = bar(ax_leg_top, NaN, NaN, ...
    "FaceColor", col_new_start, ...
    "FaceAlpha", 0.80, ...
    "EdgeColor", "none", ...
    "DisplayName", "Mech-Refit model");

lgd_top = legend(ax_leg_top, ...
    [h_band, h_ref, h_lstm, h_ccpi, h_mech, h_new_start, h_mid_line, h_new_mid, h_meas, h_bar_lstm_local, h_bar_refit_local, h_mn_bar, h_nn_bar, h_new_full_bar], ...
    "Location", "north", ...
    "Orientation", "horizontal", ...
    "NumColumns", 4);

lgd_top.Box = "off";
lgd_top.FontSize = 14;
lgd_top.FontName = "Arial";

%% Remove toolbar icons

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

out_pdf = fullfile(redo_dir, "matlab_recreated_combined_ABC_W23_DO_with_new_mech_mid__loo_uw" + string(uw) + ".pdf");

exportgraphics(fig, char(out_pdf), ...
    "ContentType", "image", ...
    "Resolution", 300, ...
    "BackgroundColor", "white");

disp("[OK] Saved:")
disp(out_pdf)

%% Local functions

function ax = get_axis_handle(c, axes_A, axes_B, idx)
    if c == 1
        ax = axes_A(idx);
    else
        ax = axes_B(idx);
    end
end


function plot_curve_axis_from_csv( ...
    ax, C, M, V, exp_id, feature, summary_feature_map, ...
    col_true, col_nn, col_ode, col_band_light, col_ccpi, ...
    col_new_start, col_lstm_mid, col_new_mid, col_mid_line, ...
    col_nn_bar, ...
    show_ylabels, ylabel_map)

    d = C(C.experiment_id == exp_id & C.feature == feature, :);
    d = sortrows(d, "ProcTime_h");

    if isempty(d)
        text(ax, 0.5, 0.5, sprintf("No data\n%s\n%s", exp_id, feature), ...
            "Units", "normalized", ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "middle");
        return
    end

    qhat = get_loeo_qhat( ...
        V, exp_id, feature, summary_feature_map);

    t = d.ProcTime_h;
    q05 = d.pred_q05;
    q50 = d.pred_median;
    q95 = d.pred_q95;

    ccpi_lower = q05 - qhat;
    ccpi_upper = q95 + qhat;

    reference = d.reference;
    mechanistic = d.mechanistic_model;

    new_full = d.new_mechanistic_full_start;
    lstm_mid = d.placeholder_mid_median;
    new_mid = d.new_mechanistic_mid_start;

    mid_start_h = get_mid_start_h(d);

    if isfinite(mid_start_h)
        mid_mask = t >= mid_start_h;
    else
        mid_mask = isfinite(lstm_mid) | isfinite(new_mid);
    end

    % LSTM raw 5--95% interval
    fill(ax, ...
        [t; flipud(t)], ...
        [q05; flipud(q95)], ...
        col_band_light, ...
        "FaceAlpha", 0.35, ...
        "EdgeColor", "none", ...
        "DisplayName", "5-95% LSTM ensemble interval");

    % CCPI interval
    if isfinite(qhat)
        fill(ax, ...
            [t; flipud(t)], ...
            [ccpi_lower; flipud(ccpi_upper)], ...
            col_ccpi, ...
            "FaceAlpha", 0.28, ...
            "EdgeColor", "none", ...
            "DisplayName", "Conformal-calibrated 90% prediction intervals");
    end

    % Old mechanistic model for biomass/substrate only
    mech_valid = isfinite(mechanistic);

    if sum(mech_valid) > 1 && feature ~= "DO"
        plot(ax, t(mech_valid), mechanistic(mech_valid), ...
            "--", ...
            "Color", col_ode, ...
            "LineWidth", 1.3, ...
            "DisplayName", "Old mechanistic model");
    end

    % New mechanistic model from start
    new_full_valid = isfinite(new_full);

    if sum(new_full_valid) > 1
        plot(ax, t(new_full_valid), new_full(new_full_valid), ...
            "-.", ...
            "Color", col_new_start, ...
            "LineWidth", 1.3, ...
            "DisplayName", "New mechanistic, start");
    end

    % Local re-fit cutoff line
    if isfinite(mid_start_h)
        h_cut = xline(ax, mid_start_h, ...
            "--", ...
            "Color", [0.00, 0.00, 0.00], ...
            "LineWidth", 1.4, ...
            "Alpha", 0.85, ...
            "DisplayName", "Local re-fit cutoff time");
    
        try
            h_cut.LineStyle = "--";
        catch
        end
    end

    % Preprocessed data
    plot(ax, t, reference, ...
        "Color", col_true, ...
        "LineWidth", 1.3, ...
        "DisplayName", "Preprocessed reference data");

    % LSTM median
    plot(ax, t, q50, ...
        "--", ...
        "Color", col_nn, ...
        "LineWidth", 1.3, ...
        "DisplayName", "LSTM-EMP");


    % New mechanistic model from mid-start
    new_mid_valid = mid_mask & isfinite(new_mid);

    if sum(new_mid_valid) > 1
        plot(ax, t(new_mid_valid), new_mid(new_mid_valid), ...
            ":", ...
            "Color", col_new_mid, ...
            "LineWidth", 1.6, ...
            "DisplayName", "New mechanistic, mid");
    end

    % Measurements
    m = M(M.experiment_id == exp_id & M.feature == feature, :);
    m = sortrows(m, "ProcTime_h");

    if ~isempty(m)
        if feature == "Substrate"
            scatter(ax, m.ProcTime_h, m.measurement, ...
                40, ...
                "MarkerEdgeColor", col_true, ...
                "MarkerFaceColor", "none", ...
                "LineWidth", 0.8, ...
                "DisplayName", "Measurements");

        elseif feature == "Biomass"
            sc = scatter(ax, m.ProcTime_h, m.measurement, ...
                4, ...
                "MarkerEdgeColor", col_true, ...
                "MarkerFaceColor", "none", ...
                "LineWidth", 0.4, ...
                "DisplayName", "Measurements");
            try
                sc.MarkerEdgeAlpha = 0.25;
            catch
            end

        elseif feature == "DO"
            sc = scatter(ax, m.ProcTime_h, m.measurement, ...
                5, ...
                "MarkerEdgeColor", col_true, ...
                "MarkerFaceColor", "none", ...
                "LineWidth", 0.4, ...
                "DisplayName", "Measurements");
            try
                sc.MarkerEdgeAlpha = 0.25;
            catch
            end
        end
    end

    if show_ylabels
        ylabel(ax, ylabel_map(feature));
    else
        ylabel(ax, "");
        ax.YTickLabel = [];
    end

    grid(ax, "off");

    ax.TickDir = "in";
    ax.LineWidth = 1.5;
    ax.FontSize = 14;
    ax.FontName = "Arial";
    ax.XMinorTick = "on";
    ax.YMinorTick = "on";

    format_curve_axis(ax, feature);

end

function qhat = get_loeo_qhat( ...
    V, exp_id, feature, summary_feature_map)

    % Convert the curve-file feature label to the calibration-file label.
    calibration_feature = summary_feature_map(feature);

    % Each row is identified jointly by held-out experiment and feature.
    row_mask = ...
        V.held_out_experiment == exp_id & ...
        V.feature == calibration_feature;

    row = V(row_mask, :);

    if isempty(row)

        error( ...
            ['No LOEO calibration row found for held-out experiment ' ...
             '"%s" and feature "%s".'], ...
            exp_id, calibration_feature);

    elseif height(row) > 1

        error( ...
            ['Expected one LOEO calibration row, but found %d rows ' ...
             'for held-out experiment "%s" and feature "%s".'], ...
            height(row), exp_id, calibration_feature);

    elseif ~isfinite(row.qhat_logo(1))

        error( ...
            ['The LOEO qhat is not finite for held-out experiment ' ...
             '"%s" and feature "%s".'], ...
            exp_id, calibration_feature);

    end

    qhat = row.qhat_logo(1);

    fprintf( ...
        'LOEO qhat: experiment = %s, feature = %s, qhat = %.6g\n', ...
        char(exp_id), char(calibration_feature), qhat);

end

function plot_rmse_bar_axis( ...
    ax, rmse_rows, feature, condition_labels, ylabel_map, ...
    col_nn_bar, col_mn_bar, col_new_start, col_lstm_mid, col_new_mid)

    d = rmse_rows(rmse_rows.feature == feature, :);

    rmse_lstm = nan(1, numel(condition_labels));
    rmse_mech = nan(1, numel(condition_labels));
    rmse_new_full = nan(1, numel(condition_labels));
    rmse_lstm_mid = nan(1, numel(condition_labels));
    rmse_new_mid = nan(1, numel(condition_labels));

    for i = 1:numel(condition_labels)
        row = d(d.condition == condition_labels(i), :);
        if ~isempty(row)
            rmse_lstm(i) = row.rmse_lstm(1);
            rmse_mech(i) = row.rmse_mech(1);
            rmse_new_full(i) = row.rmse_new_full(1);
            rmse_lstm_mid(i) = row.rmse_lstm_mid(1);
            rmse_new_mid(i) = row.rmse_new_mid(1);
        end
    end

    bar_w = 0.1;
    gap_group = 0.1;
    
    x_centers = (0:numel(condition_labels)-1) * (3 * bar_w + gap_group);
    offsets = (-1:1) * (bar_w * 1.10);
    
    bar(ax, x_centers + offsets(1), rmse_mech, bar_w, ...
        "FaceColor", col_mn_bar, ...
        "FaceAlpha", 0.90, ...
        "EdgeColor", "none", ...
        "DisplayName", "Old mechanistic");
    
    bar(ax, x_centers + offsets(2), rmse_lstm, bar_w, ...
        "FaceColor", col_nn_bar, ...
        "FaceAlpha", 0.80, ...
        "EdgeColor", "none", ...
        "DisplayName", "LSTM full");
    
    bar(ax, x_centers + offsets(3), rmse_new_full, bar_w, ...
        "FaceColor", col_new_start, ...
        "FaceAlpha", 0.80, ...
        "EdgeColor", "none", ...
        "DisplayName", "New mechanistic start");

    title(ax, ylabel_map(feature), "FontWeight", "normal");

    if feature == "Biomass"
        ylabel(ax, "RMSE");
    else
        ylabel(ax, "");
    end

    ax.XTick = x_centers;
    ax.XTickLabel = condition_labels;

    ax.TickDir = "in";
    ax.LineWidth = 1.5;
    ax.FontSize = 14;
    ax.FontName = "Arial";

    grid(ax, "on");
    ax.GridAlpha = 0.20;
    ax.XGrid = "off";
    ax.YGrid = "on";

    ax.XAxis.FontSize = 14;
    ax.XAxis.TickLabelRotation = 0;

    if feature == "Substrate"
        ytickformat(ax, "%.1f");
    end

    ax.XLim = [min(x_centers) - 0.28, max(x_centers) + 0.28];

end


function format_curve_axis(ax, feature)

    if feature == "Biomass"
        ylim(ax, [0, 18]);
        ax.YTick = 0:5:20;
        xlim(ax, [0, 9]);
        ax.XTick = 0:2:10;

    elseif feature == "Substrate"
        ylim(ax, [0, 22]);
        ax.YTick = 0:5:25;
        xlim(ax, [0, 9]);
        ax.XTick = 0:2:10;

    elseif feature == "DO"
        ylim(ax, [15, 100]);
        ax.YTick = 15:15:100;
        xlim(ax, [0, 9]);
        ax.XTick = 0:2:10;
    end

end


function mid_start_h = get_mid_start_h(d)

    mid_start_h = first_finite_x(d.ProcTime_h, d.new_mechanistic_mid_start);

    if ~isfinite(mid_start_h)
        mid_start_h = first_finite_x(d.ProcTime_h, d.placeholder_mid_median);
    end

end


function x0 = first_finite_x(x, y)

    x = double(x);
    y = double(y);

    valid = isfinite(x) & isfinite(y);

    if sum(valid) == 0
        x0 = NaN;
    else
        x0 = min(x(valid));
    end

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


function add_local_rmse_inset_visible(mainAx, feature, rmse_lstm_local, rmse_mech_local, col_lstm, col_mech)

    if ~isfinite(rmse_lstm_local) && ~isfinite(rmse_mech_local)
        return
    end

    fig = ancestor(mainAx, "figure");
    pos = mainAx.Position;

    % Small and close to y-axis.
    % Biomass: top-left. Substrate and DO: bottom-left.
    if feature == "Biomass"
        insetPos = [ ...
            pos(1) + 0.05 * pos(3), ...
            pos(2) + 0.40 * pos(4), ...
            0.15 * pos(3), ...
            0.26 * pos(4)];
    else
        insetPos = [ ...
            pos(1) + 0.05 * pos(3), ...
            pos(2) + 0.06 * pos(4), ...
            0.15 * pos(3), ...
            0.26 * pos(4)];
    end

    insetAx = axes( ...
        "Parent", fig, ...
        "Position", insetPos, ...
        "Color", "none", ...
        "Box", "off", ...
        "Tag", "local_rmse_inset" ...
    );
    hold(insetAx, "on");

    barValues = [rmse_lstm_local, rmse_mech_local];

    if all(~isfinite(barValues))
        text(insetAx, 0.5, 0.5, "NaN RMSE", ...
            "Units", "normalized", ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "middle", ...
            "FontSize", 7);
    else
        b = bar(insetAx, barValues, ...
            "FaceColor", "flat", ...
            "EdgeColor", "k", ...
            "LineWidth", 0.6);

        b.CData(1, :) = col_lstm;
        b.CData(2, :) = col_mech;

        ymax_inset = max(barValues(isfinite(barValues)));

        if isempty(ymax_inset) || ~isfinite(ymax_inset) || ymax_inset <= 0
            ymax_inset = 1;
        end

        ylim(insetAx, [0, 1.8 * ymax_inset]);

        text(insetAx, 1:2, barValues, ...
            compose("%.1f", barValues), ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "bottom", ...
            "FontSize", 8);
    end

    set(insetAx, ...
        "XTick", 1:2, ...
        "XTickLabel", ["", ""], ...
        "FontSize", 8, ...
        "YTick", [], ...
        "YTickLabel", []);

    insetAx.YAxis.Visible = "off";

    title(insetAx, "Post-cutoff RMSE", ...
        "FontSize", 10, ...
        "FontWeight", "normal", ...
        "Units", "normalized", ...
        "Position", [0.5, 0.86, 0]);

    grid(insetAx, "off");
    box(insetAx, "off");

    drawnow;

    try
        uistack(insetAx, "top");
    catch
    end

end

function plot_rmse_bar_axis_rightside( ...
    ax, rmse_rows, feature, condition_labels, ...
    col_nn_bar, col_mn_bar, col_new_start, show_xticklabels)

    d = rmse_rows(rmse_rows.feature == feature, :);

    rmse_lstm = nan(1, numel(condition_labels));
    rmse_mech = nan(1, numel(condition_labels));
    rmse_new_full = nan(1, numel(condition_labels));

    for i = 1:numel(condition_labels)
        row = d(d.condition == condition_labels(i), :);

        if ~isempty(row)
            rmse_lstm(i) = row.rmse_lstm(1);
            rmse_mech(i) = row.rmse_mech(1);
            rmse_new_full(i) = row.rmse_new_full(1);
        end
    end

    % Same x positions for all three feature rows.
    bar_w = 0.16;
    gap_group = 0.85;

    x_centers = (0:numel(condition_labels)-1) * (3 * bar_w + gap_group);
    offsets = (-1:1) * (bar_w * 1.15);
    

    bar(ax, x_centers + offsets(1), rmse_mech, bar_w, ...
        "FaceColor", col_mn_bar, ...
        "FaceAlpha", 0.90, ...
        "EdgeColor", "none", ...
        "DisplayName", "Mech-Lit model RMSE");

    bar(ax, x_centers + offsets(2), rmse_lstm, bar_w, ...
        "FaceColor", col_nn_bar, ...
        "FaceAlpha", 0.80, ...
        "EdgeColor", "none", ...
        "DisplayName", "LSTM-EMP RMSE");

    bar(ax, x_centers + offsets(3), rmse_new_full, bar_w, ...
        "FaceColor", col_new_start, ...
        "FaceAlpha", 0.80, ...
        "EdgeColor", "none", ...
        "DisplayName", "Mech-Refit model RMSE");

    % Shared x-axis behavior.
    ax.XTick = x_centers;

    if show_xticklabels
        ax.XTickLabel = ["Controlled", "Unregulated"];
    
        hx = xlabel(ax, ["DO"]);
        hx.FontSize = 11;
    else
        ax.XTickLabel = [];
        xlabel(ax, "");
    end

    % Y-axis on right side only, numeric ticks only.
    ax.YAxisLocation = "right";
    ylabel(ax, "");
    title(ax, "");

    ax.TickDir = "in";
    ax.LineWidth = 1.5;
    ax.FontSize = 14;
    ax.FontName = "Arial";
    
    grid(ax, "on");
    ax.GridAlpha = 0.20;
    ax.XGrid = "off";
    ax.YGrid = "on";
    
    ax.XAxis.FontSize = 14;
    ax.XAxis.TickLabelRotation = 0;
    
    ax.XLim = [min(x_centers) - 0.28, max(x_centers) + 0.28];

end