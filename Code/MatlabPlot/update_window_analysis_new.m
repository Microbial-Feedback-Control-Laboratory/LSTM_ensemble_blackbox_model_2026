%% Validation RMSE boxplots by update window
% Layout: Biomass | Substrate | DO
%
% Reads:
%   check_mse_stats.csv
%
% Metric:
%   RMSE = sqrt(MSE)

clear; close all; clc;

set(groot, "defaultTextInterpreter", "tex");
set(groot, "defaultAxesTickLabelInterpreter", "tex");
set(groot, "defaultLegendInterpreter", "tex");

%% Paths

ver = "v10_f1";
plotpath = "C:\Research\HybridModel\March2025\Plots";
save_plot_path = fullfile(plotpath, "BB", ver);
redo_dir = fullfile(save_plot_path, "RedoMatlab");
csv_path = fullfile(save_plot_path, "check_mse_stats.csv");
csv_new_mech_path = fullfile(save_plot_path, "full_new_mechanistic_check_mse_stats.csv");

T = readtable(csv_path, "TextType", "string");
T_new = readtable(csv_new_mech_path, "TextType", "string");

%% Validation experiments

vallist = [
    "2024_W51_A2"
    "2024_W51_B2"
    "2024_W49_B2"
    "2024_W43_A2"
    "2024_W43_B2"
    "2025_W23_B2"
    "2025_W21_A2"
    "2025_W21_B2"
    "2025_W23_A2"
];

T = T(ismember(T.experiment_id, vallist), :);
T_new = T_new(ismember(T_new.experiment_id, vallist), :);
%% Colors: matched to attached MATLAB figure

col_lstm = [0.95, 0.55, 0.10];       % orange
col_mech = [0.10, 0.55, 0.20];       % green
col_new_mech = [0.35, 0.15, 0.65];   % purple

%% Add update-window labels

T.uw_label = strings(height(T), 1);

for i = 1:height(T)
    h = T.update_window_min(i) / 60;

    if h == 80
        T.uw_label(i) = "No Update";
    else
        T.uw_label(i) = string(round(h));
    end
end

T_new.uw_label = strings(height(T_new), 1);

for i = 1:height(T_new)
    h = T_new.update_window_min(i) / 60;

    if h == 80
        T_new.uw_label(i) = "No Update";
    else
        T_new.uw_label(i) = string(round(h));
    end
end

uw_values = sort(unique(T.update_window_min));
uw_order = strings(numel(uw_values), 1);

for i = 1:numel(uw_values)
    h = uw_values(i) / 60;

    if h == 80
        uw_order(i) = "No Update";
    else
        uw_order(i) = string(round(h));
    end
end

%% Build long RMSE tables

D_bio = build_rmse_long( ...
    T, T_new, ...
    "OD_mse_true_vs_nn", ...
    "OD_mse_true_vs_mn", ...
    "Biomass (g/L)" ...
);

D_sub = build_rmse_long( ...
    T, T_new, ...
    "Substrate_mse_true_vs_nn", ...
    "Substrate_mse_true_vs_mn", ...
    "Substrate (g/L)" ...
);

D_do = build_rmse_long( ...
    T, T_new, ...
    "DO_mse_true_vs_nn", ...
    "DO_mse_true_vs_mn", ...
    "DO (%)" ...
);

disp(" ")
disp("============================================================")
disp("RMSE rows by feature/model")
disp("============================================================")
disp_summary(D_bio, "Biomass")
disp_summary(D_sub, "Substrate")
disp_summary(D_do, "DO")

%% Figure

fig = figure("Color", "w");
set(fig, "Units", "centimeters");
set(fig, "Position", [2 2 34 8]);

left = 0.075;
bottom = 0.20;
width = 0.255;
height = 0.62;
gap = 0.065;

ax1 = axes("Parent", fig, "Position", [left, bottom, width, height]);
draw_rmse_boxplot(ax1, D_bio, uw_order, "Biomass (g/L)", col_lstm, col_mech, col_new_mech);

ax2 = axes("Parent", fig, "Position", [left + width + gap, bottom, width, height]);
draw_rmse_boxplot(ax2, D_sub, uw_order, "Substrate (g/L)", col_lstm, col_mech, col_new_mech);
ylim(ax2, [0, 6]);
ax2.YTick = 0:2:6;
ax2.YTickLabel = string(0:2:6);

ax3 = axes("Parent", fig, "Position", [left + 2*(width + gap), bottom, width, height]);
draw_rmse_boxplot(ax3, D_do, uw_order, "DO (%)", col_lstm, col_mech, col_new_mech);
yl = ylim(ax3);
ylim(ax3, [0, yl(2)]);
ax3.YTick = 0:10:ceil(yl(2)/10)*10;
ax3.YTickLabel = string(ax3.YTick);

