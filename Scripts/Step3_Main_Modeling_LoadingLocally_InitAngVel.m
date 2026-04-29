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
% 本脚本将根据Info中的信息，将mg_data中的数据与Model Base中的有限元模型结合，生成计算文件
% 注意，在matlab中的单位系是标准单位系，但是具体模型的单位系会有所不同，所以在生成模型时需要转化单位系
% This script will combine the data from mg_data with the finite element model in Model Base based on the information in Info and generate the calculation files.
% Note that the unit system in MATLAB is the standard unit system, but the unit system of the specific model may differ, so unit conversion is required when generating the model.

%% ------------脚本主体 / Script Execution --------------- 

import tools_functions.*

%% Load Info
% 加载信息文件，获取相关参数 / Load the info file to get relevant parameters
p = load('info.mat');  % 加载info.mat文件
Info = p.Info;  % 提取Info结构体数据

%% Directory
% 设置项目文件夹路径 / Set up directory paths for the project
Dir_Project = Info(1).Dir_Project;  % 项目根目录路径

% 设置各个子目录路径 / Set paths for different subdirectories
Dir_Scripts = strcat(Dir_Project, '\Scripts');  % 脚本目录
Dir_Data = strcat(Dir_Project, '\Data');  % 数据目录
Dir_Data_FEM = strcat(Dir_Project, '\Data\FEM');  % 有限元数据目录
Dir_Data_Kinematics = strcat(Dir_Project, '\Data\Kinematics');  % 运动学数据目录

% 如果FEM数据目录不存在，则创建它 / Create the FEM data directory if it doesn't exist
if ~exist(Dir_Data_FEM, 'dir')
    mkdir(Dir_Data_FEM);  % 创建FEM数据目录
end

%% Load Kinematics
% 加载运动学数据 / Load kinematic data
File_Data_Kinematics = strcat(Dir_Data_Kinematics, '\Kinematics_Processed.mat');  % 运动学处理后的数据文件路径
p = load(File_Data_Kinematics);  % 加载运动学数据文件
mg_data = p.mg_data;  % 提取运动学数据

%% Select id Case
% 选择案例 / Select cases based on Info
ind = 1:length(Info);  % 获取所有案例的索引
Info = Info(ind);  % 更新Info结构体中的案例数据
num_Case = length(Info);  % 获取案例的总数

