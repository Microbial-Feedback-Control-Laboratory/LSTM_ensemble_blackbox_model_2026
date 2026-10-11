%% Recreate raw vs final LSTM two-exp plot from compact CSVs
% Reads:
%   fix_raw_two_exp_curves_uw4800.csv
%   fix_raw_two_exp_measurements_uw4800.csv

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

curves_path = fullfile(redo_dir, "fix_raw_two_exp_curves_uw" + string(uw) + ".csv");
measurements_path = fullfile(redo_dir, "fix_raw_two_exp_measurements_uw" + string(uw) + ".csv");

curves = readtable(curves_path, "TextType", "string");
measurements = readtable(measurements_path, "TextType", "string");

disp("[INFO] Loaded:")
disp(curves_path)
disp(measurements_path)

%% Settings

target_exps = ["2024_W49_B2", "2024_W51_A2"];
panel_labels = ["(a)", "(b)"];
feature_order = ["Biomass", "Substrate", "DO"];

ylabel_map = containers.Map;
ylabel_map("Biomass")   = "Biomass (g/L)";
ylabel_map("Substrate") = "Substrate (g/L)";
ylabel_map("DO")        = "DO (%)";

% Colors, matched to Python
col_true = [0.00, 0.00, 0.00];
col_final = [0.80, 0.10, 0.10];
col_raw = [0.45, 0.10, 0.80];

col_band_final = [1.00, 0.70, 0.30];
col_band_raw = [0.70, 0.70, 1.00];

%% Figure layout

fig = figure("Color", "w");
set(fig, "Units", "centimeters");
set(fig, "Position", [2 2 38 19]);

% Manual layout to mimic Python 3 x 2 subplots
left_x = 0.105;     % more room for (a)
right_x = 0.550;
panel_w = 0.390;    % slightly narrower panels

top_y = 0.630;
mid_y = 0.375;
bot_y = 0.120;
panel_h = 0.235;

axes_all = gobjects(3, 2);

for c = 1:2

    exp_id = target_exps(c);

    if c == 1
        x0 = left_x;
        show_ylabels = true;
        show_left_ticklabels = true;
    else
        x0 = right_x;
        show_ylabels = false;
        show_left_ticklabels = false;
    end

    y_positions = [top_y, mid_y, bot_y];

    for r = 1:3

        feature = feature_order(r);

        ax = axes( ...
            "Parent", fig, ...
            "Position", [x0, y_positions(r), panel_w, panel_h] ...
        );
        hold(ax, "on");

        axes_all(r, c) = ax;

        plot_one_panel_from_csv( ...
            ax, ...
            curves, ...
            measurements, ...
            exp_id, ...
            feature, ...
            ylabel_map, ...
            col_true, ...
            col_final, ...
            col_raw, ...
            col_band_final, ...
            col_band_raw, ...
            show_ylabels, ...
            show_left_ticklabels ...
        );

        if r < 3
            ax.XTickLabel = [];
        else
            xlabel(ax, "Process Time (h)");
        end
    end

    % Panel label
    if c == 1
        label_x = -0.22;
    else
        label_x = -0.10;
    end

    text(axes_all(1, c), label_x, 0.99, panel_labels(c), ...
        "Units", "normalized", ...
        "Interpreter", "none", ...
        "FontSize", 30, ...
        "FontWeight", "bold", ...
        "FontName", "Arial", ...
        "VerticalAlignment", "top", ...
        "HorizontalAlignment", "left", ...
        "Clipping", "off");
end

% Align left y-labels
for r = 1:3
    axes_all(r,1).YLabel.Units = "normalized";
    axes_all(r,1).YLabel.Position(1) = -0.085;
end

%% Calculate and print RMSE: raw vs reference and final vs reference

rmse_rows = table( ...
    strings(0,1), strings(0,1), ...
    zeros(0,1), zeros(0,1), zeros(0,1), ...
    'VariableNames', { ...
        'experiment_id', ...
        'feature', ...
        'rmse_raw_vs_reference', ...
        'rmse_final_vs_reference', ...
        'n_points' ...
    } ...
);

