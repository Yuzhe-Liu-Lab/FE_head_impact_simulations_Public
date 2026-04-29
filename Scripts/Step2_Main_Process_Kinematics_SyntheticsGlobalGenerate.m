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
%
% **功能**：  
% 本脚本基于 `Info.mat` 中提供的信息，生成或读取测量或仿真获得的头部运动数据，并进行预处理。  
% 本脚本将生成两个结构体 `mg_data` 和 `impact`，其中 `mg_data` 包含所有头部运动信息，  
% `impact` 结构体包含关键数据，供机器学习模型使用。  
%
% **头部运动数据处理过程**：  
% 1. **读取或生成运动信息**（加速度数据位于头部质心处）  
%    - 可穿戴设备数据采用 `process_RawCSV_MiG` 进行读取（适用于 Stanford MiG）。  
% 2. **调整时间序列**  
%    - 将头部运动时间序列的起始时间调整为 0，并插值至 `Info.mat` 中提供的时间序列 `t`。  
% 3. **计算大脑质心处的线性加速度**  
%    - 将头部质心处的线性加速度投影到大脑质心处，生成 `_BCG` 结尾的数据。  
% 4. **坐标系转换**  
%    - 将解剖坐标系（随头部运动变化的坐标系）中的数据转换为全局坐标系，生成 `G_` 开头的数据。  
%
% **Function**:  
% This script generates or reads head motion data obtained from measurements or simulations,  
% based on the information provided in `Info.mat`, and performs preprocessing.  
% The script generates two structures: `mg_data` and `impact`.  
% `mg_data` contains all head motion information, while `impact` holds key data used for machine learning models.  
%
% **Head Motion Data Processing Steps**:  
% 1. **Read or Generate Motion Data** (Acceleration data is at the head center of mass)  
%    - Wearable device data is read using `process_RawCSV_MiG` (for Stanford MiG).  
% 2. **Adjust Time Series**  
%    - Set the origin of the head motion time series to zero and interpolate it to match  
%      the time series `t` provided in `Info.mat`.  
% 3. **Compute Linear Acceleration at the Brain Center of Mass**  
%    - Project the linear acceleration from the head center of mass to the brain center of mass,  
%      generating data with the `_BCG` suffix.  
% 4. **Coordinate System Transformation**  
%    - Convert data from the anatomical coordinate system (which moves with the head)  
%      to the global coordinate system, generating data prefixed with `G_`.  

%% ------------脚本主体 / Script Execution --------------- 

import tools_functions.*

%% Load Info
p=load('info.mat');
Info=p.Info;    
num_Case=length(Info);

%% Directory
Dir_Project=Info(1).Dir_Project;

Dir_Scripts=strcat(Dir_Project,'\Scripts');
Dir_Data=strcat(Dir_Project,'\Data');
Dir_Data_Kinematics=strcat(Dir_Project,'\Data\Kinematics');

if ~exist(Dir_Data_Kinematics,'dir')
    mkdir(Dir_Data_Kinematics);
end

%% Load original kinematic data, and assembly as mg_data
mg_data0=struct([]);

