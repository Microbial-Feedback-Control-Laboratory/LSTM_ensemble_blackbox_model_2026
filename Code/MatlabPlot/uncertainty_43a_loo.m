function PlotUncertainty_FromCSV()

    clear; close all; clc;

    % Use tex for more consistent MATLAB fonts.
    % If you strictly want LaTeX, change "tex" to "latex".
    set(groot, "defaultTextInterpreter", "tex");
    set(groot, "defaultAxesTickLabelInterpreter", "tex");
    set(groot, "defaultLegendInterpreter", "tex");

    %% Paths

    ver = "v10_f1";
    plotpath = "C:\Research\HybridModel\March2025\Plots";
    save_plot_path = fullfile(plotpath, "BB", ver);
    redo_dir = fullfile(save_plot_path, "RedoMatlab");

    selected_exp_id = "2024_W43_A2";
    input_history_s = 20 * 60;  % 1200 s; exclude from coverage calculation only

    curves_path = fullfile(redo_dir, "uncertainty_curves_" + selected_exp_id + "_logo.csv");
    measurements_path = fullfile(redo_dir, "uncertainty_measurements_" + selected_exp_id + "_logo.csv");
    summary_path = fullfile(redo_dir, "uncertainty_summary_validation_" + selected_exp_id + "_logo.csv");

    validation_loo_path = fullfile(redo_dir, ...
        "validation_logo_fold_results.csv");
    
    V = readtable(validation_loo_path, "TextType", "string");

    C = readtable(curves_path, "TextType", "string");
    M = readtable(measurements_path, "TextType", "string");
    S = readtable(summary_path, "TextType", "string");

    disp("[INFO] Loaded:")
    disp(curves_path)
    disp(measurements_path)
    disp(summary_path)

    %% Figure layout, same structure as attached PlotUncertainty.m

    figure("Color", "w");
    set(gcf, "Units", "centimeters");
    set(gcf, "Position", [2 2 36 22]);   % wider figure

    leftX  = 0.08;
    rightX = 0.72;                       % move right panels slightly left
    
    leftW  = 0.60;                       % slightly narrower left panels
    rightW = 0.18;                       % wider right panels

    leftH = 0.26;
    rightH = 0.38;

    feature_order = ["biomass", "substrate", "DO"];

    Cbio = C(C.feature == "biomass", :);
    Csub = C(C.feature == "substrate", :);
    CDO  = C(C.feature == "DO", :);

    Mbio = M(M.feature == "biomass", :);
    Msub = M(M.feature == "substrate", :);
    MDO  = M(M.feature == "DO", :);

    %% Left column: 3 main uncertainty panels

    ax1 = axes("Position", [leftX 0.68 leftW leftH]);
    plotuncer_from_csv(Cbio, Mbio, S, "biomass", 1);

    ax2 = axes("Position", [leftX 0.38 leftW leftH]);
    plotuncer_from_csv(Csub, Msub, S, "substrate", 0);

    ax3 = axes("Position", [leftX 0.08 leftW leftH]);
    plotuncer_from_csv(CDO, MDO, S, "DO", 3);

    %% Right column: coverage and width-ratio summaries

    ax4 = axes("Position", [rightX 0.56 rightW rightH]);
    plotCoverageValidationAndExp_from_csv( ...
        S, V, C, M, selected_exp_id, feature_order, input_history_s);

    ax5 = axes("Position", [rightX 0.08 rightW rightH]);
    plotWidthRatioSummary_from_csv(V, feature_order);
    ylim(ax5, [0 2.2]);

    %% Remove MATLAB toolbar icons before saving

    all_axes = findall(gcf, "Type", "axes");

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

    out_pdf = fullfile(redo_dir, "matlab_uncertainty_" + selected_exp_id + "_loo.pdf");

    exportgraphics(gcf, char(out_pdf), ...
        "ContentType", "vector", ...
        "BackgroundColor", "white");

    disp("[OK] Saved figure:")
    disp(out_pdf)

end