axes_all = [ax1, ax2, ax3];

%% Panel labels

add_panel_label(ax1, "(a)");
add_panel_label(ax2, "(b)");
add_panel_label(ax3, "(c)");

%% Shared formatting

for ax = axes_all
    xlabel(ax, "Update window (h)");
    ax.FontName = "Arial";
    ax.FontSize = 16;
    ax.LineWidth = 1.5;
    ax.TickDir = "in";
    ax.Box = "on";
    ax.XTickLabelRotation = 0;
    ax.YGrid = "on";
    ax.XGrid = "off";
    ax.GridAlpha = 0.25;
end

ylabel(ax1, "RMSE");
ylabel(ax2, "RMSE");
ylabel(ax3, "RMSE");

%% Legend

ax_leg = axes( ...
    "Parent", fig, ...
    "Position", [0.20, 0.94, 0.60, 0.080], ...
    "Visible", "off" ...
);
hold(ax_leg, "on");
axis(ax_leg, "off");

h_lstm = patch(ax_leg, NaN, NaN, col_lstm, ...
    "FaceAlpha", 0.65, ...
    "EdgeColor", "k", ...
    "DisplayName", "LSTM-EMP");

h_mech = patch(ax_leg, NaN, NaN, col_mech, ...
    "FaceAlpha", 0.65, ...
    "EdgeColor", "k", ...
    "DisplayName", "Mech-Lit model");

h_new_mech = patch(ax_leg, NaN, NaN, col_new_mech, ...
    "FaceAlpha", 0.65, ...
    "EdgeColor", "k", ...
    "DisplayName", "Mech-Refit model");

lgd = legend(ax_leg, [h_lstm, h_mech, h_new_mech], ...
    "Location", "north", ...
    "Orientation", "horizontal", ...
    "NumColumns", 3);

lgd.Box = "off";
lgd.FontSize = 16;
lgd.FontName = "Arial";

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

out_pdf = fullfile(redo_dir, "box_Validation_1x3_RMSE_matlab.pdf");

exportgraphics(fig, char(out_pdf), ...
    "ContentType", "vector", ...
    "BackgroundColor", "white");

disp("[OK] Saved:")
disp(out_pdf)

%% Local functions

function D = build_rmse_long(T, T_new, col_lstm, col_mech, feature_name)

    D = table();

    % Original LSTM model from check_mse_stats.csv
    if ismember(col_lstm, T.Properties.VariableNames)
        x = T.(col_lstm);
        valid = isfinite(x) & x >= 0;

        D1 = table();
        D1.experiment_id = T.experiment_id(valid);
        D1.update_window_min = T.update_window_min(valid);
        D1.uw_label = T.uw_label(valid);
        D1.model = repmat("LSTM-EMP", sum(valid), 1);
        D1.rmse_value = sqrt(x(valid));
        D1.feature = repmat(string(feature_name), sum(valid), 1);

        D = [D; D1];
    end

    % Original mechanistic model from check_mse_stats.csv
    if ismember(col_mech, T.Properties.VariableNames)
        x = T.(col_mech);
        valid = isfinite(x) & x >= 0;

        D2 = table();
        D2.experiment_id = T.experiment_id(valid);
        D2.update_window_min = T.update_window_min(valid);
        D2.uw_label = T.uw_label(valid);
        D2.model = repmat("Mechanistic model", sum(valid), 1);
        D2.rmse_value = sqrt(x(valid));
        D2.feature = repmat(string(feature_name), sum(valid), 1);

        D = [D; D2];
    end

    % Re-fit mechanistic model from full_new_mechanistic_check_mse_stats.csv
    % Uses the same mechanistic MSE column name as the original mechanistic model.
    if ismember(col_mech, T_new.Properties.VariableNames)
        x = T_new.(col_mech);
        valid = isfinite(x) & x >= 0;

        D3 = table();
        D3.experiment_id = T_new.experiment_id(valid);
        D3.update_window_min = T_new.update_window_min(valid);
        D3.uw_label = T_new.uw_label(valid);
        D3.model = repmat("Re-fit mechanistic model", sum(valid), 1);
        D3.rmse_value = sqrt(x(valid));
        D3.feature = repmat(string(feature_name), sum(valid), 1);

        D = [D; D3];
    end

end

