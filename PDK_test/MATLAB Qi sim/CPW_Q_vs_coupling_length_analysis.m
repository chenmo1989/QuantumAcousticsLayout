% this analysis deals with all simple CPW COMSOL simulations with
% coupling_gap = 5um, and varying coupling_length
clear
close all
clc

% % main 
[sorted_filenames, coupling_length] = extract_filenames_and_coupling_strength();

Ql_guess = [2000, 2100, 1800,2200,2200,2200,2400,1900];
fr_guess = [5.6217, 5.61635, 5.6165, 5.6142, 5.6073, 5.5974, 5.5868, 5.5691];

Qc_fit = zeros(size(Ql_guess));
fr_fit = Qc_fit;

% processing
% for hlp = 2
for hlp = 1:length(coupling_length)
    T = readtable(sorted_filenames{hlp});
    freq = T.Var1;
    S21_complex = T.Var2;
    [fr_fit1, Qc_fit1] = S21_Qi_fit(freq, S21_complex, [1, 0, 1, Ql_guess(hlp), 1000, 0, fr_guess(hlp)]);
    Qc_fit(hlp) = Qc_fit1;
    fr_fit(hlp) = fr_fit1;
end

S21_fit_plot(coupling_length, Qc_fit, fr_fit)


% % functions

function S21_fit_plot(coupling_length, Qc_fit, fr_fit)
% generate the fit for S21 analysis
figure('Color', 'w', 'Position', [100, 100, 1000, 400]);
% Subplot 1: Qc
subplot(1, 2, 1);
plot(coupling_length, Qc_fit, 'o-', ...
    'LineWidth', 1.5, ...
    'MarkerSize', 6, ...
    'MarkerFaceColor', [0.2 0.4 0.8], ...
    'MarkerEdgeColor', 'k');
grid on; box on;
xlabel('Coupling Length (\mum)', 'FontSize', 12);
ylabel('Q_c', 'FontSize', 12);
title('Inverse Coupling Quality Factor', 'FontSize', 14);
set(gca, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out', 'YScale', 'log', 'XScale', 'log');

% % exp fit
% hold on
% s21_exp_phenomenon_fit(coupling_length, Qc_fit)

% Subplot 2: Resonant Frequency
subplot(1, 2, 2);
plot(coupling_length, fr_fit, 's-', ...
    'LineWidth', 1.5, ...
    'MarkerSize', 6, ...
    'MarkerFaceColor', [0.8 0.2 0.2], ...
    'MarkerEdgeColor', 'k');
grid on; box on;
xlabel('Coupling Length (\mum)', 'FontSize', 12);
ylabel('Resonant Frequency f_r (GHz)', 'FontSize', 12);
title('Resonant Frequency', 'FontSize', 14);
set(gca, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out');


    function s21_exp_phenomenon_fit(coupling_length, Qc_fit)
        % Exponential fit as a phenomenological model

        model = @(p, x) p(1) * exp(-p(2) * x) + p(3);

        % Initial guess
        p0 = [1e7, 1/300, 0];

        % Fit using lsqcurvefit
        p_fit = lsqcurvefit(model, p0, coupling_length, Qc_fit);

        % Generate fitted curve
        x_fit = linspace(min(coupling_length), max(coupling_length), 100)';
        y_fit = model(p_fit, x_fit);

        % Plot
        plot(x_fit, y_fit, 'r-', 'LineWidth', 1.5);
        %legend('Data', sprintf('Fit: a=%.3f, b=%.3f', a, b), 'Location', 'northwest');
        %xlabel('x'); ylabel('y');
        %title('Exponential Fit: y = a \cdot exp(bx)');
        %grid on;
    end

end

function [sorted_filenames, coupling_length] = extract_filenames_and_coupling_strength()
% data files
% Step 1: Get all matching *.txt files
files = dir('*_*.txt');
filenames = {files.name};

% Step 2: Extract the number before 'um' in each filename
pattern = '_([\d]+)um\.txt$';  % regex to match '_xxum.txt' or '_xxxum.txt'
nums = zeros(size(filenames));

for k = 1:length(filenames)
    tokens = regexp(filenames{k}, pattern, 'tokens');
    if ~isempty(tokens)
        nums(k) = str2double(tokens{1}{1});  % extract and convert to number
    else
        nums(k) = NaN;  % if pattern doesn't match
    end
end

% Step 3: Sort filenames by extracted number
[coupling_length, sort_idx] = sort(nums, 'ascend', 'MissingPlacement', 'last');
sorted_filenames = filenames(sort_idx);

% Remove entries where pattern didn't match
sorted_filenames(isnan(coupling_length)) = [];

end