% 遍历每一个案例 / Loop through each case
for i_Case = 1:num_Case
    
    % Create the folder for simulation
    % 为仿真创建输出文件夹 / Create the folder for storing simulation results
    Dir_KFile_Output = strcat(Dir_Data_FEM, '\', Info(i_Case).CaseName);  % 创建案例对应的输出文件夹路径
    
    if ~exist(Dir_KFile_Output, 'dir')  % 如果输出文件夹不存在
        mkdir(Dir_KFile_Output);  % 创建该文件夹
    end
    
    % Pick Kinematics File
    % 选择当前案例的运动学数据 / Select the kinematic data for this case
    mg_data_i = mg_data(i_Case);  % 提取当前案例的运动学数据
    
    % Assembly Setting
    % 设置模型参数 / Model settings
    ModelSetting.Name = Info(i_Case).CaseName;  % 设置案例名称
    ModelSetting.Termination_Time = Info(i_Case).t(end);  % 设置终止时间
    ModelSetting.Output_Interval = mean(diff(Info(i_Case).t));  % 设置输出时间间隔
    ModelSetting.Model_Base2 = strcat(Dir_Project, '\Model Base\', Info(i_Case).FE_Model_Name, '_base\', Info(i_Case).FE_Model_Name, '_Base2.k');  % 设置模型Base2文件路径
    ModelSetting.Head_Center = Info(i_Case).Head_Center;  % 设置头部中心位置
    ModelSetting.Brain_Center = Info(i_Case).Brain_Center;  % 设置大脑中心位置
    ModelSetting.ApplyCoriolis = Info(i_Case).ApplyCoriolis;  % 设置是否应用科里奥利力
    ModelSetting.Model_Unit_System = Info(i_Case).Model_Unit_System;  % 设置模型单位制
    
    % Pick assembly function by model and loading mode
    % 根据模型和加载模式选择不同的组装函数 / Choose assembly function based on model and loading mode
    switch Info(i_Case).FE_Model_Name  % 根据有限元模型名称选择
        case 'KTH'
            switch Info(i_Case).LoadMode  % 根据加载模式选择
                case 'Movement'
                    KTH_Modeling_InitAngVel(mg_data_i, ModelSetting, Dir_KFile_Output);  % 运动学模型初始化函数
                case 'InertialForce'
                    KTH_Modeling_InertialForce(mg_data_i, ModelSetting, Dir_KFile_Output);  % 惯性力模型初始化函数
                otherwise
                    error('Case %04u, loading mode:%s does not exist', i_Case, Info(i_Case).LoadMode);  % 错误处理：加载模式不存在
            end
        case 'GHBMC'
            switch Info(i_Case).LoadMode  % 根据加载模式选择
                case 'Movement'
                    GHBMC_Modeling_InitAngVel(mg_data_i, ModelSetting, Dir_KFile_Output);  % 运动学模型初始化函数
                case 'InertialForce'
                    GHBMC_Modeling_InertialForce(mg_data_i, ModelSetting, Dir_KFile_Output);  % 惯性力模型初始化函数
                otherwise
                    error('Case %04u, loading mode:%s does not exist', i_Case, Info(i_Case).LoadMode);  % 错误处理：加载模式不存在
            end
        case 'THUMS_og'
            switch Info(i_Case).LoadMode  % 根据加载模式选择
                case 'Movement'
                    THUMS_og_Modeling_InitAngVel(mg_data_i, ModelSetting, Dir_KFile_Output);  % 运动学模型初始化函数
                case 'InertialForce'
                    THUMS_og_Modeling_InertialForce(mg_data_i, ModelSetting, Dir_KFile_Output);  % 惯性力模型初始化函数
                otherwise
                    error('Case %04u, loading mode:%s does not exist', i_Case, Info(i_Case).LoadMode);  % 错误处理：加载模式不存在
            end
    end

end


%% ------------建模函数 /Modeling Function --------------- 
function THUMS_og_Modeling_InitAngVel(mg_data,THUMS_og_Setting,Dir_KFile_Output)
% 该函数将基于THUMS orignial模型创建有限元计算文件，加载方式为运动加载
% Author: Yuzhe Liu from TBI Biomechanics Lab, Beihang University
% Contacts: yuzheliu@buaa.edu.cn
% Version: 20250130 by Egge
% THUMS mm-s-ton
%% Loading and Directory
Model_Unit_System=THUMS_og_Setting.Model_Unit_System;
Name=THUMS_og_Setting.Name;
Termination_Time=THUMS_og_Setting.Termination_Time/Model_Unit_System(2);
Output_Interval=THUMS_og_Setting.Output_Interval/Model_Unit_System(2);
THUMS_og_Model_Base2=THUMS_og_Setting.Model_Base2;% The rest THUMS_og model. The file Name should be THUMS_og_Base2.k
Rotation_Center=THUMS_og_Setting.Head_Center/Model_Unit_System(1);
ApplyCoriolis=THUMS_og_Setting.ApplyCoriolis;
if ~ApplyCoriolis
    warning('Corilios force can not be neglected in movement loading mode in\n%s',Dir_KFile_Output);
end

%% Read input and change unit
t=mg_data.t/Model_Unit_System(2);
num_t=length(t);
lin_acc_CG=mg_data.lin_acc_CG/Model_Unit_System(1)*Model_Unit_System(2)^2; % m/s^2 to mm/s^2
ang_vel=mg_data.ang_vel*Model_Unit_System(2);

%% Calculate the initial angular velocity at t=0
[~,ind_t0]=min(t.^2);
ang_vel0=ang_vel(ind_t0,:);
ang_vel0_mag=norm(ang_vel0);
% If there is no initial angualr velocity, 0 magnitude of angular velocity
% will be assigned to the axis 1,0,0
if ang_vel0_mag~=0
    Axis_ang_vel0=ang_vel0/ang_vel0_mag;
else
    Axis_ang_vel0=[1,0,0];
end

THUMS_og_Model_Base1=strcat(Dir_KFile_Output,'\THUMS_og_Base1.k');
fid=fopen(THUMS_og_Model_Base1,'w+');

%% Write Title
fprintf(fid,'$# LS-DYNA Keyword file created by LS-PrePost(R) V4.8.29 - 05Apr2022\n');
fprintf(fid,'$# Created on Jan-15-2025 (08:21:56)\n');
fprintf(fid,'$$ HM_OUTPUT_DECK created 16:31:49 01-14-2025 by HyperMesh Version 2020.0.0.71\n');
fprintf(fid,'$$ Ls-dyna Input Deck Generated by HyperMesh Version  : 2020.0.0.71\n');
fprintf(fid,'$$ Generated using HyperMesh-Ls-dyna 971_R11.1 Template Version : 2020.0.0.71\n');
fprintf(fid,'*KEYWORD LONG=Y\n');
fprintf(fid,'$ ***** (FOLLOWING DESCRIPTION SHOULD ALWAYS BE AT THE BEGINNING OF DATA, *****\n');
fprintf(fid,'$ *****  EVEN IF THUMS IS MODIFIED) *******************************************\n');
fprintf(fid,'$ -----------------------------------------------------------------------------\n');
fprintf(fid,'$ THUMS defined in the "THUMS USER POLICY"\n');
fprintf(fid,'$ -----------------------------------------------------------------------------\n');
fprintf(fid,'$ Date: January 2021\n');
fprintf(fid,'$ -----------------------------------------------------------------------------\n');
fprintf(fid,'$ Copyright (C) 2021 TOYOTA MOTOR CORPORATION and TOYOTA CENTRAL R&D LABS., INC.\n');
fprintf(fid,'$ All Rights Reserved.\n');
fprintf(fid,'$ -----------------------------------------------------------------------------\n');
fprintf(fid,'$ Developed by TOYOTA MOTOR CORPORATION and TOYOTA CENTRAL R&D LABS., INC.\n');
fprintf(fid,'$ -----------------------------------------------------------------------------\n');
fprintf(fid,'$ COPYRIGHT NOTICE\n');
fprintf(fid,'$ All intellectual property rights, including without limitation to the\n');
fprintf(fid,'$ copyright of and with respect to the THUMS, are owned by TOYOTA MOTOR\n');
fprintf(fid,'$ CORPORATION and TOYOTA CENTRAL R&D LABS., INC.\n');
fprintf(fid,'$ Only users that have agreed to the "THUMS USER POLICY" and have registered\n');
fprintf(fid,'$ as a user on the website published by TOYOTA MOTOR CORPORATION may refer to,\n');
fprintf(fid,'$ use and share the licensed THUMS or modified THUMS, and only in accordance\n');
fprintf(fid,'$ with and subject to the "THUMS USER POLICY". \n');
fprintf(fid,'$ Users shall indemnify TOYOTA MOTOR CORPORATION and TOYOTA CENTRAL R&D LABS.,\n');
fprintf(fid,'$ INC.\n');
fprintf(fid,'$ The THUMS are provided on an "as is" basis and TOYOTA MOTOR CORPORATION\n');
fprintf(fid,'$ and TOYOTA CENTRAL R&D LABS., INC. make no representations or warranties of\n');
fprintf(fid,'$ any kind with respect thereto.\n');
fprintf(fid,'$ Any use of the THUMS shall be entirely at the users own risk and\n');
fprintf(fid,'$ responsibility. Neither TOYOTA MOTOR CORPORATION nor TOYOTA CENTRAL R&D LABS.,\n');
fprintf(fid,'$ INC. shall assume any liability or responsibility whatsoever for any damage,\n');
fprintf(fid,'$ claims, injury or loss of any kind that may arise from or in connection with\n');
fprintf(fid,'$ any use of, reference to and/or reliance upon "THUMS USER POLICY".\n');
fprintf(fid,'$ ******************* (THE ABOVE DESCRIPTION MUST BE KEPT) ********************\n');
fprintf(fid,'*TITLE\n');
fprintf(fid,'$#                                    yc                  zc               title     \n');
fprintf(fid,'THUMS AM50 Pedestrian Model Version 4.02 20150527 no fracture\n');

%% Initial Velocity
fprintf(fid,'*INITIAL_VELOCITY_GENERATION\n');
fprintf(fid,'$#                id                styp               omega                  vx                  vy                  vz               ivatn                icid    \n');
fprintf(fid,'            88000186                   1%20e    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0                   1\n',ang_vel0_mag);
fprintf(fid,'$#                xc                  yc                  zc                  nx                  ny                  nz               phase              irigid    \n');
fprintf(fid,'%20e%20e%20e%20e%20e%20e                   0                   0\n',Rotation_Center(1),Rotation_Center(2),Rotation_Center(3),Axis_ang_vel0(1),Axis_ang_vel0(2),Axis_ang_vel0(3));

%% Termination
fprintf(fid,'*CONTROL_TERMINATION\n');
fprintf(fid,'$   ENDTIM    ENDCYC     DTMIN    ENDENG    ENDMAS     NOSOL\n');
fprintf(fid,'$#            endtim              endcyc               dtmin              endeng              endmas               nosol     \n');
fprintf(fid,'%20e                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0\n',Termination_Time);% Termination_Time in s

%% D3plot
fprintf(fid,'*DATABASE_BINARY_D3PLOT\n');
fprintf(fid,'$       DT      LCDT      BEAM     NPLTC    PSETID\n');
fprintf(fid,'$#                dt                lcdt                beam               npltc              psetid      \n');
fprintf(fid,'%20e                   0                   0                   0                   0\n',Output_Interval); % Output_Interval in s
fprintf(fid,'$     IOOPT\n');
fprintf(fid,'$#             ioopt                rate              cutoff              window                type                pset    \n');
fprintf(fid,'                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0                   0\n');

%% Boundary
fprintf(fid,'*BOUNDARY_PRESCRIBED_MOTION_RIGID_LOCAL_ID\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                      zc               title   heading       \n');
fprintf(fid,'                   0linear acceleration x\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   1                   1            90000001                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                     vad                lcid   heading       \n');
fprintf(fid,'                   0linear acceleration y\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   2                   1            90000002                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                     vad                lcid   heading       \n');
fprintf(fid,'                   0linear acceleration z\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   3                   1            90000003                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                     vad                lcid   heading       \n');
fprintf(fid,'                   0angular velocity x\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   5                   0            90000004                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                     vad                lcid   heading       \n');
fprintf(fid,'                   0angular velocity y\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   6                   0            90000005                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                     vad                lcid   heading       \n');
fprintf(fid,'                   0angular velocity z\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   7                   0            90000006                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');

%% Curve for loading
dir_name={'x','y','z'};

for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE_TITLE\n');
    fprintf(fid,'linear acceleration %s\n',dir_name{i_d});
    fprintf(fid,'$#              lcid                sidr                 sfa                 sfo                offa                offo              dattyp               lcint    \n');
    fprintf(fid,'%20u                   0                 1.0      9.800000190735    0.0000000000e+00    0.0000000000e+00                   0                   0\n',90000000+i_d);
    fprintf(fid,'$#                a1                  o1  \n');
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),lin_acc_CG(i_t,i_d));
    end
