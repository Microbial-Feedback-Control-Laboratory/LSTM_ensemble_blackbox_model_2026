%% Recreate two-experiment plot from compact exported datasets
% Required files:
%   exp_43a_49b_curves_with_new_mech_and_mid_uw4800.csv
%   exp_43a_49b_measurements_uw4800.csv
%   exp_43a_49b_widest_band_all100_uw4800.csv
%
% Required helper files in MATLAB path:
%   save_figure.m
%   set_fig_size.m
%   nature_methods_colors.m
%   format_tick.m

clear; close all; clc;

set(groot, "defaultTextInterpreter", "tex");
set(groot, "defaultAxesTickLabelInterpreter", "tex");
set(groot, "defaultLegendInterpreter", "tex");

%% User settings

ver = "v10_f1";
plotpath = "C:\Research\HybridModel\March2025\Plots";
save_plot_path = fullfile(plotpath, "BB", ver);

uw = 4800;
redo_dir = fullfile(save_plot_path, "RedoMatlab");

curves_path       = fullfile(redo_dir, "exp_43a_49b_curves_with_new_mech_and_mid_uw" + string(uw) + ".csv");
measurements_path = fullfile(redo_dir, "exp_43a_49b_measurements_uw" + string(uw) + ".csv");
widest_path       = fullfile(redo_dir, "exp_43a_49b_widest_band_all100_uw" + string(uw) + ".csv");

curves = readtable(curves_path, "TextType", "string");
measurements = readtable(measurements_path, "TextType", "string");
widest = readtable(widest_path, "TextType", "string");

disp("[INFO] Loaded files:")
disp(curves_path)
disp(measurements_path)
disp(widest_path)

disp("[CHECK] Widest-band table size; should be 6 rows:")
disp(size(widest))

%% Plot settings

target_exps = ["2024_W43_A2", "2024_W49_B2"];
panel_labels = ["(a)", "(b)"];

feature_order = ["Biomass", "Substrate", "DO"];

ylabel_map = containers.Map;
ylabel_map("Biomass")   = "Biomass (g/L)";
ylabel_map("Substrate") = "Substrate (g/L)";
ylabel_map("DO")        = "DO (\%)";

% Same colors as Python plot
col_true       = [0.00, 0.00, 0.00];
col_nn         = [0.80, 0.10, 0.10];
col_ode        = [0.10, 0.55, 0.20];
col_band_light = [1.00, 0.70, 0.30];
col_band_dark  = [0.95, 0.55, 0.10];

% New added colors
col_new_start = [0.35, 0.15, 0.65];   % new mechanistic from start
col_lstm_mid  = [0.55, 0.00, 0.00];   % LSTM median from mid
col_new_mid   = [0.00, 0.45, 0.70];   % new mechanistic from mid
col_mid_line  = [0.25, 0.25, 0.25];   % vertical mid-time line

%% Figure and manual layout

fig = figure("Color", "w");
set_fig_size(2400, 1150);

% Manual normalized positions:
% two experiment blocks side by side.
% Each block has 3 stacked curve axes + 1 right RMSE axis.
left_xs = [0.08, 0.58];

% Longer curve panels
left_w = 0.345;

% Keep the gap between curve panel and barplot unchanged.
% Old gap = bar_offset - left_w = 0.335 - 0.320 = 0.015.
% New bar_offset = new left_w + 0.015.
bar_offset = 0.360;

% Narrower right RMSE barplot
bar_w = 0.060;

top_margin = 0.18;      % leave room for legend
bottom_margin = 0.08;

block_y = bottom_margin;
block_h = 1 - top_margin - bottom_margin;

panel_gap_y = 0.020;
panel_h = (block_h - 2 * panel_gap_y) / 3;

axes_all = gobjects(numel(target_exps), numel(feature_order));
bar_axes = gobjects(numel(target_exps), 1);

local_rmse_lstm_store = nan(numel(target_exps), numel(feature_order));
local_rmse_mech_store = nan(numel(target_exps), numel(feature_order));
mid_start_store = nan(numel(target_exps), numel(feature_order));

%% Metric table container