function plotuncer_from_csv(Tvar, Mvar, S, varName, flg)

    if isempty(Tvar)
        warning("Input curve table is empty for %s. No plot generated.", varName);
        return;
    end

    Tvar = sortrows(Tvar, "ProcTime_h");

    % Get qhat and summary values for this feature
    srow = S(S.feature == varName, :);

    if isempty(srow)
        warning("No summary row found for %s.", varName);
        qhat = NaN;
        rawCoverage = NaN;
        confCoverage = NaN;
        rawWidth = NaN;
        confWidth = NaN;
    else
        qhat = srow.qhat(1);
        rawCoverage = srow.raw_coverage(1);
        confCoverage = srow.conformal_coverage(1);
        rawWidth = srow.mean_raw_width(1);
        confWidth = srow.mean_conformal_width(1);
    end

    % Extract curve data
    t = Tvar.ProcTime_h;

    rawLower = Tvar.pred_q05;
    rawUpper = Tvar.pred_q95;
    q50 = Tvar.pred_median;
    rawWidth_exp = mean(rawUpper - rawLower, "omitnan");
    confWidth_exp = mean((rawUpper - rawLower) + 2 * qhat, "omitnan");

    confLower = rawLower - qhat;
    confUpper = rawUpper + qhat;

    % Clip negative lower bounds for visualization only
    rawLowerPlot = rawLower;
    confLowerPlot = confLower;

    if varName == "biomass" || varName == "substrate" || varName == "DO"
        rawLowerPlot = max(rawLowerPlot, 0);
        confLowerPlot = max(confLowerPlot, 0);
    end

    hold on;
    box off;

    % --- Conformal-calibrated interval ---
    fill([t; flipud(t)], ...
         [confLowerPlot; flipud(confUpper)], ...
         [0.85 0.85 0.85], ...
         "EdgeColor", "none", ...
         "FaceAlpha", 0.60, ...
         "DisplayName", "Conformal-calibrated 90% interval");

    % --- Raw LSTM 5--95% ensemble interval ---
    fill([t; flipud(t)], ...
         [rawLowerPlot; flipud(rawUpper)], ...
         [0.95 0.55 0.10], ...
         "EdgeColor", "none", ...
         "FaceAlpha", 0.45, ...
         "DisplayName", "LSTM 5-95% ensemble interval");

    % --- Median LSTM prediction ---
    % --- Median LSTM prediction ---
    h_med = plot(t, q50, "--", ...
         "Color", [0.80 0.10 0.10], ...
         "LineWidth", 1.6, ...
         "DisplayName", "LSTM-EMP");
    
    % Add transparency if MATLAB version supports RGBA colors
    try
        h_med.Color = [0.80 0.10 0.10 0.75];
    catch
    end

    % --- Measurements ---
    if ~isempty(Mvar)
        Mvar = sortrows(Mvar, "measurement_time_h");

        if varName == "substrate"
            markerSize = 30;
            markerLineWidth = 1.5;
        else
            markerSize = 5;          % smaller for biomass and DO
            markerAlpha = 0.3;      % more transparent for dense measurements
            markerLineWidth = 0.6;
        end
        
        sc = scatter(Mvar.measurement_time_h, Mvar.measurement, ...
            markerSize, ...
            "MarkerFaceColor", "none", ...
            "MarkerEdgeColor", "k", ...
            "LineWidth", markerLineWidth, ...
            "DisplayName", "Measurements");
        
        try
            sc.MarkerEdgeAlpha = markerAlpha;
        catch
        end
    end

    xlim([0 10.6]);

    if flg == 3
        xlabel("Time [h]");
        set(gca, "YTick", 0:50:100);
    else
        set(gca, "XTickLabel", []);
    end

    switch varName
        case "biomass"
            ylabel("Biomass [g/L]");
        case "substrate"
            ylabel("Substrate [g/L]");
        case "DO"
            ylabel("DO [%]");
        otherwise
            ylabel(varName);
    end
    ax = gca;
    ax.YLabel.Units = "normalized";
    ax.YLabel.Position(1) = -0.055;

    % Legend only on top panel, same as attached style
    if flg == 1
        lgd = legend( ...
            "Conformal-calibrated 90% interval", ...
            "LSTM 5-95% ensemble interval", ...
            "LSTM-EMP", ...
            "Measurements", ...
            "Location", "northwest", ...
            "Box", "off", ...
            "FontSize", 12);
    
        % Move legend up slightly
        lgd.Units = "normalized";
        lgd.Position(2) = lgd.Position(2) + 0.035;
    end

    grid off;
    set(gca, "FontSize", 12);
    set(gca, "TickDir", "in");
    set(gca, "LineWidth", 1.2);

    %% Inset bar plot: raw vs conformal mean interval width

    mainAx = gca;
    pos = mainAx.Position;

    insetPos = [ ...
        pos(1) + 0.01 * pos(3), ...
        pos(2) + 0.15 * pos(4), ...
        0.20 * pos(3), ...
        0.25 * pos(4)];

    if flg == 1
        insetPos = [ ...
            pos(1) + 0.01 * pos(3), ...
            pos(2) + 0.30 * pos(4), ...
            0.20 * pos(3), ...
            0.25 * pos(4)];
    end

    insetAx = axes("Position", insetPos);

    barValues = [rawWidth_exp, confWidth_exp];

    bar(insetAx, barValues, ...
        "FaceColor", [0.45 0.45 0.45], ...
        "EdgeColor", "k", ...
        "LineWidth", 0.8);

    set(insetAx, ...
        "XTick", 1:2, ...
        "XTickLabel", ["Raw", "Conf"], ...
        "FontSize", 9, ...
        "YTick", [], ...
        "YTickLabel", []);

    insetAx.YAxis.Visible = "off";

    text(insetAx, 1:2, barValues, ...
        compose("%.1f", barValues), ...
        "HorizontalAlignment", "center", ...
        "VerticalAlignment", "bottom", ...
        "FontSize", 9);

    grid(insetAx, "off");
    box(insetAx, "off");