for i_Case=1:num_Case
    mg_data0(i_Case).t=Info(i_Case).t;
    num_t=length(mg_data0(i_Case).t);

    mg_data0(i_Case).ang_vel=zeros(num_t,3);
    mg_data0(i_Case).ang_acc=zeros(num_t,3);
    mg_data0(i_Case).lin_acc_CG=zeros(num_t,3);

    ang_vel_mag_i=Info(i_Case).ang_vel_mag;
    ang_acc_mag_i=Info(i_Case).ang_acc_mag;
    lin_acc_mag_i=Info(i_Case).lin_acc_mag;
        
    T_i=Info(i_Case).T;% Here T is not the period of the system, but the time for loading
    Omega_i=2*pi/T_i;
    [ind_T_i]=find(T_i>mg_data0(i_Case).t);
    ind_T_i=ind_T_i(end);
    t_1=mg_data0(i_Case).t(1:ind_T_i);

    ang_vel_0=(ang_vel_mag_i'*(1-cos(Omega_i*t_1)))';
    ang_acc_0=(ang_acc_mag_i'*sin(Omega_i*t_1))';
    lin_acc_CG_0=(lin_acc_mag_i'*sin(Omega_i*t_1))';
    
    mg_data0(i_Case).ang_vel=[ang_vel_0;zeros(length(mg_data0(i_Case).t)-ind_T_i,3)];
    mg_data0(i_Case).ang_acc=[ang_acc_0;zeros(length(mg_data0(i_Case).t)-ind_T_i,3)];
    mg_data0(i_Case).lin_acc_CG=[lin_acc_CG_0;zeros(length(mg_data0(i_Case).t)-ind_T_i,3)];
    % Here we assume the ideal kinematics in the global frame. (because we
    % want to control the torque, and the inertial force is calculated
    % based on the kinematics in global frame.
end

%% Rotate the frame
% % MG frame -> J211
% M_R=[1,0,0;0,-1,0;0,0,-1];
% 
% num_Case=length(mg_data0);
% 
mg_data1=mg_data0;
% 
% for i_Case=1:num_Case
%     mg_data1(i_Case)=RotateFrame_mg_data(mg_data0(i_Case),M_R);
% end

%% Shift the time domain
% Here do not change the time because NFL data have different time windows
% Kinematics time will be interpolated to the time given in Info

mg_data2=mg_data1;
% 
% num_Case=length(mg_data1);
% 
% for i_Case=1:num_Case
%     t0=mg_data2(i_Case).t;
%     t_shift=-t0(1);
%     t0=t0+t_shift;
%     mg_data2(i_Case).t=(Info(i_Case).t)';
%     
%     mg_data2(i_Case).lin_acc_CG=interp1(mg_data1(i_Case).t+t_shift,mg_data1(i_Case).lin_acc_CG,mg_data2(i_Case).t);
%     mg_data2(i_Case).ang_vel=interp1(mg_data1(i_Case).t+t_shift,mg_data1(i_Case).ang_vel,mg_data2(i_Case).t);
%     mg_data2(i_Case).ang_acc=interp1(mg_data1(i_Case).t+t_shift,mg_data1(i_Case).ang_acc,mg_data2(i_Case).t);
% end

%% Transfer linear acceleration from Head center to Brain center
for i_Case=1:num_Case
    % Prepare the point
        Head_Center=Info(i_Case).Head_Center;
        Brain_Center=Info(i_Case).Brain_Center;
    % Calculate at brain center
        lin_acc_HCG=mg_data2(i_Case).lin_acc_CG;% at Head_Center J211 Frame
        ang_vel=mg_data2(i_Case).ang_vel;
        ang_acc=mg_data2(i_Case).ang_acc;
        C1=Head_Center; % from
        C2=Brain_Center; % to
        % transfer the linear from Head CoG to Brain CoG
        [lin_acc_BCG]=Transfer_lin_acc(lin_acc_HCG,ang_vel,ang_acc,C1,C2);
        % assign to mg_data
        mg_data2(i_Case).lin_acc_BCG=lin_acc_BCG;
end

%% Add parameter at global frame

[mg_data3]=Transfer2Global_Reference_mg_data(mg_data2);
% Parameter starting with G is at global frame
% mg_data3=mg_data2;

%% Save
mg_data=mg_data3;

File_Data_Kinematics=strcat(Dir_Data_Kinematics,'\Kinematics_Processed.mat');
save(File_Data_Kinematics,'mg_data');


%%%%%

impact=struct([]);

for i_Case=1:length(mg_data)
    impact(i_Case).ang_vel=mg_data(i_Case).ang_vel;
    impact(i_Case).ang_acc=mg_data(i_Case).ang_acc;
    impact(i_Case).lin_acc_CG=mg_data(i_Case).lin_acc_CG;
    impact(i_Case).t=mg_data(i_Case).t;
end

File_Data_KinematicsML=strcat(Dir_Data_Kinematics,'\Kinematics_ProcessedML.mat');
save(File_Data_KinematicsML,'impact');