metric_rows = table( ...
    strings(0,1), strings(0,1), strings(0,1), ...
    zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    'VariableNames', { ...
        'experiment_id', ...
        'feature', ...
        'comparison', ...
        'mse', ...
        'rmse', ...
        'nrmse_range', ...
        'mean_abs_error_percent_stable', ...
        'percent_error_floor', ...
        'normalization_denominator', ...
        'n_points' ...
    } ...
);

%% Precompute shared RMSE limit for both right panels

all_rmse_vals = [];

for e0 = 1:numel(target_exps)

    exp_id0 = target_exps(e0);

    for f0 = 1:numel(feature_order)

        feature0 = feature_order(f0);

        sub0 = curves(curves.experiment_id == exp_id0 & curves.feature == feature0, :);
        sub0 = sortrows(sub0, "ProcTime_h");

        reference0 = sub0.reference;
        q500 = sub0.pred_median;
        mech0 = sub0.mechanistic_model;
        new_full0 = sub0.new_mechanistic_full_start;
        lstm_mid0 = sub0.placeholder_mid_median;
        new_mid0 = sub0.new_mechanistic_mid_start;

        mid_h0 = first_finite_x(sub0.ProcTime_h, new_mid0);
        if ~isfinite(mid_h0)
            mid_h0 = first_finite_x(sub0.ProcTime_h, lstm_mid0);
        end

        if isfinite(mid_h0)
            mid_mask0 = sub0.ProcTime_h >= mid_h0;
        else
            mid_mask0 = isfinite(lstm_mid0) | isfinite(new_mid0);
        end

        [~, rmse_lstm0] = calc_metrics_simple(reference0, q500);
        [~, rmse_mech0] = calc_metrics_simple(reference0, mech0);
        [~, rmse_new_full0] = calc_metrics_simple(reference0, new_full0);
        
        all_rmse_vals = [
            all_rmse_vals;
            rmse_lstm0;
            rmse_mech0;
            rmse_new_full0
        ];
    end
end

all_rmse_vals = all_rmse_vals(isfinite(all_rmse_vals));

if isempty(all_rmse_vals)
    shared_rmse_xlim = [0, 1];
else
    shared_rmse_xlim = [0, 1.15 * max(all_rmse_vals)];
end

%% Main plotting loop