function draw_rmse_boxplot(ax, D, uw_order, title_text, col_lstm, col_mech, col_new_mech)

    hold(ax, "on");

    if isempty(D)
        text(ax, 0.5, 0.5, "No finite data", ...
            "Units", "normalized", ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "middle");
        title(ax, title_text, "FontWeight", "normal");
        return
    end

    model_order = ["Mechanistic model", "LSTM-EMP", "Re-fit mechanistic model"];

    group_centers = 1:numel(uw_order);
    box_w = 0.18;
    offset = 0.20;

    for u = 1:numel(uw_order)

        uw = uw_order(u);

        for m = 1:numel(model_order)

            model_name = model_order(m);

            vals = D.rmse_value(D.uw_label == uw & D.model == model_name);
            vals = vals(isfinite(vals));

            if isempty(vals)
                continue
            end

            if model_name == "Mechanistic model"
                xpos = group_centers(u) - offset;
                face_col = col_mech;
            
            elseif model_name == "LSTM-EMP"
                xpos = group_centers(u);
                face_col = col_lstm;
            
            elseif model_name == "Re-fit mechanistic model"
                xpos = group_centers(u) + offset;
                face_col = col_new_mech;
            end

            draw_one_box(ax, xpos, vals, box_w, face_col);
        end
    end

    title(ax, title_text, "FontWeight", "normal");

    ax.XLim = [0.5, numel(uw_order) + 0.5];
    ax.XTick = group_centers;
    ax.XTickLabel = uw_order;

    % Match Python ylim:
    % yhi = percentile 97.5
    % ylim = [0, 1.10*yhi]
    yhi = prctile(D.rmse_value(isfinite(D.rmse_value)), 97.5);
    
    if isempty(yhi) || ~isfinite(yhi) || yhi <= 0
        yhi = 1.0;
    end
    
    ymax = 1.10 * yhi;
    ylim(ax, [0, ymax]);
    
    % Integer-only y ticks, similar to MaxNLocator(nbins=4)
    ytop_tick = floor(ymax);
    
    if ytop_tick <= 1
        yt = 0:1:ceil(ymax);
    elseif ytop_tick <= 4
        yt = 0:1:ytop_tick;
    elseif ytop_tick <= 8
        yt = 0:2:ytop_tick;
    elseif ytop_tick <= 15
        yt = 0:3:ytop_tick;
    else
        yt = 0:5:ytop_tick;
    end
    
    % Make sure at least 2 ticks are shown
    if numel(yt) < 2
        yt = [0, ceil(ymax)];
    end
    
    ax.YTick = yt;
    ax.YTickLabel = string(yt);

end


function draw_one_box(ax, xpos, vals, box_w, face_col)

    vals = vals(:);
    vals = vals(isfinite(vals));

    if isempty(vals)
        return
    end

    q = prctile(vals, [5, 25, 50, 75, 95]);

    whis_low = q(1);
    q25 = q(2);
    med = q(3);
    q75 = q(4);
    whis_high = q(5);

    half_w = box_w / 2;
    cap_w = box_w * 0.75;

    % Box
    patch(ax, ...
        [xpos-half_w, xpos+half_w, xpos+half_w, xpos-half_w], ...
        [q25, q25, q75, q75], ...
        face_col, ...
        "FaceAlpha", 0.65, ...
        "EdgeColor", "k", ...
        "LineWidth", 1.0);

    % Median line
    line(ax, ...
        [xpos-half_w, xpos+half_w], ...
        [med, med], ...
        "Color", "k", ...
        "LineWidth", 1.3);

    % Lower whisker
    line(ax, ...
        [xpos, xpos], ...
        [whis_low, q25], ...
        "Color", "k", ...
        "LineWidth", 1.0);

    % Upper whisker
    line(ax, ...
        [xpos, xpos], ...
        [q75, whis_high], ...
        "Color", "k", ...
        "LineWidth", 1.0);

    % Lower cap
    line(ax, ...
        [xpos-cap_w/2, xpos+cap_w/2], ...
        [whis_low, whis_low], ...
        "Color", "k", ...
        "LineWidth", 1.0);

    % Upper cap
    line(ax, ...
        [xpos-cap_w/2, xpos+cap_w/2], ...
        [whis_high, whis_high], ...
        "Color", "k", ...
        "LineWidth", 1.0);

end


function add_panel_label(ax, label_text)

    text(ax, -0.23, 1.06, label_text, ...
        "Units", "normalized", ...
        "Interpreter", "none", ...
        "FontSize", 24, ...
        "FontWeight", "bold", ...
        "FontName", "Arial", ...
        "HorizontalAlignment", "left", ...
        "VerticalAlignment", "top", ...
        "Clipping", "off");

end


function disp_summary(D, name)

    fprintf("\n%s\n", name);

    if isempty(D)
        fprintf("No finite rows.\n");
        return
    end

    G = groupsummary(D, ["uw_label", "model"], ...
        {"mean", "median", "min", "max"}, "rmse_value");

    disp(G)

end