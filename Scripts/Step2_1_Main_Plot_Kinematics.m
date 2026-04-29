function Step2_1_Main_Plot_Kinematics()
% STEP2_1_MAIN_PLOT_KINEMATICS 绘制所有案例的运动学数据 / Plot kinematic data for all cases

%% Load required data
if ~exist('info.mat', 'file')
    error('info.mat file not found in current directory');
end
load('info.mat', 'Info');

% Define directories
Dir_Project = Info(1).Dir_Project;
Dir_Data_Kinematics = fullfile(Dir_Project, 'Data', 'Kinematics');
Dir_Plot_Kinematics = fullfile(Dir_Project, 'Data', 'Plot', 'Kinematics');
if ~exist(Dir_Plot_Kinematics, 'dir')
    mkdir(Dir_Plot_Kinematics);
end

% Load processed kinematic data
kinematics_file = fullfile(Dir_Data_Kinematics, 'Kinematics_Processed.mat');
if ~exist(kinematics_file, 'file')
    error('Kinematics_Processed.mat not found in specified directory');
end
load(kinematics_file, 'mg_data');

%% Verify data consistency
if length(Info) ~= length(mg_data)
    error('Mismatch between cases in Info (%d) and mg_data (%d)', ...
          length(Info), length(mg_data));
end

%% Define plot configurations
plot_config = {
    % Field name       Y-label  Unit        Scale/1e3  Coordinate system
    'lin_acc_CG',    'LA',    '(m/s²)',    false,    'Anatomical';
    'G_lin_acc_CG',  'GLA',   '(m/s²)',    false,    'Global';
    'ang_vel',       'AV',    '(rad/s)',   false,    'Anatomical';
    'G_ang_vel',     'GAV',   '(rad/s)',   false,    'Global';
    'ang_acc',       'AA',    '(krad/s²)', true,     'Anatomical';
    'G_ang_acc',     'GAA',   '(krad/s²)', true,     'Global';
};

%% Create plots for each case
for i_Case = 1:length(mg_data)
    % Get current case data
    case_data = mg_data(i_Case);
    case_name = strrep(Info(i_Case).CaseName, '_', ' ');
    t = case_data.t * 1e3; % Convert to milliseconds
    
    % Identify available fields
    available_fields = fieldnames(case_data);
    valid_plots = {};
    
    % Check which fields exist in data
    for i = 1:size(plot_config, 1)
        if ismember(plot_config{i,1}, available_fields)
            valid_plots{end+1} = plot_config(i,:);
        end
    end
    
    if isempty(valid_plots)
        warning('No plottable fields in case %s', case_name);
        continue;
    end
    
    % Create figure
    fig = figure('Name', case_name, ...
                 'Position', [100, 100, 1200, 200*length(valid_plots)], ...
                 'Color', 'w');
    sgtitle(case_name, 'FontSize', 14, 'FontWeight', 'bold');
    
    % Set common x-axis limits
    x_lim = [min(t), max(t)];
    
    % Plot each valid field
    for row_num = 1:length(valid_plots)
        field_name = valid_plots{row_num}{1};
        y_label = valid_plots{row_num}{2};
        y_unit = valid_plots{row_num}{3};
        scale_1e3 = valid_plots{row_num}{4};
        coord_sys = valid_plots{row_num}{5};
        
        % Get data and apply scaling
        data = case_data.(field_name);
        if scale_1e3
            data = data / 1e3;
        end
        
        % Plot current field
        plot_components(length(valid_plots), row_num, t, data, ...
                       {y_label, y_unit}, x_lim, [0.94, 0.94, 0.94], coord_sys, ...
                       row_num == length(valid_plots));
    end
    
    % Adjust layout
    set(findall(fig, 'Type', 'axes'), 'FontSize', 10);
    
    % Save figure
    saveas(fig, fullfile(Dir_Plot_Kinematics, [Info(i_Case).CaseName '_kinematics.png']));
    close(fig);
end

disp('All kinematic plots generated successfully!');
end

%% Helper function to plot components
function plot_components(rows, row_num, t, data, ylabel_text, x_lim, bg_color, coord_sys, show_xlabel)
% PLOT_COMPONENTS Plot component subplots

% Define component names and colors
components = {'X', 'Y', 'Z', 'X/Y/Z/Mag'};
colors = lines(3); % Colors for X, Y, Z components
mag_color = [0.5, 0, 0.5]; % Purple for magnitude

% Calculate magnitude
magnitude = sqrt(sum(data.^2, 2));

% Handle all-zero data
combined_data = [data, magnitude];
if all(combined_data(:) == 0)
    y_lim = [-1, 1];
else
    y_min = min(combined_data(:));
    y_max = max(combined_data(:));
    y_pad = (y_max - y_min) * 0.1;
    y_lim = [y_min - y_pad, y_max + y_pad];
end

% Create subplot for each component
for i = 1:4
    subplot(rows, 4, (row_num-1)*4 + i);
    set(gca, 'Color', bg_color);
    
    hold on;
    if i < 4
        % Plot individual component
        plot(t, data(:,i), 'Color', colors(i,:), 'LineWidth', 1.5);
    else
        % 4th column: X, Y, Z and Magnitude
        plot(t, data(:,1), 'Color', colors(1,:), 'LineWidth', 1.5);
        plot(t, data(:,2), 'Color', colors(2,:), 'LineWidth', 1.5);
        plot(t, data(:,3), 'Color', colors(3,:), 'LineWidth', 1.5);
        plot(t, magnitude, 'Color', mag_color, 'LineWidth', 1.5, 'LineStyle', '-');
    end
    hold off;
    
    % Format plot
    title(sprintf('%s (%s)', components{i}, coord_sys), 'FontWeight', 'bold');
    
    if i == 1
        ylabel(ylabel_text, 'Interpreter', 'none');
    else
        ylabel('');
    end
    
    if show_xlabel
        xlabel('Time (ms)');
    else
        set(gca, 'XTickLabel', []);
    end
    
    xlim(x_lim);
    ylim(y_lim);
    grid on;
    box on;
end
end