end

for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE_TITLE\n');
    fprintf(fid,'angular velocity %s\n',dir_name{i_d});
    fprintf(fid,'$#              lcid                sidr                 sfa                 sfo                offa                offo              dattyp               lcint    \n');
    fprintf(fid,'%20u                   0                 1.0                 1.0    0.0000000000e+00    0.0000000000e+00                   0                   0\n',90000003+i_d);
    fprintf(fid,'$#                a1                  o1  \n');
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),ang_vel(i_t,i_d));
    end
end

fclose(fid);
    
copyfile(THUMS_og_Model_Base2,Dir_KFile_Output);

FileName=strcat(Name,'.k');

CurrentPath=cd;
cd(Dir_KFile_Output);
command=sprintf('copy THUMS_og_Base1.k+THUMS_og_Base2.k %s',FileName);
system(command);
delete('THUMS_og_Base1.k');
delete('THUMS_og_Base2.k');
cd(CurrentPath);  
end

function THUMS_og_Modeling_InertialForce(mg_data,THUMS_og_Setting,Dir_KFile_Output)
% 该函数将基于THUMS orignial模型创建有限元计算文件，加载方式为惯性力加载
% Author: Yuzhe Liu from TBI Biomechanics Lab, Beihang University
% Contacts: yuzheliu@buaa.edu.cn
% Version: 20250130 by Egge
% THUMS mm-s-ton

%% Loading and Directory
Model_Unit_System=THUMS_og_Setting.Model_Unit_System;
Name=THUMS_og_Setting.Name;
Termination_Time=THUMS_og_Setting.Termination_Time/Model_Unit_System(2);% in s
Output_Interval=THUMS_og_Setting.Output_Interval/Model_Unit_System(2);% in s
THUMS_og_Model_Base2=THUMS_og_Setting.Model_Base2;% The rest THUMS_og model. The file Name should be THUMS_og_Base2.k
LoadingCenter_THUMS_og=THUMS_og_Setting.Brain_Center/Model_Unit_System(1); %m to mm
ApplyCoriolis=THUMS_og_Setting.ApplyCoriolis;


%% Read input and change unit
t=mg_data.t/Model_Unit_System(2);
num_t=length(t);
lin_acc_BCG=mg_data.G_lin_acc_BCG/Model_Unit_System(1)*Model_Unit_System(2)^2; % m/s^2 to mm/s^2
ang_vel=mg_data.G_ang_vel*Model_Unit_System(2);
ang_acc=mg_data.G_ang_acc*Model_Unit_System(2)^2;

THUMS_og_Model_Base1=strcat(Dir_KFile_Output,'\THUMS_og_Base1.k');
fid=fopen(THUMS_og_Model_Base1,'w+');