for e = 1:numel(target_exps)

    exp_id = target_exps(e);

    left_x = left_xs(e);
    bar_x = left_x + bar_offset;

    rmse_lstm = nan(1, numel(feature_order));
    rmse_mech = nan(1, numel(feature_order));
    rmse_new_full = nan(1, numel(feature_order));
    rmse_lstm_mid = nan(1, numel(feature_order));
    rmse_new_mid = nan(1, numel(feature_order));

    for f = 1:numel(feature_order)

        feature = feature_order(f);

        % Position: feature 1 top, feature 3 bottom
        ax_y = block_y + block_h - f * panel_h - (f - 1) * panel_gap_y;

        ax = axes( ...
            "Parent", fig, ...
            "Position", [left_x, ax_y, left_w, panel_h] ...
        );
        hold(ax, "on");

        axes_all(e, f) = ax;

        sub = curves(curves.experiment_id == exp_id & curves.feature == feature, :);
        sub = sortrows(sub, "ProcTime_h");

        x = sub.ProcTime_h;
        reference = sub.reference;
        mech = sub.mechanistic_model;

        q5 = sub.pred_q5;
        q25 = sub.pred_q25;
        q50 = sub.pred_median;
        q75 = sub.pred_q75;
        q95 = sub.pred_q95;

        new_mech_full = sub.new_mechanistic_full_start;
        lstm_mid = sub.placeholder_mid_median;
        new_mech_mid = sub.new_mechanistic_mid_start;

        mid_start_h = first_finite_x(x, new_mech_mid);

        if ~isfinite(mid_start_h)
            mid_start_h = first_finite_x(x, lstm_mid);
        end

        if isfinite(mid_start_h)
            mid_eval_mask = x >= mid_start_h;
        else
            mid_eval_mask = isfinite(lstm_mid) | isfinite(new_mech_mid);
        end

        % 5--95% LSTM ensemble band
        fill(ax, ...
            [x; flipud(x)], ...
            [q5; flipud(q95)], ...
            col_band_light, ...
            "FaceAlpha", 0.35, ...
            "EdgeColor", "none", ...
            "DisplayName", "LSTM 5-95% ensemble interval");

        % 25--75% LSTM ensemble band
        fill(ax, ...
            [x; flipud(x)], ...
            [q25; flipud(q75)], ...
            col_band_dark, ...
            "FaceAlpha", 0.45, ...
            "EdgeColor", "none", ...
            "DisplayName", "LSTM 25-75% ensemble interval");

        % Preprocessed reference
        plot(ax, x, reference, ...
            "Color", col_true, ...
            "LineWidth", 1.5, ...
            "DisplayName", "Preprocessed reference data");

        % LSTM median, full start
        plot(ax, x, q50, ...
            "--", ...
            "Color", col_nn, ...
            "LineWidth", 1.8, ...
            "DisplayName", "LSTM-EMP");

        % Old mechanistic model
        mech_valid = isfinite(mech);

        if sum(mech_valid) > 1
            plot(ax, x(mech_valid), mech(mech_valid), ...
                "--", ...
                "Color", col_ode, ...
                "LineWidth", 1.8, ...
                "DisplayName", "Old mechanistic model");
        end

        % New mechanistic model from start
        new_full_valid = isfinite(new_mech_full);

        if sum(new_full_valid) > 1
            plot(ax, x(new_full_valid), new_mech_full(new_full_valid), ...
                "-.", ...
                "Color", col_new_start, ...
                "LineWidth", 1.8, ...
                "DisplayName", "New mechanistic, start");
        end

        % Vertical local-fit cutoff line
        h_cut = xline(ax, mid_start_h, ...
            "--", ...
            "Color", [0.00, 0.00, 0.00], ...
            "LineWidth", 1.8, ...
            "Alpha", 0.85, ...
            "DisplayName", "Local re-fit cutoff time");
        
        try
            h_cut.LineStyle = "--";
        catch
        end
        % LSTM median from mid time
        % lstm_mid_valid = mid_eval_mask & isfinite(lstm_mid);
        % 
        % if sum(lstm_mid_valid) > 1
        %     plot(ax, x(lstm_mid_valid), lstm_mid(lstm_mid_valid), ...
        %         ":", ...
        %         "Color", col_lstm_mid, ...
        %         "LineWidth", 2.0, ...
        %         "DisplayName", "LSTM-EMP, mid");
        % end

        % New mechanistic model from mid time
        new_mid_valid = mid_eval_mask & isfinite(new_mech_mid);

        if sum(new_mid_valid) > 1
            plot(ax, x(new_mid_valid), new_mech_mid(new_mid_valid), ...
                ":", ...
                "Color", col_new_mid, ...
                "LineWidth", 2.0, ...
                "DisplayName", "New mechanistic, mid");
        end

        % Measurements
        meas = measurements( ...
            measurements.experiment_id == exp_id & ...
            measurements.feature == feature, : ...
        );
        meas = sortrows(meas, "ProcTime_h");

        if height(meas) > 0

            if feature == "Biomass"

                % sc = scatter(ax, ...
                %     meas.ProcTime_h, ...
                %     meas.measurement, ...
                %     8, ...
                %     "MarkerEdgeColor", col_true, ...
                %     "MarkerFaceColor", "none", ...
                %     "LineWidth", 0.4, ...
                %     "DisplayName", "Biomass measurements");

                keep_every = 4;
                keep_idx = 1:keep_every:height(meas);
                
                sc = scatter(ax, ...
                    meas.ProcTime_h(keep_idx), ...
                    meas.measurement(keep_idx), ...
                    5, ...
                    "MarkerEdgeColor", col_true, ...
                    "MarkerFaceColor", "none", ...
                    "LineWidth", 0.6, ...
                    "DisplayName", "Biomass measurements");

                try
                    sc.MarkerEdgeAlpha = 0.30;
                catch
                    % Older MATLAB versions may not support MarkerEdgeAlpha.
                end

            elseif feature == "Substrate"

                scatter(ax, ...
                    meas.ProcTime_h, ...
                    meas.measurement, ...
                    40, ...
                    "MarkerEdgeColor", col_true, ...
                    "MarkerFaceColor", "none", ...
                    "LineWidth", 1.5, ...
                    "DisplayName", "Substrate measurements");

            end

            % DO measurements are loaded but not plotted, matching your Python plot.
        end

        % Metrics: full-window reference vs LSTM median
        [mse1, rmse1, nrmse1, mae_pct1, pct_floor1, denom1, n1] = calc_metrics(reference, q50);
        rmse_lstm(f) = rmse1;

        metric_rows = [metric_rows; table( ...
            exp_id, feature, "reference_vs_LSTM_EMP_median_full", ...
            mse1, rmse1, nrmse1, mae_pct1, pct_floor1, denom1, n1, ...
            'VariableNames', metric_rows.Properties.VariableNames ...
        )];

        % Metrics: full-window reference vs old mechanistic model
        [mse2, rmse2, nrmse2, mae_pct2, pct_floor2, denom2, n2] = calc_metrics(reference, mech);
        rmse_mech(f) = rmse2;

        metric_rows = [metric_rows; table( ...
            exp_id, feature, "reference_vs_old_mechanistic_full", ...
            mse2, rmse2, nrmse2, mae_pct2, pct_floor2, denom2, n2, ...
            'VariableNames', metric_rows.Properties.VariableNames ...
        )];

        % Metrics: full-window reference vs new mechanistic from start
        [mse3, rmse3, nrmse3, mae_pct3, pct_floor3, denom3, n3] = calc_metrics(reference, new_mech_full);
        rmse_new_full(f) = rmse3;

        metric_rows = [metric_rows; table( ...
            exp_id, feature, "reference_vs_new_mechanistic_start_full", ...
            mse3, rmse3, nrmse3, mae_pct3, pct_floor3, denom3, n3, ...
            'VariableNames', metric_rows.Properties.VariableNames ...
        )];

        % Metrics: local-period reference vs original LSTM-EMP median
        % This uses q50, not placeholder_mid_median.
        [mse4, rmse4, nrmse4, mae_pct4, pct_floor4, denom4, n4] = calc_metrics( ...
            reference(mid_eval_mask), ...
            q50(mid_eval_mask) ...
        );
        rmse_lstm_mid(f) = rmse4;
        
        metric_rows = [metric_rows; table( ...
            exp_id, feature, "reference_vs_LSTM_EMP_local_period", ...
            mse4, rmse4, nrmse4, mae_pct4, pct_floor4, denom4, n4, ...
            'VariableNames', metric_rows.Properties.VariableNames ...
        )];
        % Metrics: mid-window reference vs new mechanistic from mid
        [mse5, rmse5, nrmse5, mae_pct5, pct_floor5, denom5, n5] = calc_metrics( ...
            reference(mid_eval_mask), ...
            new_mech_mid(mid_eval_mask) ...
        );
        rmse_new_mid(f) = rmse5;
        local_rmse_lstm_store(e, f) = rmse_lstm_mid(f);
        local_rmse_mech_store(e, f) = rmse_new_mid(f);
        mid_start_store(e, f) = mid_start_h;

        

        metric_rows = [metric_rows; table( ...
            exp_id, feature, "reference_vs_new_mechanistic_mid_from_mid_time", ...
            mse5, rmse5, nrmse5, mae_pct5, pct_floor5, denom5, n5, ...
            'VariableNames', metric_rows.Properties.VariableNames ...
        )];

        % Axis formatting
        ylabel(ax, ylabel_map(feature));

        ax.YLabel.Units = "normalized";
        ax.YLabel.Position(1) = -0.080;

        grid(ax, "off");

        ax.TickDir = "in";
        ax.LineWidth = 1.5;
        ax.FontSize = 12;
        ax.FontName = "Arial";

        ax.XMinorTick = "on";
        ax.YMinorTick = "on";

        xmin = 0;
        xmax = max(x) + 0.5;
        
        xlim(ax, [xmin, xmax]);
        xticks(ax, 0:2:ceil(xmax));

        if f < numel(feature_order)
            ax.XTickLabel = [];
        else
            xlabel(ax, "Process time (h)");
        end

        % Panel label
        if f == 1
            text(ax, -0.22, 1.06, char(panel_labels(e)), ...
                "Units", "normalized", ...
                "Interpreter", "none", ...
                "FontSize", 24, ...
                "FontWeight", "bold", ...
                "FontName", "Arial", ...
                "VerticalAlignment", "top", ...
                "HorizontalAlignment", "left", ...
                "Clipping", "off");
        end

        %% Inset bar plot: local refit RMSE bar

        mainAx = ax;
        pos = mainAx.Position;
        
        % Fixed visible test position inside each line panel.
        % Biomass/Substrate: top-right. DO: bottom-right.
        if feature ~= "Biomass"

            insetPos = [ ...
                pos(1) + 0.03 * pos(3), ...
                pos(2) + 0.04 * pos(4), ...
                0.18 * pos(3), ...
                0.26 * pos(4)];

        else

            insetPos = [ ...
                pos(1) + 0.03 * pos(3), ...
                pos(2) + 0.40 * pos(4), ...
                0.18 * pos(3), ...
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
        
        barValues = [rmse_lstm_mid(f), rmse_new_mid(f)];
        
        % Diagnostic text if values are NaN.
        if all(~isfinite(barValues))
            text(insetAx, 0.5, 0.5, "NaN RMSE", ...
                "Units", "normalized", ...
                "HorizontalAlignment", "center", ...
                "VerticalAlignment", "middle", ...
                "FontSize", 8);
        else
            b = bar(insetAx, barValues, ...
                "FaceColor", "flat", ...
                "EdgeColor", "k", ...
                "LineWidth", 0.8);
        
            b.CData(1, :) = col_band_dark;
            b.CData(2, :) = col_new_mid;
        
            ymax_inset = max(barValues(isfinite(barValues)));
        
            if isempty(ymax_inset) || ~isfinite(ymax_inset) || ymax_inset <= 0
                ymax_inset = 1;
            end
        
            ylim(insetAx, [0, 1.80 * ymax_inset]);
        
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
            "FontSize", 8, ...
            "FontWeight", "normal", ...
            "Units", "normalized", ...
            "Position", [0.5, 0.84, 0]);
        
        grid(insetAx, "off");
        
        % Force it visually to the front now.
        drawnow;
        try
            uistack(insetAx, "top");
        catch
        end
        
        axes(mainAx);

    end

    %% Right RMSE bar panel

    ax_bar = axes( ...
        "Parent", fig, ...
        "Position", [bar_x, block_y, bar_w, block_h] ...
    );
    hold(ax_bar, "on");

    bar_axes(e) = ax_bar;

    cats = ["Biomass", "Substrate", "DO"];

    eps_val = 1e-6;

    vals_lstm = rmse_lstm;
    vals_old_mech = rmse_mech;
    vals_new_full = rmse_new_full;
    
    vals_lstm(isfinite(vals_lstm)) = max(vals_lstm(isfinite(vals_lstm)), eps_val);
    vals_old_mech(isfinite(vals_old_mech)) = max(vals_old_mech(isfinite(vals_old_mech)), eps_val);
    vals_new_full(isfinite(vals_new_full)) = max(vals_new_full(isfinite(vals_new_full)), eps_val);
    
    y_base = (0:numel(cats)-1) * 1.35;
    bar_h = 0.14;
    
    offsets = ((1:3) - 2) * bar_h;

    for k = 1:numel(cats)

        if isfinite(vals_lstm(k))
            barh(ax_bar, y_base(k) + offsets(1), vals_lstm(k), bar_h, ...
                "FaceColor", col_band_dark, ...
                "FaceAlpha", 0.5, ...
                "EdgeColor", "black", ...
                "LineWidth", 0.8, ...
                "DisplayName", "LSTM-EMP full RMSE");
        end
    
        if isfinite(vals_old_mech(k))
            barh(ax_bar, y_base(k) + offsets(2), vals_old_mech(k), bar_h, ...
                "FaceColor", col_ode, ...
                "FaceAlpha", 0.45, ...
                "EdgeColor", col_ode, ...
                "LineWidth", 1.2, ...
                "DisplayName", "Old mechanistic full RMSE");
        end
    
        if isfinite(vals_new_full(k))
            barh(ax_bar, y_base(k) + offsets(3), vals_new_full(k), bar_h, ...
                "FaceColor", col_new_start, ...
                "FaceAlpha", 0.45, ...
                "EdgeColor", col_new_start, ...
                "LineWidth", 1.2, ...
                "DisplayName", "Re-fit mechanistic full RMSE");
        end
    end

    set(ax_bar, "XScale", "log");

    % Use log scale with readable ticks.
    xlim(ax_bar, [0.1, 30]);
    
    ax_bar.XTick = [1, 10];
    ax_bar.XTickLabel = ["1", "10"];
    ax_bar.XTickLabelRotation = 0;

    ax_bar.YTick = y_base;
    ax_bar.YTickLabel = [];
    ax_bar.YDir = "reverse";

    ax_bar.TickDir = "in";
    ax_bar.LineWidth = 1.5;
    ax_bar.FontSize = 12;
    ax_bar.FontName = "Arial";

    hx = xlabel(ax_bar, ["RMSE"; "(log scale)"]);
    hx.FontSize = 12;

    grid(ax_bar, "off");
    box(ax_bar, "on");

