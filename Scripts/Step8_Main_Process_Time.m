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
% 本脚本是对仿真结果进行总结，在时间尺度上简化，得到空间分布
%The script summarizes the simulation results by simplifying them in the time scale, and produces a spatial distribution.
%% ------------脚本主体 / Script Execution --------------- 

import tools_functions.*

%% Load Info
% 加载info.mat文件，里面存储了项目的基本信息
p=load('info.mat');
Info=p.Info;

%% Directory
% 设定项目的目录路径，并生成相关子目录路径
Dir_Project=Info(1).Dir_Project;

% 通过拼接路径来定义脚本和数据结果的目录路径
Dir_Scripts=strcat(Dir_Project,'\Scripts');
Dir_Data_Results_Field=strcat(Dir_Project,'\Data\Results\Field');
Dir_Data_Results_Field_time=strcat(Dir_Project,'\Data\Results\Field_time');

% 如果“Field_time”目录不存在，则创建该目录
if ~exist(Dir_Data_Results_Field_time,'dir')
    mkdir(Dir_Data_Results_Field_time);
end

%% Select id Case
% 获取所有case的ID，并确定case的数量
ind=1:length(Info);
Info=Info(ind);
num_Case=length(Info);

%% Select Fringe
% 加载Fringe.mat文件，包含了感兴趣的变量（如场强等）
p=load('Fringe.mat');
Fringe=p.Fringe;

% 选择需要读取的Fringe项的ID，这里包含了MPS、MPSR、速度和坐标等
id_Fringe_read=[...
    5;  ... MPS
    10; ... MPSR
    34; ... Velocity X
    35; ... Velocity Y
    36; ... Velocity Z
    43; ... Coordinate X
    44; ... Coordinate Y
    45; ... Coordinate Z
    ];

num_Fringe=length(id_Fringe_read);

% 遍历所有Fringe项目
for i=1:num_Fringe
    
    id_Fringe=id_Fringe_read(i);

    % 根据Fringe名称生成对应的Field_Time文件路径
    File_Field_Time=strcat(Dir_Data_Results_Field_time,'\',Fringe(id_Fringe).Name,'_Time.mat');
    
    % 创建一个结构数组来保存每个case的结果
    DataFEM_Time=struct([]);

    % 遍历所有case，进行数据处理
    for i_Case=1:num_Case
        %% Process Space Whole Brain
        % 处理整个大脑范围的数据，计算场的峰值和对应的时间点
        % TimePeak: 场在整个大脑中的峰值
        % TimePeak_TimePoint: 场峰值发生的时间点
        % TimePeak_CC: 场在胼胝体（Corpus Callosum）中的峰值
        % TimePeak_TimePoint_CC: 场峰值在胼胝体发生的时间点
        
        %% Load Field 
        % 加载对应Case的数据文件
        File_Field=strcat(Dir_Data_Results_Field,'\',Fringe(id_Fringe).Name,'\',Fringe(id_Fringe).Name,'_',Info(id_Case_0).CaseName,'.mat');
        p=load(File_Field);
        DataFEM=p.DataFEM;
        
        % 获取元素数量
        num_Elem=size(DataFEM.Field,2);
        
        % 初始化结果结构体
        DataFEM_Time(i_Case).TimePeak=zeros(num_Elem,1);
        DataFEM_Time(i_Case).TimePeak_TimePoint=zeros(num_Elem,1);
        
        % 计算每个元素的场强峰值以及对应的时间点
        for id_Elem=1:num_Elem
            [DataFEM_Time(i_Case).TimePeak(id_Elem),ind]=max(DataFEM.Field(:,id_Elem));  % 获取峰值及其索引
            DataFEM_Time(i_Case).TimePeak_TimePoint(id_Elem)=DataFEM.t(ind);  % 获取峰值发生的时间点
        end
        
        % 下面的代码部分注释掉了，原来是处理胼胝体（CC）部分的
        % 注释掉的代码是针对胼胝体的元素进行处理，提取其最大值以及对应时间点的过程
        
    end
    
    % 保存当前Fringe的所有case计算结果到对应的.mat文件
    save(File_Field_Time,'DataFEM_Time','-v7.3');
end