%% Write Title
fprintf(fid,'$# LS-DYNA Keyword file created by LS-PrePost(R) V4.8.29 - 05Apr2022\n');
fprintf(fid,'$# Created on Jan-15-2025 (08:21:56)\n');
fprintf(fid,'$$ HM_OUTPUT_DECK created 16:31:49 01-14-2025 by HyperMesh Version 2020.0.0.71\n');
fprintf(fid,'$$ Ls-dyna Input Deck Generated by HyperMesh Version  : 2020.0.0.71\n');
fprintf(fid,'$$ Generated using HyperMesh-Ls-dyna 971_R11.1 Template Version : 2020.0.0.71\n');
fprintf(fid,'*KEYWORD LONG=Y\n');
fprintf(fid,'$ ***** (FOLLOWING DESCRIPTION SHOULD ALWAYS BE AT THE BEGINNING OF DATA, *****\n');
fprintf(fid,'$ *****  EVEN IF THUMS IS MODIFIED) *******************************************\n');
fprintf(fid,'$ -----------------------------------------------------------------------------\n');
fprintf(fid,'$ THUMS defined in the "THUMS USER POLICY"\n');
fprintf(fid,'$ -----------------------------------------------------------------------------\n');
fprintf(fid,'$ Date: January 2021\n');
fprintf(fid,'$ -----------------------------------------------------------------------------\n');
fprintf(fid,'$ Copyright (C) 2021 TOYOTA MOTOR CORPORATION and TOYOTA CENTRAL R&D LABS., INC.\n');
fprintf(fid,'$ All Rights Reserved.\n');
fprintf(fid,'$ -----------------------------------------------------------------------------\n');
fprintf(fid,'$ Developed by TOYOTA MOTOR CORPORATION and TOYOTA CENTRAL R&D LABS., INC.\n');
fprintf(fid,'$ -----------------------------------------------------------------------------\n');
fprintf(fid,'$ COPYRIGHT NOTICE\n');
fprintf(fid,'$ All intellectual property rights, including without limitation to the\n');
fprintf(fid,'$ copyright of and with respect to the THUMS, are owned by TOYOTA MOTOR\n');
fprintf(fid,'$ CORPORATION and TOYOTA CENTRAL R&D LABS., INC.\n');
fprintf(fid,'$ Only users that have agreed to the "THUMS USER POLICY" and have registered\n');
fprintf(fid,'$ as a user on the website published by TOYOTA MOTOR CORPORATION may refer to,\n');
fprintf(fid,'$ use and share the licensed THUMS or modified THUMS, and only in accordance\n');
fprintf(fid,'$ with and subject to the "THUMS USER POLICY". \n');
fprintf(fid,'$ Users shall indemnify TOYOTA MOTOR CORPORATION and TOYOTA CENTRAL R&D LABS.,\n');
fprintf(fid,'$ INC.\n');
fprintf(fid,'$ The THUMS are provided on an "as is" basis and TOYOTA MOTOR CORPORATION\n');
fprintf(fid,'$ and TOYOTA CENTRAL R&D LABS., INC. make no representations or warranties of\n');
fprintf(fid,'$ any kind with respect thereto.\n');
fprintf(fid,'$ Any use of the THUMS shall be entirely at the users own risk and\n');
fprintf(fid,'$ responsibility. Neither TOYOTA MOTOR CORPORATION nor TOYOTA CENTRAL R&D LABS.,\n');
fprintf(fid,'$ INC. shall assume any liability or responsibility whatsoever for any damage,\n');
fprintf(fid,'$ claims, injury or loss of any kind that may arise from or in connection with\n');
fprintf(fid,'$ any use of, reference to and/or reliance upon "THUMS USER POLICY".\n');
fprintf(fid,'$ ******************* (THE ABOVE DESCRIPTION MUST BE KEPT) ********************\n');
fprintf(fid,'*TITLE\n');
fprintf(fid,'$#                                    yc                  zc               title     \n');
fprintf(fid,'THUMS AM50 Pedestrian Model Version 4.02 20150527 no fracture\n');

%% Inertial Force Loading
fprintf(fid,'*LOAD_BODY_GENERALIZED_SET_PART\n');

% linear force x
fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000001,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
fprintf(fid,'                   1    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1CENT\n');
% linear force y
fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000002,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
fprintf(fid,'    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1CENT\n');
% linear force z
fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000003,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1CENT\n');

% centrifugal force x
fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000004,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00                   1CENT\n');
% centrifugal force y
fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000005,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00                   1CENT\n');
% centrifugal force z
fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000006,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1                   1CENT\n');

if ApplyCoriolis
    % Coriolios force x
    fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000004,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
    fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00                   1CORI\n');
    % Coriolios force y
    fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000005,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
    fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00                   1CORI\n');
    % Coriolios force z
    fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000006,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
    fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1                   1CORI\n');
end
        
% Euler force x
fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000007,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00                   1ROTA\n');
% Euler force y
fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000008,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00                   1ROTA\n');
% Euler force z
fprintf(fid,'            88000186                   0%20u                   0%20e%20e%20e\n',90000009,LoadingCenter_THUMS_og(1),LoadingCenter_THUMS_og(2),LoadingCenter_THUMS_og(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1                   1ROTA\n');

%% Termination
fprintf(fid,'*CONTROL_TERMINATION\n');
fprintf(fid,'$   ENDTIM    ENDCYC     DTMIN    ENDENG    ENDMAS     NOSOL\n');
fprintf(fid,'$#            endtim              endcyc               dtmin              endeng              endmas               nosol     \n');
fprintf(fid,'%20e                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0\n',Termination_Time);% Termination_Time in s

%% D3plot
fprintf(fid,'*DATABASE_BINARY_D3PLOT\n');
fprintf(fid,'$       DT      LCDT      BEAM     NPLTC    PSETID\n');
fprintf(fid,'$#                dt                lcdt                beam               npltc              psetid      \n');
fprintf(fid,'%20e                   0                   0                   0                   0\n',Output_Interval); % Output_Interval in s
fprintf(fid,'$     IOOPT\n');
fprintf(fid,'$#             ioopt                rate              cutoff              window                type                pset    \n');
fprintf(fid,'                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0                   0\n');

%% Boundary
fprintf(fid,'*BOUNDARY_PRESCRIBED_MOTION_RIGID_LOCAL_ID\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                      zc               title   heading       \n');
fprintf(fid,'                   0linear acceleration x\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   1                   2            90000010                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                     vad                lcid   heading       \n');
fprintf(fid,'                   0linear acceleration y\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   2                   2            90000010                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                     vad                lcid   heading       \n');
fprintf(fid,'                   0linear acceleration z\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   3                   2            90000010                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                     vad                lcid   heading       \n');
fprintf(fid,'                   0angular velocity x\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   5                   2            90000010                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                     vad                lcid   heading       \n');
fprintf(fid,'                   0angular velocity y\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   6                   2            90000010                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'$      PID     SECID       MID     EOSID      HGID      GRAV    ADPOPT      TMID\n');
fprintf(fid,'$#                id                                     vad                lcid   heading       \n');
fprintf(fid,'                   0angular velocity z\n');
fprintf(fid,'$#               pid                 dof                 vad                lcid                  sf                 vid               death               birth    \n');
fprintf(fid,'            88000003                   7                   2            90000010                   0                   0    9.9999994421e+27    0.0000000000e+00\n');

%% Curve for loading
dir_name={'x','y','z'};

for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE_TITLE\n');
    fprintf(fid,'linear acceleration %s\n',dir_name{i_d});
    fprintf(fid,'$#              lcid                sidr                 sfa                 sfo                offa                offo              dattyp               lcint    \n');
    fprintf(fid,'%20u                   0                 1.0      9.800000190735    0.0000000000e+00    0.0000000000e+00                   0                   0\n',90000000+i_d);
    fprintf(fid,'$#                a1                  o1  \n');
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),lin_acc_BCG(i_t,i_d));
    end
end

for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE_TITLE\n');
    fprintf(fid,'angular velocity %s\n',dir_name{i_d});
    fprintf(fid,'$#              lcid                sidr                 sfa                 sfo                offa                offo              dattyp               lcint    \n');
    fprintf(fid,'%20u                   0                 1.0                 1.0    0.0000000000e+00    0.0000000000e+00                   0                   0\n',90000003+i_d);
    fprintf(fid,'$#                a1                  o1  \n');
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),ang_vel(i_t,i_d));
    end