end

%% Bring inset axes to front

all_axes = findall(fig, "Type", "axes");

for ii = 1:numel(all_axes)
    tag_i = string(get(all_axes(ii), "Tag"));

    if tag_i == "local_rmse_inset"
        try
            uistack(all_axes(ii), "top");
        catch
        end
    end
end

%% Add separate legend at top

% Create invisible axes for legend handles
ax_leg = axes( ...
    "Parent", fig, ...
    "Position", [0.04, 0.962, 0.93, 0.035], ...
    "Visible", "off" ...
);
hold(ax_leg, "on");
axis(ax_leg, "off");
ax_leg.Box = "off";
ax_leg.XColor = "none";
ax_leg.YColor = "none";

% Dummy handles, only for legend
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
    "LineWidth", 1.2, ...
    "DisplayName", "Preprocessed reference data");

h_lstm = plot(ax_leg, NaN, NaN, ...
    "--", ...
    "Color", col_nn, ...
    "LineWidth", 1.8, ...
    "DisplayName", "LSTM-EMP");

h_biomass_meas = scatter(ax_leg, NaN, NaN, ...
    5, ...
    "MarkerEdgeColor", col_true, ...
    "MarkerFaceColor", "none", ...
    "LineWidth", 0.6, ...
    "DisplayName", "Biomass measurements");

