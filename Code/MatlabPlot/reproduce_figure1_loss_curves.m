% -------------------------------------------------------------------------
% Load saved ensemble-loss data from CSV
% -------------------------------------------------------------------------

csv_file = 'figure_ensemble_loss_data.csv';

T = readtable(csv_file);

% Epochs
epochs = T.epoch;

% Median curves already stored in the CSV
train_median   = T.train_median;
subtest_median = T.subtest_median;

% Find all individual ensemble-member columns
varNames = T.Properties.VariableNames;

train_cols = startsWith(varNames, 'train_member_');
subtest_cols = startsWith(varNames, 'subtest_member_');

% Convert the selected table columns into numeric matrices:
% rows    = epochs
% columns = ensemble members
train_rmse = T{:, train_cols};
subtest_rmse = T{:, subtest_cols};

fprintf('Loaded %d epochs and %d ensemble members from CSV.\n', ...
    numel(epochs), size(train_rmse, 2));

% -------------------------------------------------------------------------
% Plot colors
% -------------------------------------------------------------------------

train_member_color   = [0.65, 0.65, 0.65, 0.25];
subtest_member_color = [0.85, 0.55, 0.55, 0.25];

black_curve = [0, 0, 0];
red_curve   = [0.80, 0.10, 0.10];

% -------------------------------------------------------------------------
% Output
% -------------------------------------------------------------------------

output_folder = pwd;
output_pdf = fullfile(output_folder, ...
    'figure_ensemble_rmse_curves_matlab.pdf');

% -------------------------------------------------------------------------
% Figure with compact layout
% -------------------------------------------------------------------------

f = figure( ...
    'Color', 'w', ...
    'Units', 'centimeters', ...
    'Position', [2, 2, 20.3, 10.5], ...
    'PaperPositionMode', 'auto');

% Compact layout controls the whitespace more reliably than manually
% modifying OuterPosition and LooseInset.
tl = tiledlayout(f, 1, 1, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

ax = nexttile(tl);
hold(ax, 'on');

% -------------------------------------------------------------------------
% Individual ensemble-member curves
% -------------------------------------------------------------------------

for member_idx = 1:size(train_rmse, 2)

    plot(ax, epochs, train_rmse(:, member_idx), ...
        '-', ...
        'Color', train_member_color, ...
        'LineWidth', 0.35, ...
        'HandleVisibility', 'off');

    plot(ax, epochs, subtest_rmse(:, member_idx), ...
        '--', ...
        'Color', subtest_member_color, ...
        'LineWidth', 0.35, ...
        'HandleVisibility', 'off');

end

% -------------------------------------------------------------------------
% Median curves
% -------------------------------------------------------------------------

h_train_median = plot(ax, epochs, train_median, ...
    '-', ...
    'Color', black_curve, ...
    'LineWidth', 1.8, ...
    'DisplayName', ...
    'Median internal training sub-dataset RMSE');

h_subtest_median = plot(ax, epochs, subtest_median, ...
    '--', ...
    'Color', red_curve, ...
    'LineWidth', 1.8, ...
    'DisplayName', ...
    'Median internal monitoring sub-dataset RMSE');

% -------------------------------------------------------------------------
% Axis limits
% -------------------------------------------------------------------------

xlim(ax, [epochs(1), epochs(end)]);
ylim(ax, [0, 0.5]);

% Remove MATLAB's default horizontal padding at the x-axis ends.
ax.XLimMode = 'manual';

% -------------------------------------------------------------------------
% Labels and appearance
% -------------------------------------------------------------------------

xlabel(ax, 'Epoch', ...
    'FontSize', 12);

ylabel(ax, 'Root Mean Squared Error', ...
    'FontSize', 12);

title(ax, ...
    ['Internal Training and Monitoring Sub-dataset RMSE ' ...
     'Across Ensemble Members'], ...
    'FontSize', 13, ...
    'FontWeight', 'normal');

set(ax, ...
    'FontName', 'Arial', ...
    'FontSize', 11, ...
    'LineWidth', 0.8, ...
    'Box', 'on', ...
    'Layer', 'top', ...
    'TickDir', 'in', ...
    'XMinorTick', 'on', ...
    'YMinorTick', 'on');

grid(ax, 'on');

ax.GridColor = [0.80, 0.80, 0.80];
ax.GridAlpha = 0.35;
ax.MinorGridAlpha = 0.15;

legend(ax, ...
    [h_train_median, h_subtest_median], ...
    'Location', 'northeast', ...
    'FontSize', 9, ...
    'Box', 'on');

% Ensure MATLAB has calculated the final text and legend extents before export.
drawnow;

% -------------------------------------------------------------------------
% Export
% -------------------------------------------------------------------------

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

if exist('exportgraphics', 'file') == 2

    % Exporting the figure preserves the specified compact aspect ratio.
    exportgraphics(f, output_pdf, ...
        'ContentType', 'vector', ...
        'BackgroundColor', 'white');

else

    set(f, ...
        'PaperUnits', 'centimeters', ...
        'PaperSize', [20.3, 10.5], ...
        'PaperPosition', [0, 0, 20.3, 10.5], ...
        'PaperPositionMode', 'manual');

    print(f, output_pdf, '-dpdf', '-painters');

end

fprintf('Saved PDF: %s\n', output_pdf);