end

for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE_TITLE\n');
    fprintf(fid,'angular acceleration %s\n',dir_name{i_d});
    fprintf(fid,'$#              lcid                sidr                 sfa                 sfo                offa                offo              dattyp               lcint    \n');
    fprintf(fid,'%20u                   0                 1.0                 1.0    0.0000000000e+00    0.0000000000e+00                   0                   0\n',90000006+i_d);
    fprintf(fid,'$#                a1                  o1  \n');
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),ang_acc(i_t,i_d));
    end
end

%% Curve for constant zero
fprintf(fid,'*DEFINE_CURVE\n');
fprintf(fid,'%20u                   0                 1.0      1.000000000000    0.0000000000e+00    0.0000000000e+00                   0                   0\n',90000010);
fprintf(fid,'%10e,%10e\n',0,0);
fprintf(fid,'%10e,%10e\n',1e9,0);

fclose(fid);
    
copyfile(THUMS_og_Model_Base2,Dir_KFile_Output);

FileName=strcat(Name,'.k');

CurrentPath=cd;
cd(Dir_KFile_Output);
command=sprintf('copy THUMS_og_Base1.k+THUMS_og_Base2.k %s',FileName);
system(command);
delete('THUMS_og_Base1.k');
delete('THUMS_og_Base2.k');
cd(CurrentPath); 

end

function GHBMC_Modeling_InertialForce(mg_data,GHBMC_Setting,Dir_KFile_Output)
% 该函数将基于GHBMC模型创建有限元计算文件，加载方式为惯性力加载
% Author: Yuzhe Liu from TBI Biomechanics Lab, Beihang University
% Contacts: yuzheliu@buaa.edu.cn
% Version: 20250130 by Egge
% GHBMC mm-ms-kg

%% Loading and Directory
Model_Unit_System=GHBMC_Setting.Model_Unit_System;
Name=GHBMC_Setting.Name;
Termination_Time=GHBMC_Setting.Termination_Time/Model_Unit_System(2);% s to ms
Output_Interval=GHBMC_Setting.Output_Interval/Model_Unit_System(2);% s to ms
GHBMC_Model_Base2=GHBMC_Setting.Model_Base2;% The rest GHBMC model. The file Name should be GHBMC_Base2.k
LoadingCenter_GHBMC=GHBMC_Setting.Brain_Center/Model_Unit_System(1); %SHOULD be in GHBMC frame m to mm
ApplyCoriolis=GHBMC_Setting.ApplyCoriolis;

%% Read input and change unit
t=mg_data.t/Model_Unit_System(2);
num_t=length(t);
lin_acc_BCG=mg_data.G_lin_acc_BCG/Model_Unit_System(1)*Model_Unit_System(2)^2; % m/s^2 to mm/s^2
ang_vel=mg_data.G_ang_vel*Model_Unit_System(2);
ang_acc=mg_data.G_ang_acc*Model_Unit_System(2)^2;

GHBMC_Model_Base1=strcat(Dir_KFile_Output,'\GHBMC_Base1.k');
fid=fopen(GHBMC_Model_Base1,'w+');

%% Write Title
fprintf(fid,'$# LS-DYNA Keyword file created by LS-PrePost(R) V4.7.23 -28Sep2021\n');
fprintf(fid,'$# Created on Jan-15-2025 (13:56:51)\n');
fprintf(fid,'*KEYWORD LONG=Y\n');
fprintf(fid,'*PARAMETER\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'R solfail           0.000                                                                                                                                       \n');
fprintf(fid,'R shefail           0.000               R noseshe           0.000               R skdfail           0.000               R skcfail           0.000\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'*TITLE\n');
fprintf(fid,'LS-DYNA keyword deck by LS-PrePost\n');

%% D3plot

fprintf(fid,'*DATABASE_BINARY_D3PLOT\n');
fprintf(fid,'$   0.25000         0         0         0         0\n');
fprintf(fid,'$  1.250000         0         0         0         0\n');
fprintf(fid,'%20e                   0                   0                   0                   0\n',Output_Interval);
fprintf(fid,'$  10.00000         0         0         0         0\n');
fprintf(fid,'                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0                   0\n');

%% Termination
fprintf(fid,'*CONTROL_TERMINATION\n');
fprintf(fid,'%20e                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0\n',Termination_Time);

%% Curve for loading
for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE\n');
    fprintf(fid,'%20u                   0                 1.0      9.810000419617    0.0000000000e+00    0.0000000000e+00                   0                   0\n',i_d);
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),lin_acc_BCG(i_t,i_d));
    end
end

for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE\n');
    fprintf(fid,'%20u                   0                 1.0      1.000000000000    0.0000000000e+00    0.0000000000e+00                   0                   0\n',i_d+3);
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),ang_vel(i_t,i_d));
    end
end

for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE\n');
    fprintf(fid,'%20u                   0                 1.0      1.000000000000    0.0000000000e+00    0.0000000000e+00                   0                   0\n',i_d+6);
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),ang_acc(i_t,i_d));
    end
end

%% Curve for constant zero
fprintf(fid,'*DEFINE_CURVE\n');
fprintf(fid,'%20u                   0                 1.0      1.000000000000    0.0000000000e+00    0.0000000000e+00                   0                   0\n',10);
fprintf(fid,'%10e,%10e\n',0,0);
fprintf(fid,'%10e,%10e\n',1e9,0);

%% Boundary
fprintf(fid,'*BOUNDARY_PRESCRIBED_MOTION_RIGID_LOCAL\n');
fprintf(fid,'             1400006                   1                   2                  10                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'             1400006                   2                   2                  10                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'             1400006                   3                   2                  10                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'             1400006                   5                   2                  10                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'             1400006                   6                   2                  10                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'             1400006                   7                   2                  10                   0                   0    9.9999994421e+27    0.0000000000e+00\n'); 
%% Inertial Force Loading
fprintf(fid,'*LOAD_BODY_GENERALIZED_SET_PART\n');

% linear force x
fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',1,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
fprintf(fid,'                   1    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00             1991101CENT\n');
% linear force y
fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',2,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
fprintf(fid,'    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00             1991101CENT\n');
% linear force z
fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',3,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00             1991101CENT\n');