for c = 1:numel(target_exps)

    exp_id = target_exps(c);

    for r = 1:numel(feature_order)

        feature = feature_order(r);

        d = curves(curves.experiment_id == exp_id & curves.feature == feature, :);
        d = sortrows(d, "ProcTime_h");

        if isempty(d)
            rmse_raw = NaN;
            rmse_final = NaN;
            n_points = 0;
        else
            y_ref = d.reference;
            y_raw = d.raw_median;
            y_final = d.final_median;

            valid_raw = isfinite(y_ref) & isfinite(y_raw);
            valid_final = isfinite(y_ref) & isfinite(y_final);

            if any(valid_raw)
                rmse_raw = sqrt(mean((y_ref(valid_raw) - y_raw(valid_raw)).^2));
            else
                rmse_raw = NaN;
            end

            if any(valid_final)
                rmse_final = sqrt(mean((y_ref(valid_final) - y_final(valid_final)).^2));
            else
                rmse_final = NaN;
            end

            n_points = sum(isfinite(y_ref) & (isfinite(y_raw) | isfinite(y_final)));
        end

        rmse_rows = [rmse_rows; table( ...
            exp_id, ...
            feature, ...
            rmse_raw, ...
            rmse_final, ...
            n_points, ...
            'VariableNames', rmse_rows.Properties.VariableNames ...
        )];

    end
end

disp(" ")
disp("============================================================")
disp("RMSE: LSTM-EMP raw vs reference and LSTM-EMP final vs reference")
disp("============================================================")
disp(rmse_rows)

%% Legend inside same figure

ax_leg = axes( ...
    "Parent", fig, ...
    "Position", [0.06, 0.935, 0.92, 0.055], ...
    "Visible", "off" ...
);
hold(ax_leg, "on");
axis(ax_leg, "off");
ax_leg.Box = "off";

h_band_final = fill(ax_leg, NaN, NaN, col_band_final, ...
    "FaceAlpha", 0.25, ...
    "EdgeColor", "none", ...
    "DisplayName", "LSTM 5-95% ensemble interval (final)");

h_band_raw = fill(ax_leg, NaN, NaN, col_band_raw, ...
    "FaceAlpha", 0.18, ...
    "EdgeColor", "none", ...
    "DisplayName", "LSTM 5-95% ensemble interval (raw)");

h_ref = plot(ax_leg, NaN, NaN, ...
    "Color", col_true, ...
    "LineWidth", 2.2, ...
    "DisplayName", "Preprocessed reference data");

h_final = plot(ax_leg, NaN, NaN, ...
    "--", ...
    "Color", col_final, ...
    "LineWidth", 1.8, ...
    "DisplayName", "LSTM-EMP (final)");

h_raw = plot(ax_leg, NaN, NaN, ...
    ":", ...
    "Color", col_raw, ...
    "LineWidth", 2.0, ...
    "DisplayName", "LSTM-EMP (raw)");

h_biomass_meas = scatter(ax_leg, NaN, NaN, ...
    8, ...
    "MarkerEdgeColor", col_true, ...
    "MarkerFaceColor", "none", ...
    "DisplayName", "Biomass measurements");

try
    h_biomass_meas.MarkerEdgeAlpha = 0.30;
catch
end

h_sub_meas = scatter(ax_leg, NaN, NaN, ...
    40, ...
    "MarkerEdgeColor", col_true, ...
    "MarkerFaceColor", "none", ...
    "LineWidth", 1.5, ...
    "DisplayName", "Substrate measurements");

lgd = legend(ax_leg, ...
    [h_band_final, h_band_raw, h_ref, h_final, h_raw, h_biomass_meas, h_sub_meas], ...
    "Location", "north", ...
    "Orientation", "horizontal", ...
    "NumColumns", 4);

lgd.Box = "off";
lgd.FontSize = 16;
lgd.FontName = "Arial";

%% Remove MATLAB toolbar icons before export

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

out_pdf = fullfile(redo_dir, "matlab_recreated_fix_raw_two_exp_nobar_uw" + string(uw) + ".pdf");

exportgraphics(fig, char(out_pdf), ...
    "ContentType", "vector", ...
    "BackgroundColor", "white");

disp("[OK] Saved:")
disp(out_pdf)

%% Local functions

