clear;
%% ------------项目介绍 / Project Introduction ---------------
% 本项目基于 LS-DYNA 进行大批量的头部撞击大脑冲击响应有限元模拟。  
% 输入：头部刚体运动（平移和旋转，共六个自由度的时间序列）。  
% 输出：大脑冲击响应（应变、应变率等）。  
%
% 北航 创伤性脑损伤生物力学研究团队 
% 联系邮箱：yuzheliu@buaa.edu.cn  

% This project conducts large-scale finite element simulations of brain impact responses based on LS-DYNA.  
%
% **Input**: Rigid-body motion of the head (translation and rotation, six degrees of freedom time series).  
% **Output**: Brain impact responses (e.g., strain, strain rate, etc.).  
%
% Lab of Traumatic Brain Injury (TBI) Biomechanics, Beihang University  
% **Contact Email**: yuzheliu@buaa.edu.cn  
%% ------------脚本简介 / Script Overview ---------------
% **版本**：Version 20250129_Egge  
% 本脚本是对仿真结果进行总结，在空间尺度上简化，得到一条时间序列曲线
%The script summarizes the simulation results by simplifying them in the spatial scale, and produces a time-series curve.
%% ------------脚本主体 / Script Execution --------------- 

import tools_functions.*

%% Load Info
p = load('info.mat');  % 加载包含项目信息的.mat文件
Info = p.Info;         % 从加载的结构中提取Info信息

%% Directory
Dir_Project = Info(1).Dir_Project;  % 获取项目目录路径

% 设置不同文件夹路径
Dir_Scripts = strcat(Dir_Project, '\Scripts');  
Dir_Data_Results_Field = strcat(Dir_Project, '\Data\Results\Field');  
Dir_Data_Results_Field_space = strcat(Dir_Project, '\Data\Results\Field_space');  

% 如果存储空间目录不存在，则创建该目录
if ~exist(Dir_Data_Results_Field_space, 'dir')
    mkdir(Dir_Data_Results_Field_space);  
end

%% Select Fringe
p = load('Fringe.mat');  % 加载包含Fringe信息的.mat文件
Fringe = p.Fringe;       % 从加载的结构中提取Fringe数据

% 设置需要读取的Fringe ID列表
id_Fringe_read = [...
    5;  ... MPS
    10; ... MPSR
    34; ... Velocity X
    35; ... Velocity Y
    36; ... Velocity Z
    43; ... Coordinate X
    44; ... Coordinate Y
    45; ... Coordinate Z
];

num_Fringe = length(id_Fringe_read);  % 选择的Fringe数量

%% Select id Case
id_Case = 1:length(Info);  % 选择所有案例
num_Case = length(id_Case);  % 案例数量

% 循环遍历每个Fringe
for i = 1:num_Fringe
    id_Fringe = id_Fringe_read(i);  % 获取当前Fringe ID

    % 生成存储空间结果的文件路径
    File_Field_Space = strcat(Dir_Data_Results_Field_space, '\', Fringe(id_Fringe).Name, '_Space.mat');
    
    DataFEM_Space = struct([]);  % 初始化存储空间数据的结构体

    % 循环遍历每个案例
    for j = 1:num_Case
        id_Case_0 = id_Case(j);  % 获取当前案例ID
        
        %% Load Field 
        % 生成当前案例的结果文件路径
        File_Field = strcat(Dir_Data_Results_Field, '\', Fringe(id_Fringe).Name, '\', Fringe(id_Fringe).Name, '_', Info(id_Case_0).CaseName, '.mat');
        p = load(File_Field);  % 加载案例文件
        DataFEM = p.DataFEM;   % 从文件中提取DataFEM数据
        
        DataFEM_Space(j).t = DataFEM.t;  % 保存当前案例的时间数据
        
        %% 处理空间数据（Whole Brain）
        % 计算峰值（Peak）
        DataFEM_Space(j).SpacePeak = max(DataFEM.Field, [], 2);
        
        % 计算95百分位数（95%）
        DataFEM_Space(j).Space95 = prctile(DataFEM.Field, 95, 2);
        
        % 计算50百分位数（50%）
        DataFEM_Space(j).Space50 = prctile(DataFEM.Field, 50, 2);
        
        % 计算均值（Mean）
        DataFEM_Space(j).SpaceMean = mean(DataFEM.Field, 2);  
        
    end
    
    % 保存计算结果到.mat文件
    save(File_Field_Space, 'DataFEM_Space');
end
