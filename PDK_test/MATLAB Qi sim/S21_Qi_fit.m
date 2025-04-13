function [fr_fit, Qc_fit, Ql_fit] = S21_Qi_fit(freq, S21_complex, varargin)
%% Define the model function
% Define the error function (real + imag components)
error_fun = @(p) [real(S21_model(p, freq)) - real(S21_complex);
    imag(S21_model(p, freq)) - imag(S21_complex)];

% Units: ns, GHz
% Initial parameter guess: [a, alpha, tau, Ql, Qc, phi, fr]
if length(varargin) >= 1
    p0 = varargin{1};
else
    p0 = [1, 0, 1, 2200, 1000, 0, 5.6142];
end

% Fit using lsqnonlin (requires Optimization Toolbox)
options = optimoptions('lsqnonlin', 'Display', 'off', 'MaxFunctionEvaluations', 1e5);
[p_fit, ~] = lsqnonlin(error_fun, p0, [], [], options);

% Extract parameters
a_fit      = p_fit(1);
alpha_fit  = p_fit(2);
tau_fit    = p_fit(3);
Ql_fit     = p_fit(4);
Qc_fit     = p_fit(5);
phi_fit    = p_fit(6);
fr_fit     = p_fit(7);

% Generate fit
S21_fit = S21_model(p_fit, freq);

% Print fitting parameters
% header
fprintf('\n%-10s %12s %12s\n', 'Parameter', 'Initial', 'Fitted');
fprintf('%s\n', repmat('-', 1, 52));
% parameters
% Define labels
param_names = {'a', ...
    'α (rad)', ...
    'τ (ns)', ...
    'Q_l', ...
    'Q_c', ...
    'φ (rad)', ...
    'f_r (GHz)'};

% Print each parameter
for k = 1:length(param_names)
    fprintf('%-10s %12.5g %12.5g\n', param_names{k}, p0(k), p_fit(k));
end

% Optional: compute derived quantities
fprintf('\nDerived quantities:\n');
fprintf('  Q_i   = %12.5g\n', 1./(1./Ql_fit - 1./real(Qc_fit)));

%% Plot results
figure('Color', 'w');  % white background

% Subplot 1: Magnitude
subplot(1, 2, 1);
plot(freq, 20*log10(abs(S21_complex)), 'b.', 'MarkerSize', 8); hold on;
plot(freq, 20*log10(abs(S21_fit)), 'r-', 'LineWidth', 1.5);
xlabel('Frequency (GHz)', 'FontSize', 12);
ylabel('|S_{21}| (dB)', 'FontSize', 12);
title('Magnitude Fit', 'FontSize', 14);
legend('Data', 'Fit', 'Location', 'southeast');
grid on;
set(gca, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out');

% Subplot 2: Complex Plane (IQ Plot)
subplot(1, 2, 2);
scatter(real(S21_complex), imag(S21_complex), 25, ...
    'filled', 'MarkerFaceColor', [0.2 0.4 0.8], 'MarkerEdgeColor', 'k'); hold on;
plot(real(S21_fit), imag(S21_fit), 'r-', 'LineWidth', 1.5);
axis equal;
grid on; box on;

% Axis limits with padding
padding = 0.05;
xlims = [min(real(S21_complex)), max(real(S21_complex))];
ylims = [min(imag(S21_complex)), max(imag(S21_complex))];
xrange = diff(xlims); yrange = diff(ylims);
xlim([xlims(1)-padding*xrange, xlims(2)+padding*xrange]);
ylim([ylims(1)-padding*yrange, ylims(2)+padding*yrange]);

xlabel('Re(S_{21})', 'FontSize', 12);
ylabel('Im(S_{21})', 'FontSize', 12);
title('S_{21} in Complex Plane', 'FontSize', 14);
legend('Data', 'Fit', 'Location', 'southeast');
set(gca, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out');

% Optional: Tight layout
set(gcf, 'Position', [100, 100, 1200, 400]);

%% Define the model
% based on Probst et al.
    function S21_out = S21_model(p,f)
        % p(1): a, total attenuation of line
        % p(2): alpha, global spurious phase shift
        % p(3): tau, electrical delay
        % p(4): Ql, real valued loaded Q (total quality factor)
        % p(5): Qc, complex valued coupling quality factor
        % p(6): phi, phase factor for Qc, describing the asymmetry in hanger
        % response
        % p(7): fr, resonance frequency
        S21_out = p(1) * exp(1i * p(2)) .* exp(-2i * pi * f * p(3)) .* ...
            (1 - ( (p(4) / abs(p(5))) * exp(1i * p(6)) ) ./ ...
            (1 + 2i * p(4) .* (f / p(7) - 1)));
    end
end