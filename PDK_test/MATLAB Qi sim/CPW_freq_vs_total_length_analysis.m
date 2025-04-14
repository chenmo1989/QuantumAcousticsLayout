% This script deals with the frequency vs total resonator length data from
% COMSOL simulation.

% All resonators have coupling_gap = 5um, coupling_length = 150um.
clear
clc

%% Regular Claw Resonators
total_length = [5800, 5700, 5500, 5100, 4500];
freq = [4.6081, 4.6824, 4.8351, 5.1709, 5.7737];

% Polynomial degree
degree = 1;

% Fit polynomial
p2 = polyfit(total_length, freq, degree);

% Evaluate polynomial over a finer grid for smooth plotting
x_fit = linspace(min(total_length), max(total_length), 100);
y_fit = polyval(p2, x_fit);

% Create figure
figure('Color', 'w');  % white background

% Plot original data
scatter(total_length, freq, 80, 'filled', 'MarkerFaceColor', '#0072BD', ...
        'DisplayName', 'COMSOL sim (regular claw)');

hold on;

% Plot fitted curve
plot(x_fit, y_fit, 'LineWidth', 2.5, 'Color', '#D95319', ...
     'DisplayName', 'Linear Fit (regular claw)');

% Improve axes appearance
grid on;
box on;
xlabel('Total Length (\mum)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Resonator Frequency (GHz)', 'FontSize', 12, 'FontWeight', 'bold');

% Customize ticks and font
set(gca, 'FontSize', 14, 'LineWidth', 1.2, 'TickDir', 'out');

% Add legend
legend('Location', 'northeast', 'FontSize', 11);

% Optional: tight margins
axis tight;




% if I want to find the total_length for certain target frequency ft
% roots(p - [0, ft])


%% Tapered Claw Resonators
hold on

% Fit polynomial
p = polyfit([5500, 5100, 4600], [5.2663, 5.6661, 6.2647], degree);

% Evaluate polynomial over a finer grid for smooth plotting
y_fit2 = polyval(p, x_fit);

scatter([5500, 5100, 4600], [5.2663, 5.6661, 6.2647], 80, 'filled', ...
        'DisplayName', 'COMSOL sim (tapered claw)');

% Plot fitted curve
plot(x_fit, y_fit2, 'LineWidth', 2.5, ...
     'DisplayName', 'Linear Fit (tapered claw)');