% centrifugal force x
fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',4,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00             1991101CENT\n');
% centrifugal force y
fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',5,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00             1991101CENT\n');
% centrifugal force z
fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',6,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1             1991101CENT\n');

if ApplyCoriolis
    % Coriolios force x
    fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',4,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
    fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00             1991101CORI\n');
    % Coriolios force y
    fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',5,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
    fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00             1991101CORI\n');
    % Coriolios force z
    fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',6,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
    fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1             1991101CORI\n');
end    

% Euler force x
fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',7,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00             1991101ROTA\n');
% Euler force y
fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',8,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00             1991101ROTA\n');
% Euler force z
fprintf(fid,'             1400004                   0%20u                   0%20e%20e%20e\n',9,LoadingCenter_GHBMC(1),LoadingCenter_GHBMC(2),LoadingCenter_GHBMC(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1             1991101ROTA\n');

fclose(fid);
    
copyfile(GHBMC_Model_Base2,Dir_KFile_Output);

FileName=strcat(Name,'.k');

CurrentPath=cd;
cd(Dir_KFile_Output);
command=sprintf('copy GHBMC_Base1.k+GHBMC_Base2.k %s',FileName);
system(command);
delete('GHBMC_Base1.k');
delete('GHBMC_Base2.k');
cd(CurrentPath);  

end

function GHBMC_Modeling_InitAngVel(mg_data,GHBMC_Setting,Dir_KFile_Output)
% 该函数将基于GHBMC模型创建有限元计算文件，加载方式为运动加载
% Author: Yuzhe Liu from TBI Biomechanics Lab, Beihang University
% Contacts: yuzheliu@buaa.edu.cn
% Version: 20250130 by Egge
% GHBMC mm-ms-kg


%% Loading and Directory
Model_Unit_System=GHBMC_Setting.Model_Unit_System;
Name=GHBMC_Setting.Name;
Termination_Time=GHBMC_Setting.Termination_Time/Model_Unit_System(2);% s to ms
Output_Interval=GHBMC_Setting.Output_Interval/Model_Unit_System(2);% s to ms
GHBMC_Model_Base2=GHBMC_Setting.Model_Base2;% The rest GHBMC model. The file Name should be GHBMC_Base2.k
Rotation_Center=GHBMC_Setting.Head_Center/Model_Unit_System(1); %SHOULD be in GHBMC frame, from m to mm
ApplyCoriolis=GHBMC_Setting.ApplyCoriolis;
if ~ApplyCoriolis
    warning('Corilios force can not be neglected in movement loading mode in\n%s',Dir_KFile_Output);
end

%% Read input and change unit
t=mg_data.t/Model_Unit_System(2);
num_t=length(t);
lin_acc_CG=mg_data.lin_acc_CG/Model_Unit_System(1)*Model_Unit_System(2)^2; % m/s^2 to mm/s^2
ang_vel=mg_data.ang_vel*Model_Unit_System(2);


%% Calculate the initial angular velocity at t=0
[~,ind_t0]=min(t.^2);
ang_vel0=ang_vel(ind_t0,:);
ang_vel0_mag=norm(ang_vel0);
% If there is no initial angualr velocity, 0 magnitude of angular velocity
% will be assigned to the axis 1,0,0
if ang_vel0_mag~=0
    Axis_ang_vel0=ang_vel0/ang_vel0_mag;
else
    Axis_ang_vel0=[1,0,0];
end

GHBMC_Model_Base1=strcat(Dir_KFile_Output,'\GHBMC_Base1.k');
fid=fopen(GHBMC_Model_Base1,'w+');

%% Write Title
fprintf(fid,'$# LS-DYNA Keyword file created by LS-PrePost(R) V4.7.23 -28Sep2021\n');
fprintf(fid,'$# Created on Jan-15-2025 (13:56:51)\n');
fprintf(fid,'*KEYWORD LONG=Y\n');
fprintf(fid,'*PARAMETER\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'R solfail           0.000                                                                                                                                       \n');
fprintf(fid,'R shefail           0.000               R noseshe           0.000               R skdfail           0.000               R skcfail           0.000\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ ****** Neck: Force and Moment ******\n');
fprintf(fid,'$ ************************************\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ---- Cross-Section Plane Definitions for OC and C1 ----\n');
fprintf(fid,'$ -------------------------------------------------------\n');
fprintf(fid,'$ ------------------------Head Model------------------------\n');
fprintf(fid,'$ Parameter for bone fracture in the skull\n');
fprintf(fid,'$    set parameters: Bone fracture active\n');
fprintf(fid,'$        RSOLFail,0.045\n');
fprintf(fid,'$        RSHEFail,0.012\n');
fprintf(fid,'$        RnoseSHE,0.02\n');
fprintf(fid,'$        Rskdfail,0.02\n');
fprintf(fid,'$        Rskcfail,0.0042\n');
fprintf(fid,'$    set parameters: Bone fracture inactive\n');
fprintf(fid,'$        RSOLFail,0.000\n');
fprintf(fid,'$        RSHEFail,0.000\n');
fprintf(fid,'$        RnoseSHE,0.00\n');
fprintf(fid,'$        Rskdfail,0.00\n');
fprintf(fid,'$        Rskcfail,0.0000\n');
fprintf(fid,'*TITLE\n');
fprintf(fid,'LS-DYNA keyword deck by LS-PrePost\n');

%% D3plot

fprintf(fid,'*DATABASE_BINARY_D3PLOT\n');
fprintf(fid,'$   0.25000         0         0         0         0\n');
fprintf(fid,'$  1.250000         0         0         0         0\n');
fprintf(fid,'%20e                   0                   0                   0                   0\n',Output_Interval);
fprintf(fid,'$  10.00000         0         0         0         0\n');
fprintf(fid,'                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0                   0\n');

%% Termination
fprintf(fid,'*CONTROL_TERMINATION\n');
fprintf(fid,'%20e                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0\n',Termination_Time);

%% Initial Velocity
fprintf(fid,'*INITIAL_VELOCITY_GENERATION\n');
fprintf(fid,'             1400004                   1%20e    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0             1991101\n',ang_vel0_mag);
fprintf(fid,'%20e%20e%20e%20e%20e%20e                   0                   0\n',Rotation_Center(1),Rotation_Center(2),Rotation_Center(3),Axis_ang_vel0(1),Axis_ang_vel0(2),Axis_ang_vel0(3));

%% Curve for loading
for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE\n');
    fprintf(fid,'%20u                   0                 1.0      9.810000419617    0.0000000000e+00    0.0000000000e+00                   0                   0\n',i_d);
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),lin_acc_CG(i_t,i_d));
    end
end

for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE\n');
    fprintf(fid,'%20u                   0                 1.0      1.000000000000    0.0000000000e+00    0.0000000000e+00                   0                   0\n',i_d+3);
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),ang_vel(i_t,i_d));
    end