end


function plotCoverageSummary_from_csv(S, feature_order)

    S = sort_summary_by_feature(S, feature_order);
    V = sort_summary_by_feature(V, feature_order);

    x = 1:numel(feature_order);

    rawCov = 100 * S.raw_coverage;
    confCov = 100 * S.conformal_coverage;

    barW = 0.38;

    hold on;
    box off;

    bar(x - barW/2, rawCov, barW, ...
        "FaceColor", [0.95 0.55 0.10], ...
        "FaceAlpha", 0.85, ...
        "EdgeColor", "k", ...
        "LineWidth", 1.0, ...
        "DisplayName", "Raw");

    bar(x + barW/2, confCov, barW, ...
        "FaceColor", [0.25 0.25 0.25], ...
        "FaceAlpha", 0.65, ...
        "EdgeColor", "k", ...
        "LineWidth", 1.0, ...
        "DisplayName", "Calibrated");

    yline(90, "k--", ...
        "LineWidth", 1.2, ...
        "DisplayName", "Nominal 90%");

    set(gca, ...
        "XTick", x, ...
        "XTickLabel", ["Biomass", "Substrate", "DO"], ...
        "FontSize", 12, ...
        "TickDir", "in", ...
        "LineWidth", 1.2);

    ylabel("Coverage [%]");
    ylim([0 105]);
    title("Measurement coverage across validation");

    grid on;
    ax = gca;
    ax.GridAlpha = 0.25;
    ax.YGrid = "on";
    ax.XGrid = "off";

    legend("Location", "southeast", "Box", "off", "FontSize", 10);

    for i = 1:numel(x)
        text(x(i) - barW/2, rawCov(i) + 2, sprintf("%.1f", rawCov(i)), ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "bottom", ...
            "FontSize", 9);

        text(x(i) + barW/2, confCov(i) + 2, sprintf("%.1f", confCov(i)), ...
            "HorizontalAlignment", "center", ...
            "VerticalAlignment", "bottom", ...
            "FontSize", 9);
    end

