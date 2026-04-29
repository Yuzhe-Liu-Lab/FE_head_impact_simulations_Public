clear;
%% ------------项目介绍 / Project Introduction ---------------
% 本项目基于 LS-DYNA 进行大批量的头部撞击大脑冲击响应有限元模拟。  
% 输入：头部刚体运动（平移和旋转，共六个自由度的时间序列）。  
% 输出：大脑冲击响应（应变、应变率等）。  
%
% 北航 创伤性脑损伤生物力学研究团队 
% 联系邮箱：yuzheliu@buaa.edu.cn  
%
% 运行本脚本需要安装以下软件：  
% 1. LS-DYNA（计算）  
% 2. LS-PrePost（前后处理）  
% 3. MATLAB 2022 及以上版本（运行本脚本）  
%
% 主要功能：  
% - 设置有限元输入文件，并赋予相应模型  
% - 生成仿真输入文件和提交文件  
% - 计算大脑冲击响应并进行分析  
%
% 单位制和坐标系：  
% 本脚本采用 SI 单位制（m, s, kg），所有有限元模型已转换至 J211 坐标系。  
% 计算时，所有数据将转换为模型固有单位系，读取结果时再转换回 SI 单位。  
%
% 加载方式：  
% 1. **加速度加载（Acceleration-based）**：  
%    刚性颅骨按输入载荷运动，计算大脑变形响应。  
% 2. **惯性力加载（Inertial force-based）**：  
%    固定刚性颅骨，对颅骨内部结构施加惯性力（线性力、欧拉力、离心力、科里奥利力）。  
%    该方式适用于单独研究惯性力影响，但计算时间较长。   
%
% 支持的有限元模型：  
% - KTH 模型（standard unit system）  
% - GHBMC 模型（mm-ms-kg）  
% - THUMS 模型（mm-s-ton）  
%
% This project conducts large-scale finite element simulations of brain impact responses based on LS-DYNA.  
%
% **Input**: Rigid-body motion of the head (translation and rotation, six degrees of freedom time series).  
% **Output**: Brain impact responses (e.g., strain, strain rate, etc.).  
%
% Lab of Traumatic Brain Injury (TBI) Biomechanics, Beihang University  
% **Contact Email**: yuzheliu@buaa.edu.cn  
%
% **Required Software**:  
% 1. LS-DYNA (for computation)  
% 2. LS-PrePost (for pre- and post-processing)  
% 3. MATLAB 2022 or later (to run this script)  
%
% **Main Functions**:  
% - Set up finite element input files and assign to corresponding models  
% - Generate simulation input and submission files  
% - Compute and analyze brain impact responses  
%
% **Unit System and Coordinate System**:  
% This script uses the SI unit system (meters, seconds, kilograms).  
% All finite element models have been converted to the J211 coordinate system.  
% During computation, all data is transformed to the model's intrinsic unit system  
% and is converted back to SI units when reading the results.  
%
% **Loading Modes**:  
% 1. **Acceleration-based Loading**:  
%    The rigid skull moves according to the input load, and the brain deformation response is computed.  
% 2. **Inertial Force-based Loading**:  
%    The rigid skull is fixed, and inertial forces (linear, Eulerian, centrifugal, and Coriolis forces)  
%    are applied to the skull's internal structure.  
%    This method is suitable for studying the effect of individual inertial forces,  
%    but it requires longer computation time.  
%
% **Supported Finite Element Models**:  
% - KTH model (standard unit system)  
% - GHBMC model (mm-ms-kg)  
% - THUMS model (mm-s-ton)  
%
%% ------------脚本简介 / Script Overview ---------------
% **版本**：Version 20250129_Egge
% **功能**：
% 本脚本生成每个有限元算例的所有必要信息，并保存为 `Info.mat`。
% 其中包含：
% - 项目路径、算例名称（CaseName）
% - 模型信息（模型 ID、模型名称、加载方式、头部质心、大脑质心、模型单位系统、是否施加科里奥利力）
% - 研究所需的各项参数（例如可穿戴设备数据文件名、Synthetic Kinematics 关键参数）
%
% **Function**: 
% This script generates all the necessary information for each finite element case and saves it as `Info.mat`.
% It includes:
% - Project path, case name (CaseName)
% - Model information (Model ID, model name, loading method, head center, brain center, model unit system, whether Coriolis force is applied)
% - Parameters required for the research (e.g., wearable device data file name, synthetic kinematics key parameters)

%% ------------脚本主体 / Script Execution --------------- 

import tools_functions.*

%% 模型信息（若非修改模型，请不要修改） / Model Information (Do not modify unless changing model)
% 1: KTH, 2: GHBMC, 3: THUMS_og (original element)  
FE_Models_Name_array = {'KTH', 'GHBMC', 'THUMS_og'}; % 模型名称 / Model names  
LoadMode_array = {'Movement', 'InertialForce'}; % 加载模式 / Load modes  

% 头部质心位置 / Head center positions  
Head_Center_array = { ...  
    [0.00284, 0, -0.02054], ...  % KTH  
    [0, 0, 0] / 1e3, ...         % GHBMC  
    [-1.0125e-07, 1.59594e-07, 0.000232384] / 1e3 ... % THUMS  
};  

% 大脑质心位置 / Brain center positions  
Brain_Center_array = { ...  
    [0.0010218, 0.0003247, -0.0162427], ... % KTH  
    [-13.9349, -0.10499, -20.8874] / 1e3, ... % GHBMC  
    [-12.3857, 1.6740, -11.7479] / 1e3 ... % THUMS  
};  

% 大脑密度 / Brain density (kg/m^3)  
Brain_Density_array = [1040, 1060, 1000];  