end

%% Boundary
fprintf(fid,'*BOUNDARY_PRESCRIBED_MOTION_RIGID_LOCAL\n');
fprintf(fid,'             1400006                   1                   1                   1                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'             1400006                   2                   1                   2                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'             1400006                   3                   1                   3                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'             1400006                   5                   0                   4                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'             1400006                   6                   0                   5                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'             1400006                   7                   0                   6                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');

fclose(fid);
    
copyfile(GHBMC_Model_Base2,Dir_KFile_Output);

FileName=strcat(Name,'.k');

CurrentPath=cd;
cd(Dir_KFile_Output);
command=sprintf('copy GHBMC_Base1.k+GHBMC_Base2.k %s',FileName);
system(command);
delete('GHBMC_Base1.k');
delete('GHBMC_Base2.k');
cd(CurrentPath);  

end

function KTH_Modeling_InertialForce(mg_data,KTH_Setting,Dir_KFile_Output)
% 该函数将基于KTH模型创建有限元计算文件，加载方式为惯性力加载
% Author: Yuzhe Liu from TBI Biomechanics Lab, Beihang University
% Contacts: yuzheliu@buaa.edu.cn
% Version: 20250130 by Egge
% KTH standard SI
%% Loading and Directory
Model_Unit_System=KTH_Setting.Model_Unit_System;
Name=KTH_Setting.Name;
Termination_Time=KTH_Setting.Termination_Time/Model_Unit_System(2);% in s
Output_Interval=KTH_Setting.Output_Interval/Model_Unit_System(2);% in s
KTH_Model_Base2=KTH_Setting.Model_Base2;% The rest KTH model. The file Name should be KTH_Base2.k
LoadingCenter_KTH=KTH_Setting.Brain_Center/Model_Unit_System(1); %SHOULD be in KTH frame
ApplyCoriolis=KTH_Setting.ApplyCoriolis;

t=mg_data.t/Model_Unit_System(2);
num_t=length(t);
lin_acc_BCG=mg_data.G_lin_acc_BCG/Model_Unit_System(1)*Model_Unit_System(2)^2; % m/s^2 to mm/s^2
ang_vel=mg_data.G_ang_vel*Model_Unit_System(2);
ang_acc=mg_data.G_ang_acc*Model_Unit_System(2)^2;
KTH_Model_Base1=strcat(Dir_KFile_Output,'\KTH_Base1.k');
fid=fopen(KTH_Model_Base1,'w+');

fprintf(fid,'$# LS-DYNA Keyword file created by LS-PrePost(R) V4.7.23 -28Sep2021\n');
fprintf(fid,'$# Created on Jan-15-2025 (14:56:37)\n');
fprintf(fid,'*KEYWORD LONG=Y\n');
fprintf(fid,'*TITLE\n');
fprintf(fid,'LS-DYNA keyword deck by LS-PrePost\n');

%% Termination
fprintf(fid,'*CONTROL_TERMINATION\n');
fprintf(fid,'%20e                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0\n',Termination_Time);
fprintf(fid,'$ 2.00000-4                   0\n');

%% Database Output
fprintf(fid,'*DATABASE_BINARY_D3PLOT\n');
fprintf(fid,'%20e                   0                   0                   0                   0\n',Output_Interval);
fprintf(fid,'$ 0.50000-4\n');
fprintf(fid,'                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0                   0\n');

%% Boundary
fprintf(fid,'*BOUNDARY_PRESCRIBED_MOTION_RIGID_LOCAL_ID\n');
fprintf(fid,'                   0fix skull linear X\n');
fprintf(fid,'                   2                   1                   2                 313                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'                   0fix skull linear Y\n');
fprintf(fid,'                   2                   2                   2                 313                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'                   0fix skull linear Z\n');
fprintf(fid,'                   2                   3                   2                 313                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'                   0fix skull angular X\n');
fprintf(fid,'                   2                   5                   2                 313                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'                   0fix skull linear Y\n');
fprintf(fid,'                   2                   6                   2                 313                   0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'                   0fix skull linear Z\n');
fprintf(fid,'                   2                   7                   2                 313                   0                   0    9.9999994421e+27    0.0000000000e+00\n');

%% Curve for loading
for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE\n');
    fprintf(fid,'%20u                   0                 1.0      9.810000419617    0.0000000000e+00    0.0000000000e+00                   0                   0\n',i_d);
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),lin_acc_BCG(i_t,i_d));
    end
end

for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE\n');
    fprintf(fid,'%20u                   0                 1.0      1.000000000000    0.0000000000e+00    0.0000000000e+00                   0                   0\n',i_d+3);
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),ang_vel(i_t,i_d));
    end
end

for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE\n');
    fprintf(fid,'%20u                   0                 1.0      1.000000000000    0.0000000000e+00    0.0000000000e+00                   0                   0\n',i_d+309);
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),ang_acc(i_t,i_d));
    end
end

%% Curve for constant zero
fprintf(fid,'*DEFINE_CURVE\n');
fprintf(fid,'%20u                   0                 1.0      1.000000000000    0.0000000000e+00    0.0000000000e+00                   0                   0\n',313);
fprintf(fid,'%10e,%10e\n',0,0);
fprintf(fid,'%10e,%10e\n',1e9,0);

%% Inertial Force Loading
fprintf(fid,'*LOAD_BODY_GENERALIZED_SET_PART\n');

% linear force x
fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',1,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
fprintf(fid,'                   1    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1CENT\n');
% linear force y
fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',2,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
fprintf(fid,'    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1CENT\n');
% linear force z
fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',3,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1CENT\n');

% centrifugal force x
fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',4,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00                   1CENT\n');
% centrifugal force y
fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',5,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00                   1CENT\n');
% centrifugal force z
fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',6,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1                   1CENT\n');

if ApplyCoriolis
    % Coriolios force x
    fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',4,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
    fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00                   1CORI\n');
    % Coriolios force y
    fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',5,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
    fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00                   1CORI\n');
    % Coriolios force z
    fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',6,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
    fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1                   1CORI\n');
