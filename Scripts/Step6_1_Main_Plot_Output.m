
% PLOT_FRINGE_WITH_KINEMATICS 创建包含边缘数据和运动学数据的综合可视化图表

%% 初始化并加载数据
clc; close all;

% 加载必要的mat文件
if ~exist('Info.mat', 'file') || ~exist('Fringe.mat', 'file')
    error('未找到必要的文件(Info.mat或Fringe.mat)');
end
load('Info.mat', 'Info');
load('Fringe.mat', 'Fringe');

% 选择要绘制的边缘数据类型（默认选择MPS）
id_Fringe_read = [5];  % 5对应MPS
num_Fringe = length(id_Fringe_read);

%% 设置目录路径
Dir_Project = Info(1).Dir_Project;
Dir_Data = fullfile(Dir_Project, 'Data');
Dir_Kinematics = fullfile(Dir_Data, 'Kinematics');

%% 检查并加载运动学数据
kinematics_file = fullfile(Dir_Kinematics, 'Kinematics_Processed.mat');
if exist(kinematics_file, 'file')
    load(kinematics_file, 'mg_data');
    has_kinematics = true;
else
    has_kinematics = false;
    warning('未找到运动学数据文件，将跳过运动学绘图');
end

%% 处理所有案例
for i_F = 1:num_Fringe
    fringe_name = Fringe(id_Fringe_read(i_F)).Name;
    
    % 创建输出目录
    Dir_Results_Field = fullfile(Dir_Data, 'Results', 'Field', fringe_name);
    Dir_Plot = fullfile(Dir_Data, 'Plot', fringe_name);
    if ~exist(Dir_Plot, 'dir')
        mkdir(Dir_Plot);
    end
    
    for i_Case = 1:length(Info)
        case_name = Info(i_Case).CaseName;
        
        % 加载边缘数据
        fringe_file = fullfile(Dir_Results_Field, [fringe_name '_' case_name '.mat']);
        if ~exist(fringe_file, 'file')
            warning('案例 %s 的边缘数据未找到', case_name);
            continue;
        end
        load(fringe_file, 'DataFEM');
        
        % 创建图表
        fig = figure('Name', sprintf('%s - %s', fringe_name, case_name), ...
                    'Position', [0, 0, 1600, 1000], ...
                    'Color', 'w');
        
        %% 第一部分：边缘数据可视化
        % 使用4x4网格布局：
        % [1  2  3  4]
        % [9 10 13 14]
        % [11 12 15 16]
        % [13 14 15 16]
        
        % 1. 主图：边缘数据二维图（左上区域，占据[1 2 5 6]）
        subplot(4, 4, [1 2 5 6]);
        imagesc(DataFEM.Field);
        colormap(jet);
        cb = colorbar;
        cb.Label.String = fringe_name;
        title(sprintf('%s (时间×空间分布)', fringe_name), 'FontWeight', 'bold');
        xlabel('空间节点');
        ylabel('时间步');
        ax=gca;
        x_ax_1_Position=ax.Position;

        
        % 2. 左下区域：时间维度95百分位数（x轴为空间，）
        subplot(4, 4, [9 10 13 14]);
        temporal_quantile = quantile(DataFEM.Field, 0.95, 1);
        h_1=plot(1:length(temporal_quantile), temporal_quantile, 'r', 'LineWidth', 2); % x轴为空间节点
        h_1.Color(4)=0.5;
        grid on;
        title('空间维度95百分位数', 'FontWeight', 'bold');
        xlabel('空间节点');
        ylabel(fringe_name);
        xlim([1, length(temporal_quantile)]);
        ax=gca;
        ax.Position([1,3])=x_ax_1_Position([1,3]);
        ax.Position(4)=0.32;

        hold on;
        smoothed_quantile = smoothdata(temporal_quantile, 'gaussian', 50); % 使用高斯窗平滑，窗口大小为20
        h_s=plot(1:length(temporal_quantile), smoothed_quantile, 'b', 'LineWidth', 1.5); 
        h_s.Color=[0,0,0]
        hold off;


%         0.3628 0.3768
  
        
        % 3. 右上区域：空间维度95百分位数（x轴为时间，）
        subplot(4, 4, [3 4 7 8]);
        spatial_quantile = quantile(DataFEM.Field, 0.95, 2);
        plot(DataFEM.t, spatial_quantile, 'b', 'LineWidth', 2); % x轴为时间
        grid on;
        title('时间维度95百分位数', 'FontWeight', 'bold');
        xlabel('时间 (ms)');
        ylabel(fringe_name);
        xlim([min(DataFEM.t), max(DataFEM.t)]);
        
        % 4. 留空区域（位置[7 8 11 12]）
        subplot(4, 4, [11 12 15 16]);
        axis off;
        
        %% 第二部分：运动学数据可视化（右下区域，位置[13 14 15 16]）
        if has_kinematics && i_Case <= length(mg_data)
            % 定义运动学参数和位置映射
            kin_config = {
                'ang_vel',    '局部角速度',  'rad/s',    11;
                'G_ang_vel',  '全局角速度',  'rad/s',    12;
                'ang_acc',    '局部角加速度', 'krad/s²', 15;
                'G_ang_acc',  '全局角加速度', 'krad/s²', 16;
            };
            
            for k = 1:4
                field = kin_config{k,1};
                subplot(4, 4, kin_config{k,4}); % 使用配置中的位置
                
                if isfield(mg_data(i_Case), field)
                    data = mg_data(i_Case).(field);
                    if contains(field, 'ang_acc')
                        data = data / 1e3; % 角加速度缩放
                    end
                    
                    % 计算幅值
                    magnitude = sqrt(sum(data.^2, 2));
                    
                    % 绘制曲线
                    hold on;
                    plot(mg_data(i_Case).t, data(:,1), 'Color', [0, 0.4470, 0.7410], 'LineWidth', 1.5); % X
                    plot(mg_data(i_Case).t, data(:,2), 'Color', [0.8500, 0.3250, 0.0980], 'LineWidth', 1.5); % Y
                    plot(mg_data(i_Case).t, data(:,3), 'Color', [0.9290, 0.6940, 0.1250], 'LineWidth', 1.5); % Z
                    plot(mg_data(i_Case).t, magnitude, 'Color', [0.4940, 0.1840, 0.5560], 'LineWidth', 2, 'LineStyle', '--'); % 幅值
                    hold off;
                    
                    % 设置图表格式
                    title(kin_config{k,2}, 'FontWeight', 'bold');
                    xlabel('时间 (ms)');
                    ylabel(kin_config{k,3});
                    grid on;
                    box on;
                end
            end
            
            % 添加共享图例
            legend({'X分量', 'Y分量', 'Z分量', '幅值'}, ...
                  'Orientation', 'horizontal', ...
                  'Position', [0.3 0.02 0.4 0.03]);
        end
        
        ShowName=case_name;
        ShowName(ShowName=='_')=' ';
        sgtitle(ShowName);
        %% 保存图表
        saveas(fig, fullfile(Dir_Plot, sprintf('%s_%s.png', fringe_name, case_name)));
        close(fig);
    end
end