% 模型单位系 / Model unit system  
Model_Unit_System = { ...  
    [1, 1, 1]; ...       % KTH    standard unit system  
    [1e-3, 1e-3, 1]; ... % GHBMC  mm-ms-kg  
    [1e-3, 1, 1e3] ...   % THUMS  mm-s-ton  
};  

%% 模型选择 / Select Simulation Models  
FE_Model_id = [1, 1, 2, 2, 3, 3]; % 模型索引 / Model indices  
Load_Mode_id = [1, 2, 1, 2, 1, 2]; % 加载模式索引 / Load mode indices  

%% 保存当前路径 / Get Current Path  
CurDir = cd;  
Dir_Project = CurDir(1:end-8); % 获取项目目录 / Get project directory  
SplitbySlash = split(CurDir, '\');  
Name_Project = SplitbySlash{end-1}; % 提取项目名称 / Extract project name  

Info = struct([]); % 结构体初始化 / Initialize structure  

%% synthetic kinematics生成的关键参数 / Generate Synthetic Kinematics Parameters  
elv_unit = 1; % 高度角分辨率 / Elevation resolution  
azi_unit = 1.5; % 方位角分辨率 / Azimuth resolution  
AngAcc_1 = 1e3; % 角加速度 / Angular acceleration  
LinAcc_1 = 50; % 线性加速度 / Linear acceleration  
num_AA = length(AngAcc_1); % 角加速度数量 / Number of angular accelerations  

%% setup elevation sample / 设置仿真方向  
elevation_0 = (-pi * 0.4 : elv_unit : pi * 0.4)'; % 采样高度角 / Sample elevations  
num_elv = length(elevation_0);  

elvation_1 = zeros(1e4, 1);  
azimuth_1 = zeros(1e4, 1);  
num_azimuth = zeros(num_elv, 1);  
num_Dir = 0;  

for i_elv = 1:num_elv  
    circum_elv = cos(elevation_0(i_elv)); % 计算圆周长 / Compute circle circumference  
    num_azimuth_i = round(circum_elv / azi_unit); % 计算方位角数目 / Compute number of azimuths  
    azimuth_0 = linspace(-pi, pi, num_azimuth_i)';  
    num_azimuth(i_elv) = num_azimuth_i;  

    azimuth_1(num_Dir+1:num_Dir+num_azimuth_i) = azimuth_0;  
    elvation_1(num_Dir+1:num_Dir+num_azimuth_i) = elevation_0(i_elv);  
    num_Dir = num_Dir + num_azimuth_i;  
end  

%% setup angular acceleration and linear acceleration sample / 设置角加速度和线性加速度样本  
azimuth_2 = repmat(azimuth_1, num_AA, 1);  
elevation_2 = repmat(elvation_1, num_AA, 1);  
AngAcc_2 = repelem(AngAcc_1, num_Dir);  
LinAcc_2 = repelem(LinAcc_1, num_Dir);  
T_0 = 40e-3;  
num_Case_Kinematics = num_Dir * num_AA;  
num_Case_Models = length(FE_Model_id);  

% Assembly kinematics with model / 组装仿真模型与方向  
azimuth_3 = repmat(azimuth_2, num_Case_Models, 1);  
elevation_3 = repmat(elevation_2, num_Case_Models, 1);  
AngAcc_3 = repmat(AngAcc_2, num_Case_Models, 1);  
LinAcc_3 = repmat(LinAcc_2, num_Case_Models, 1);  

%% 开始组装Info struct / Start assembling Info struct  
num_Case = length(AngAcc_3);  

for i_Case = 1:num_Case 

    %  仿真基本信息 必须 / Basic Information of simulation Required  
    Info(i_Case).t = (0:1:0.1 * T_0 * 1e3) * 1e-3; % 仿真时间 / Simulation time  
    Info(i_Case).Dir_Project = Dir_Project;  
    Info(i_Case).Name_Project = Name_Project;  
    Info(i_Case).Head_Center = Head_Center_array{FE_Model_id(i_Case)};  
    Info(i_Case).Brain_Center = Brain_Center_array{FE_Model_id(i_Case)};  
    Info(i_Case).Density = Brain_Density_array(FE_Model_id(i_Case));  
    Info(i_Case).Model_Unit_System = Model_Unit_System{FE_Model_id(i_Case)};  
    Info(i_Case).FE_Model_Name = FE_Models_Name_array{FE_Model_id(i_Case)};  
    Info(i_Case).LoadMode = LoadMode_array{Load_Mode_id(i_Case)};  
    Info(i_Case).FE_Model_id = FE_Model_id(i_Case);  
    Info(i_Case).Load_Mode_id = Load_Mode_id(i_Case);  
    Info(i_Case).ApplyCoriolis = true;  

    % Project Infomation / 项目信息  
    Info(i_Case).azimuth = azimuth_3(i_Case);  
    Info(i_Case).elevation = elevation_3(i_Case);  
    Info(i_Case).AngAcc = AngAcc_3(i_Case);  

    [x, y, z] = sph2cart(azimuth_3(i_Case), elevation_3(i_Case), AngAcc_3(i_Case));  
    omega = 2 * pi / T_0;  
    Info(i_Case).ang_acc_mag = [x, y, z];  
    Info(i_Case).ang_vel_mag = [x, y, z] / omega;  

    [x, y, z] = sph2cart(azimuth_3(i_Case), elevation_3(i_Case), LinAcc_3(i_Case));  
    Info(i_Case).lin_acc_mag = [x, y, z];  
    Info(i_Case).T = T_0; % T is the period of the sinusoid loading  

    % CaseName 必须 / Required  
    Info(i_Case).CaseName = sprintf('HeadModelTest_%04u_%s', i_Case, Info(i_Case).FE_Model_Name);  
end  

save('Info.mat', 'Info'); % 保存 Info.mat / Save Info.mat  