end

% Euler force x
fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',310,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00    0.0000000000e+00                   1ROTA\n');
% Euler force y
fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',311,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1    0.0000000000e+00                   1ROTA\n');
% Euler force z
fprintf(fid,'                  27                   0%20u                   0%20e%20e%20e\n',312,LoadingCenter_KTH(1),LoadingCenter_KTH(2),LoadingCenter_KTH(3));
fprintf(fid,'    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   1                   1ROTA\n');
fclose(fid);
    
copyfile(KTH_Model_Base2,Dir_KFile_Output);

FileName=strcat(Name,'.k');

CurrentPath=cd;
cd(Dir_KFile_Output);
command=sprintf('copy KTH_Base1.k+KTH_Base2.k %s',FileName);
system(command);
delete('KTH_Base1.k');
delete('KTH_Base2.k');
cd(CurrentPath);  

end



function KTH_Modeling_InitAngVel(mg_data,KTH_Setting,Dir_KFile_Output)
% 该函数将基于KTH模型创建有限元计算文件，加载方式为运动加载
% Author: Yuzhe Liu from TBI Biomechanics Lab, Beihang University
% Contacts: yuzheliu@buaa.edu.cn
% Version: 20250130 by Egge
% KTH standard SI
%% Loading and Directory
Model_Unit_System=KTH_Setting.Model_Unit_System;
Name=KTH_Setting.Name;
Termination_Time=KTH_Setting.Termination_Time/Model_Unit_System(2);% in s
Output_Interval=KTH_Setting.Output_Interval/Model_Unit_System(2);% in s
KTH_Model_Base2=KTH_Setting.Model_Base2;% The rest KTH model. The file Name should be KTH_Base2.k
Rotation_Center=KTH_Setting.Head_Center/Model_Unit_System(1); %SHOULD be in KTH frame
ApplyCoriolis=KTH_Setting.ApplyCoriolis;
if ~ApplyCoriolis
    warning('Corilios force can not be neglected in movement loading mode in\n%s',Dir_KFile_Output);
end

t=mg_data.t/Model_Unit_System(2);
num_t=length(t);
lin_acc_CG=mg_data.lin_acc_CG/Model_Unit_System(1)*Model_Unit_System(2)^2; % m/s^2 to mm/s^2
ang_vel=mg_data.ang_vel*Model_Unit_System(2);

%% Calculate the initial angular velocity at t=0
[~,ind_t0]=min(t.^2);
ang_vel0=ang_vel(ind_t0,:);
ang_vel0_mag=norm(ang_vel0);
% If there is no initial angualr velocity, 0 magnitude of angular velocity
% will be assigned to the axis 1,0,0
if ang_vel0_mag~=0
    Axis_ang_vel0=ang_vel0/ang_vel0_mag;
else
    Axis_ang_vel0=[1,0,0];
end

% This is the center of mass in the KTH model, in KTH model Frame
%Node ID = 31200 in KTH model
% Rotation_Center=[0.0,0.00284,-0.02054];

KTH_Model_Base1=strcat(Dir_KFile_Output,'\KTH_Base1.k');
fid=fopen(KTH_Model_Base1,'w+');

fprintf(fid,'$# LS-DYNA Keyword file created by LS-PrePost(R) V4.7.23 -28Sep2021\n');
fprintf(fid,'$# Created on Jan-15-2025 (14:56:37)\n');
fprintf(fid,'*KEYWORD LONG=Y\n');
fprintf(fid,'*TITLE\n');
fprintf(fid,'LS-DYNA keyword deck by LS-PrePost\n');

%% Termination
fprintf(fid,'*CONTROL_TERMINATION\n');
fprintf(fid,'%20e                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0\n',Termination_Time);
fprintf(fid,'$ 2.00000-4                   0\n');

%% Database Output
fprintf(fid,'*DATABASE_BINARY_D3PLOT\n');
fprintf(fid,'%20e                   0                   0                   0                   0\n',Output_Interval);
fprintf(fid,'$ 0.50000-4\n');
fprintf(fid,'                   0    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0                   0\n');

%% Boundary
fprintf(fid,'*BOUNDARY_PRESCRIBED_MOTION_RIGID_LOCAL_ID\n');
fprintf(fid,'                   0fix skull linear X\n');
fprintf(fid,'                   2                   1                   1                   1                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'                   0fix skull linear Y\n');
fprintf(fid,'                   2                   2                   1                   2                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'                   0fix skull linear Z\n');
fprintf(fid,'                   2                   3                   1                   3                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'                   0fix skull angular X\n');
fprintf(fid,'                   2                   5                   0                   4                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'                   0fix skull linear Y\n');
fprintf(fid,'                   2                   6                   0                   5                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');
fprintf(fid,'                   0fix skull linear Z\n');
fprintf(fid,'                   2                   7                   0                   6                 1.0                   0    9.9999994421e+27    0.0000000000e+00\n');

%% Curve for loading
for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE\n');
    fprintf(fid,'%20u                   0                 1.0      9.810000419617    0.0000000000e+00    0.0000000000e+00                   0                   0\n',i_d);
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),lin_acc_CG(i_t,i_d));
    end
end

for i_d=1:3
    fprintf(fid,'*DEFINE_CURVE\n');
    fprintf(fid,'%20u                   0                 1.0      1.000000000000    0.0000000000e+00    0.0000000000e+00                   0                   0\n',i_d+3);
    for i_t=1:num_t
        fprintf(fid,'%10e,%10e\n',t(i_t),ang_vel(i_t,i_d));
    end
end

%% Initial Velocity
fprintf(fid,'*INITIAL_VELOCITY_GENERATION\n');
fprintf(fid,'                  27                   1%20e    0.0000000000e+00    0.0000000000e+00    0.0000000000e+00                   0                   1\n',ang_vel0_mag);
fprintf(fid,'%20e%20e%20e%20e%20e%20e                   0                   0\n',Rotation_Center(1),Rotation_Center(2),Rotation_Center(3),Axis_ang_vel0(1),Axis_ang_vel0(2),Axis_ang_vel0(3));

fclose(fid);
    
copyfile(KTH_Model_Base2,Dir_KFile_Output);

FileName=strcat(Name,'.k');

CurrentPath=cd;
cd(Dir_KFile_Output);
command=sprintf('copy KTH_Base1.k+KTH_Base2.k %s',FileName);
system(command);
delete('KTH_Base1.k');
delete('KTH_Base2.k');
cd(CurrentPath);  

end