function plot_one_panel_from_csv( ...
    ax, ...
    curves, ...
    measurements, ...
    exp_id, ...
    feature, ...
    ylabel_map, ...
    col_true, ...
    col_final, ...
    col_raw, ...
    col_band_final, ...
    col_band_raw, ...
    show_ylabels, ...
    show_left_ticklabels ...
)

    d = curves(curves.experiment_id == exp_id & curves.feature == feature, :);
    d = sortrows(d, "ProcTime_h");

    if isempty(d)
        text(ax, 0.5, 0.5, sprintf("No data\n%s\n%s", exp_id, feature), ...
            "Units", "normalized", ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "middle");
        return
    end

    t = d.ProcTime_h;

    % Final 5-95% band
    fill(ax, ...
        [t; flipud(t)], ...
        [d.final_q05; flipud(d.final_q95)], ...
        col_band_final, ...
        "FaceAlpha", 0.25, ...
        "EdgeColor", "none", ...
        "DisplayName", "LSTM 5-95% ensemble interval (final)");

    % Raw 5-95% band
    fill(ax, ...
        [t; flipud(t)], ...
        [d.raw_q05; flipud(d.raw_q95)], ...
        col_band_raw, ...
        "FaceAlpha", 0.18, ...
        "EdgeColor", "none", ...
        "DisplayName", "LSTM 5-95% ensemble interval (raw)");

    % Preprocessed reference
    plot(ax, t, d.reference, ...
        "Color", col_true, ...
        "LineWidth", 2.2, ...
        "DisplayName", "Preprocessed reference data");

    % Final median
    plot(ax, t, d.final_median, ...
        "--", ...
        "Color", col_final, ...
        "LineWidth", 1.8, ...
        "DisplayName", "LSTM-EMP (final)");

    % Raw median
    plot(ax, t, d.raw_median, ...
        ":", ...
        "Color", col_raw, ...
        "LineWidth", 2.0, ...
        "DisplayName", "LSTM-EMP (raw)");

    % Measurements
    m = measurements(measurements.experiment_id == exp_id & measurements.feature == feature, :);
    m = sortrows(m, "ProcTime_h");

    if ~isempty(m)
        if feature == "Substrate"
            scatter(ax, m.ProcTime_h, m.measurement, ...
                40, ...
                "MarkerEdgeColor", col_true, ...
                "MarkerFaceColor", "none", ...
                "LineWidth", 1.5, ...
                "DisplayName", "Substrate measurements");

        % elseif feature == "Biomass"
        %     sc = scatter(ax, m.ProcTime_h, m.measurement, ...
        %         3, ...
        %         "MarkerEdgeColor", col_true, ...
        %         "MarkerFaceColor", "none", ...
        %         "LineWidth", 0.4, ...
        %         "DisplayName", "Biomass measurements");
        % 
        %     try
        %         sc.MarkerEdgeAlpha = 0.15;
        %     catch
        %     end
        % 
        %     % DO measurements intentionally not shown, matching Python plot.
        end
    end

    % Y label / tick label logic
    if show_ylabels
        ylabel(ax, ylabel_map(feature));
    else
        ylabel(ax, "");
    end

    if ~show_left_ticklabels
        ax.YTickLabel = [];
    end

    % Axis style
    grid(ax, "on");
    ax.GridAlpha = 0.25;

    ax.TickDir = "in";
    ax.LineWidth = 1.5;
    ax.FontSize = 18;
    ax.FontName = "Arial";

    ax.XMinorTick = "on";
    ax.YMinorTick = "on";

    format_axis(ax, exp_id, feature);

end


function format_axis(ax, exp_id, feature)

    if any(exp_id == ["2025_W23_A2", "2025_W23_B2"])

        if feature == "Biomass"
            ylim(ax, [0, 18]);
            ax.YTick = 0:5:20;
            xlim(ax, [0, 9]);
            ax.XTick = 0:2:10;

        elseif feature == "Substrate"
            ylim(ax, [0, 22]);
            ax.YTick = 0:10:30;
            xlim(ax, [0, 9]);
            ax.XTick = 0:2:10;

        elseif feature == "DO"
            ylim(ax, [0, 100]);
            ax.YTick = 0:25:100;
            xlim(ax, [0, 9]);
            ax.XTick = 0:2:10;
        end

    elseif any(exp_id == ["2024_W49_B2", "2024_W51_A2", "2024_W51_B2"])

        if feature == "Biomass"
            ylim(ax, [0, 18]);
            ax.YTick = 0:5:20;
            ax.XTick = 0:2:20;

        elseif feature == "Substrate"
            ylim(ax, [-9, 14]);
            ax.YTick = -10:5:15;
            ax.XTick = 0:2:20;

        elseif feature == "DO"
            ylim(ax, [0, 90]);
            ax.YTick = 0:20:100;
            ax.XTick = 0:2:20;
        end
    end

end