end

function plotWidthRatioSummary_from_csv(V, feature_order)

    numberOfFeatures = numel(feature_order);

    meanConformalWidth = nan(numberOfFeatures, 1);
    meanRawWidth = nan(numberOfFeatures, 1);
    ratios = nan(numberOfFeatures, 1);

    % Calculate feature-level mean widths first, then calculate their ratio.
    for i = 1:numberOfFeatures

        featureRows = V.feature == feature_order(i);

        meanConformalWidth(i) = mean( ...
            V.mean_conformal_width_full_curve(featureRows), ...
            "omitnan");

        meanRawWidth(i) = mean( ...
            V.mean_raw_width_full_curve(featureRows), ...
            "omitnan");

        if isfinite(meanRawWidth(i)) && meanRawWidth(i) > 0
            ratios(i) = ...
                meanConformalWidth(i) / meanRawWidth(i);
        end

    end

    x = (1:numberOfFeatures) * 1.65;

    hold on;
    box off;

    bar(x, ratios, 0.65, ...
        "FaceColor", [0.25 0.25 0.25], ...
        "FaceAlpha", 0.65, ...
        "EdgeColor", "k", ...
        "LineWidth", 1.0);

    yline(1.0, "k--", ...
        "LineWidth", 1.0);

    set(gca, ...
        "XTick", x, ...
        "XTickLabel", ["Biomass", "Substrate", "DO"], ...
        "FontSize", 11, ...
        "TickDir", "in", ...
        "LineWidth", 1.2);

    ylabel("Width ratio\newline Cal. / raw");
    title("Relative interval width");
    ylim([0 3]);

    grid on;

    ax = gca;
    ax.GridAlpha = 0.25;
    ax.YGrid = "on";
    ax.XGrid = "off";

    for i = 1:numberOfFeatures

        if isfinite(ratios(i))

            text(x(i), ratios(i) + 0.05, ...
                sprintf("%.2f", ratios(i)), ...
                "HorizontalAlignment", "center", ...
                "VerticalAlignment", "bottom", ...
                "FontSize", 9);

        end

    end

end


function S_sorted = sort_summary_by_feature(S, feature_order)

    idx_all = [];

    for i = 1:numel(feature_order)
        idx = find(S.feature == feature_order(i));
        idx_all = [idx_all; idx(:)];
    end

    S_sorted = S(idx_all, :);

end

function idx = nearest_indices_matlab(src_t, query_t)

    src_t = double(src_t(:));
    query_t = double(query_t(:));

    idx = nan(size(query_t));

    for i = 1:numel(query_t)
        [~, idx(i)] = min(abs(src_t - query_t(i)));
    end

end