try
    h_biomass_meas.MarkerEdgeAlpha = 0.20;
catch
end

h_sub_meas = scatter(ax_leg, NaN, NaN, ...
    40, ...
    "MarkerEdgeColor", col_true, ...
    "MarkerFaceColor", "none", ...
    "LineWidth", 1.5, ...
    "DisplayName", "Substrate measurements");

h_old_mech = plot(ax_leg, NaN, NaN, ...
    "--", ...
    "Color", col_ode, ...
    "LineWidth", 1.8, ...
    "DisplayName", "Mech-Lit model");

h_new_start = plot(ax_leg, NaN, NaN, ...
    "-.", ...
    "Color", col_new_start, ...
    "LineWidth", 1.8, ...
    "DisplayName", "Mech-Refit model");

h_mid_line = plot(ax_leg, NaN, NaN, ...
    "--", ...
    "Color", [0.00, 0.00, 0.00], ...
    "LineWidth", 1.2, ...
    "DisplayName", "Cutoff time");

h_new_mid = plot(ax_leg, NaN, NaN, ...
    ":", ...
    "Color", col_new_mid, ...
    "LineWidth", 2.0, ...
    "DisplayName", "Mech-Refit model, post-cutoff");

h_bar_lstm_full = bar(ax_leg, NaN, NaN, ...
    "FaceColor", col_band_dark, ...
    "FaceAlpha", 0.5, ...
    "EdgeColor", "black", ...
    "LineWidth", 0.8, ...
    "DisplayName", "LSTM-EMP RMSE");