function plotCoverageValidationAndExp_from_csv(S, V, C, M, selected_exp_id, feature_order, input_history_s)

    S = sort_summary_by_feature(S, feature_order);

    % Use wider feature spacing
    x = (1:numel(feature_order));

    % Validation coverage:
    % first average experiment-level coverage within each feature.
    valRaw = nan(numel(feature_order), 1);
    valCal = nan(numel(feature_order), 1);
    
    for i = 1:numel(feature_order)
    
        featureRows = V.feature == feature_order(i);
    
        valRaw(i) = mean( ...
            V.raw_coverage_percent(featureRows), ...
            "omitnan");
    
        valCal(i) = mean( ...
            V.logo_conformal_coverage_percent(featureRows), ...
            "omitnan");
    
    end

    % Selected-exp coverage calculated from selected-exp measurements
    expRaw = nan(numel(feature_order), 1);
    expCal = nan(numel(feature_order), 1);

    for i = 1:numel(feature_order)

        feature = feature_order(i);

        d = C(C.feature == feature & C.experiment_id == selected_exp_id, :);
        m = M(M.feature == feature & M.experiment_id == selected_exp_id, :);

        % Exclude input-history measurements from coverage calculation only.
        % Measurements before 1200 s are still plotted in the left panels.
        m = m(m.measurement_time_s >= input_history_s, :);

        if isempty(d) || isempty(m)
            continue
        end

        d = sortrows(d, "ProcTime_s");
        m = sortrows(m, "measurement_time_s");

        pred_t = d.ProcTime_s;
        meas_t = m.measurement_time_s;

        idx = nearest_indices_matlab(pred_t, meas_t);

        q05_at_meas = d.pred_q05(idx);
        q95_at_meas = d.pred_q95(idx);
        y_meas = m.measurement;

        qhat_i = S.qhat(i);

        rawCovered = y_meas >= q05_at_meas & y_meas <= q95_at_meas;
        calCovered = y_meas >= (q05_at_meas - qhat_i) & y_meas <= (q95_at_meas + qhat_i);

        expRaw(i) = 100 * mean(rawCovered, "omitnan");
        expCal(i) = 100 * mean(calCovered, "omitnan");

    end

    hold on;
    box off;

    % Wider bars
    % Four bars per feature. Keep current bar width but increase within-group offsets.
    barW = 0.16;
    barGap = 1 * barW;
    
    x_val_raw = x - 1.5 * barGap;
    x_val_cal = x - 0.5 * barGap;
    x_exp_raw = x + 0.5 * barGap;
    x_exp_cal = x + 1.5 * barGap;

    colRaw = [0.95 0.55 0.10];
    colCal = [0.25 0.25 0.25];

    % Validation raw
    bar(x_val_raw, valRaw, barW, ...
        "FaceColor", colRaw, ...
        "FaceAlpha", 0.65, ...
        "EdgeColor", "k", ...
        "LineWidth", 1.0, ...
        "DisplayName", "Val. raw");

    % Validation calibrated
    bar(x_val_cal, valCal, barW, ...
        "FaceColor", colCal, ...
        "FaceAlpha", 0.65, ...
        "EdgeColor", "k", ...
        "LineWidth", 1.0, ...
        "DisplayName", "Val. cal.");

    % Selected experiment raw
    bar(x_exp_raw, expRaw, barW, ...
        "FaceColor", colRaw, ...
        "FaceAlpha", 0.30, ...
        "EdgeColor", "k", ...
        "LineWidth", 1.0, ...
        "DisplayName", "Exp. raw");

    % Selected experiment calibrated
    bar(x_exp_cal, expCal, barW, ...
        "FaceColor", colCal, ...
        "FaceAlpha", 0.30, ...
        "EdgeColor", "k", ...
        "LineWidth", 1.0, ...
        "DisplayName", "Exp. cal.");

    yline(90, "k--", ...
        "LineWidth", 1.2, ...
        "DisplayName", "Nominal 90%");

    set(gca, ...
        "XTick", x, ...
        "XTickLabel", ["Biomass", "Substrate", "DO"], ...
        "FontSize", 12, ...
        "TickDir", "in", ...
        "LineWidth", 1.2);
    
    xlim([0.25, numel(feature_order) + 0.35]);
    ylabel("Coverage [%]");
    ylim([0 105]);
    title("Measurement coverage");

    grid on;
    ax = gca;
    ax.GridAlpha = 0.25;
    ax.YGrid = "on";
    ax.XGrid = "off";

    % legend("Location", "northeast", "Box", "off", "FontSize", 8);
    lgd = legend("Box", "off", "FontSize", 8);
    lgd.Units = "normalized";
    lgd.Position = [0.91, 0.63, 0.08, 0.10];

    % Numeric labels
    allX = [x_val_raw; x_val_cal; x_exp_raw; x_exp_cal];
    allY = [valRaw'; valCal'; expRaw'; expCal'];

    for r = 1:size(allX, 1)
        for c = 1:size(allX, 2)
            if isfinite(allY(r, c))
                text(allX(r, c), allY(r, c) + 2, sprintf("%.0f", allY(r, c)), ...
                    "HorizontalAlignment", "center", ...
                    "VerticalAlignment", "bottom", ...
                    "FontSize", 7);
            end
        end
    end

end