h_bar_mech_full = bar(ax_leg, NaN, NaN, ...
    "FaceColor", col_ode, ...
    "FaceAlpha", 0.45, ...
    "EdgeColor", col_ode, ...
    "LineWidth", 1.2, ...
    "DisplayName", "Mech-Lit RMSE");

h_bar_refit_full = bar(ax_leg, NaN, NaN, ...
    "FaceColor", col_new_start, ...
    "FaceAlpha", 0.45, ...
    "EdgeColor", col_new_start, ...
    "LineWidth", 1.2, ...
    "DisplayName", "Mech-Refit model RMSE");

h_bar_lstm_local = bar(ax_leg, NaN, NaN, ...
    "FaceColor", col_band_dark, ...
    "FaceAlpha", 1.0, ...
    "EdgeColor", "black", ...
    "LineWidth", 0.8, ...
    "DisplayName", "LSTM-EMP RMSE, post-cutoff");

h_bar_refit_local = bar(ax_leg, NaN, NaN, ...
    "FaceColor", col_new_mid, ...
    "FaceAlpha", 1.0, ...
    "EdgeColor", "black", ...
    "LineWidth", 0.8, ...
    "DisplayName", "Mech-Refit RMSE, post-cutoff");

lgd = legend(ax_leg, ...
    [h_band95, h_band75, h_ref, h_lstm, h_biomass_meas, h_sub_meas, ...
     h_old_mech, h_new_start, h_mid_line, h_new_mid, ...
     h_bar_lstm_full, h_bar_mech_full, h_bar_refit_full, ...
     h_bar_lstm_local, h_bar_refit_local], ...
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
lgd.FontSize = 15;
lgd.FontName = "Arial";

%% Print metrics

disp(" ")
disp("============================================================")
disp("Calculated metrics")
disp("MSE = mean((reference - prediction).^2)")
disp("RMSE = sqrt(MSE)")
disp("NRMSE = RMSE / (max(reference) - min(reference))")
disp("Stable mean absolute error % = 100 * mean(abs(error) ./ max(abs(reference), 0.05 * median(abs(reference))))")
disp("============================================================")
disp(metric_rows)

metrics_out_path = fullfile(redo_dir, "exp_43a_49b_metrics_new_mech_mid_from_matlab_uw" + string(uw) + ".csv");
% writetable(metric_rows, metrics_out_path);

disp("[OK] Saved metrics table:")
disp(metrics_out_path)

%% Save figure

out_pdf = fullfile(redo_dir, "matlab_recreated_exp_43a_49b_withbar_new_mech_mid_rmse2.pdf");

%% Remove MATLAB axes toolbar / interaction icons before saving

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

save_figure(char(out_pdf), fig.Number, false);
disp("[OK] Saved recreated MATLAB figure:")
disp(out_pdf)



%% Local functions

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

function [mse_val, rmse_val, nrmse_val, mean_abs_error_percent_stable, percent_error_floor, denom, n_points] = calc_metrics(y_true, y_pred)

    y_true = double(y_true);
    y_pred = double(y_pred);

    valid = isfinite(y_true) & isfinite(y_pred);

    n_points = sum(valid);

    if n_points == 0
        mse_val = NaN;
        rmse_val = NaN;
        nrmse_val = NaN;
        mean_abs_error_percent_stable = NaN;
        percent_error_floor = NaN;
        denom = NaN;
        return
    end

    y_true_valid = y_true(valid);
    y_pred_valid = y_pred(valid);

    err = y_true_valid - y_pred_valid;
    abs_err = abs(err);

    mse_val = mean(err.^2);
    rmse_val = sqrt(mse_val);

    denom = max(y_true_valid) - min(y_true_valid);

    if denom > 0
        nrmse_val = rmse_val / denom;
    else
        nrmse_val = NaN;
    end

    percent_error_floor = 0.05 * median(abs(y_true_valid));

    if percent_error_floor > 0
        stable_denom = max(abs(y_true_valid), percent_error_floor);
        mean_abs_error_percent_stable = 100 * mean(abs_err ./ stable_denom);
    else
        mean_abs_error_percent_stable = NaN;
    end
end

function [mse_val, rmse_val] = calc_metrics_simple(y_true, y_pred)

    y_true = double(y_true);
    y_pred = double(y_pred);

    valid = isfinite(y_true) & isfinite(y_pred);

    if sum(valid) == 0
        mse_val = NaN;
        rmse_val = NaN;
        return
    end

    err = y_true(valid) - y_pred(valid);

    mse_val = mean(err.^2);
    rmse_val = sqrt(mse_val);

end
