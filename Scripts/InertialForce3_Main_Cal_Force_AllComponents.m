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
% 本脚本根据mg_data中的头部平动和转动计算在固结在颅骨上，原点在大脑质心的非惯性坐标系下的平动力，欧拉力和离心力以及科里奥利力
% 注意，改脚本应在InertialForce1_xxx.m和InertialForce2_xxx.m运行后，基于其结果进行计算
% 该脚本将基于各个时间点和各个位置的非惯性力计算最大值
% 平动力 impressed force: f=-ma
% # is cross
% 欧拉力 Eular force: f=-m*ang_acc#r
% 离心力 Centrifugal force: f=-m*ang_vel#(ang_vel#r)
% 科里奥利里 Coriolis force: f=-2m*ang_vel#vr
% 该脚本将产生IntrF_BCG_All，其中保存了非惯性力的时空分布;IntrF_Br_BCG_All，其中保存了任意时刻大脑整体上向量求和的结果
% IntrF_Max_All，其中保存了任意时刻空间上最大的模量的结果
%% ------------脚本主体 / Script Execution --------------- 

import tools_functions.*

%% Load Info
p=load('info.mat');
Info=p.Info;

%% Directory
Dir_Project=Info(1).Dir_Project;

Dir_Scripts=strcat(Dir_Project,'\Scripts');
Dir_Data_Kinematics=strcat(Dir_Project,'\Data\Kinematics');
Dir_Data_Results_Field=strcat(Dir_Project,'\Data\Results\Field');
Dir_Data_Results_Field_space=strcat(Dir_Project,'\Data\Results\Field_space');

if ~exist(Dir_Data_Results_Field,'dir')
    mkdir(Dir_Data_Results_Field);
end

if ~exist(Dir_Data_Results_Field_space,'dir')
    mkdir(Dir_Data_Results_Field_space);
end

%% Select id Case
id_Case=1:length(Info);
Info=Info(id_Case);
num_Case=length(Info);

%% Load Data to merge

% Load EulrCentriLin
p=load(strcat(Dir_Data_Results_Field_space,'\IntrF_Br_EulrCentriLin.mat'));
IntrF_Br_BCG_EulrCentriLin=p.IntrF_Br_BCG;
p=load(strcat(Dir_Data_Results_Field_space,'\IntrF_Max_EulrCentriLin.mat'));
IntrF_Max_EulrCentriLin=p.IntrF_Max;

% Load Coriiolis
p=load(strcat(Dir_Data_Results_Field_space,'\IntrF_Br_Cor.mat'));
IntrF_Br_BCG_Cor=p.IntrF_Br_BCG;
p=load(strcat(Dir_Data_Results_Field_space,'\IntrF_Max_Cor.mat'));
IntrF_Max_Cor=p.IntrF_Max;

IntrF_Br_BCG=struct([]);
IntrF_Max=struct([]);

for i_Case=1:num_Case
% parfor i_Case=1:num_Case

    sprintf('Processing All %u in %u',i_Case,num_Case)
    
    % Load EulrCentriLin Force
    Folder=strcat(Dir_Data_Results_Field,'\IntrF_BCG_EulrCentriLin');
    p=load(strcat(Folder,'\IntrF_BCG_EulrCentriLin_',Info(i_Case).CaseName,'.mat'));
    IntrF_BCG_EulrCentriLin=p.IntrF_BCG;

    % Load Coriiolis
    Folder=strcat(Dir_Data_Results_Field,'\IntrF_BCG_Cor');
    p=load(strcat(Folder,'\IntrF_BCG_Cor_',Info(i_Case).CaseName,'.mat'));
    IntrF_BCG_Cor=p.IntrF_BCG;

    % All component force
    IntrF_BCG=struct();
    IntrF_BCG.t=IntrF_BCG_EulrCentriLin.t;
    IntrF_BCG.ElementID=IntrF_BCG_EulrCentriLin.ElementID;
    IntrF_BCG.For_All_x_PerMass=IntrF_BCG_Cor.For_Cor_x_PerMass+...
        IntrF_BCG_EulrCentriLin.For_Eulr_x_PerMass+...
        IntrF_BCG_EulrCentriLin.For_cenf_x_PerMass+...
        IntrF_BCG_EulrCentriLin.For_impr_x_PerMass;
    IntrF_BCG.For_All_y_PerMass=IntrF_BCG_Cor.For_Cor_y_PerMass+...
        IntrF_BCG_EulrCentriLin.For_Eulr_y_PerMass+...
        IntrF_BCG_EulrCentriLin.For_cenf_y_PerMass+...
        IntrF_BCG_EulrCentriLin.For_impr_y_PerMass;
    IntrF_BCG.For_All_z_PerMass=IntrF_BCG_Cor.For_Cor_z_PerMass+...
        IntrF_BCG_EulrCentriLin.For_Eulr_z_PerMass+...
        IntrF_BCG_EulrCentriLin.For_cenf_z_PerMass+...
        IntrF_BCG_EulrCentriLin.For_impr_z_PerMass;
    
    IntrF_BCG.Tor_All_x_PerMass=IntrF_BCG_Cor.Tor_Cor_x_PerMass+...
        IntrF_BCG_EulrCentriLin.Tor_Eulr_x_PerMass+...
        IntrF_BCG_EulrCentriLin.Tor_cenf_x_PerMass+...
        IntrF_BCG_EulrCentriLin.Tor_impr_x_PerMass;
    IntrF_BCG.Tor_All_y_PerMass=IntrF_BCG_Cor.Tor_Cor_y_PerMass+...
        IntrF_BCG_EulrCentriLin.Tor_Eulr_y_PerMass+...
        IntrF_BCG_EulrCentriLin.Tor_cenf_y_PerMass+...
        IntrF_BCG_EulrCentriLin.Tor_impr_y_PerMass;
    IntrF_BCG.Tor_All_z_PerMass=IntrF_BCG_Cor.Tor_Cor_z_PerMass+...
        IntrF_BCG_EulrCentriLin.Tor_Eulr_z_PerMass+...
        IntrF_BCG_EulrCentriLin.Tor_cenf_z_PerMass+...
        IntrF_BCG_EulrCentriLin.Tor_impr_z_PerMass;

    IntrF_BCG.For_All_x=IntrF_BCG_Cor.For_Cor_x+...
        IntrF_BCG_EulrCentriLin.For_Eulr_x+...
        IntrF_BCG_EulrCentriLin.For_cenf_x+...
        IntrF_BCG_EulrCentriLin.For_impr_x;
    IntrF_BCG.For_All_y=IntrF_BCG_Cor.For_Cor_y+...
        IntrF_BCG_EulrCentriLin.For_Eulr_y+...
        IntrF_BCG_EulrCentriLin.For_cenf_y+...
        IntrF_BCG_EulrCentriLin.For_impr_y;
    IntrF_BCG.For_All_z=IntrF_BCG_Cor.For_Cor_z+...
        IntrF_BCG_EulrCentriLin.For_Eulr_z+...
        IntrF_BCG_EulrCentriLin.For_cenf_z+...
        IntrF_BCG_EulrCentriLin.For_impr_z;

    IntrF_BCG.Tor_All_x=IntrF_BCG_Cor.Tor_Cor_x+...
        IntrF_BCG_EulrCentriLin.Tor_Eulr_x+...
        IntrF_BCG_EulrCentriLin.Tor_cenf_x+...
        IntrF_BCG_EulrCentriLin.Tor_impr_x;
    IntrF_BCG.Tor_All_y=IntrF_BCG_Cor.Tor_Cor_y+...
        IntrF_BCG_EulrCentriLin.Tor_Eulr_y+...
        IntrF_BCG_EulrCentriLin.Tor_cenf_y+...
        IntrF_BCG_EulrCentriLin.Tor_impr_y;
    IntrF_BCG.Tor_All_z=IntrF_BCG_Cor.Tor_Cor_z+...
        IntrF_BCG_EulrCentriLin.Tor_Eulr_z+...
        IntrF_BCG_EulrCentriLin.Tor_cenf_z+...
        IntrF_BCG_EulrCentriLin.Tor_impr_z;
    
    % Vector sum over brain
    IntrF_BCG.For_All_Br=IntrF_BCG_Cor.For_Cor_Br+IntrF_BCG_EulrCentriLin.For_Eulr_Br+...
        IntrF_BCG_EulrCentriLin.For_cenf_Br+IntrF_BCG_EulrCentriLin.For_impr_Br;

    IntrF_BCG.Tor_All_Br=IntrF_BCG_Cor.Tor_Cor_Br+IntrF_BCG_EulrCentriLin.Tor_Eulr_Br+...
        IntrF_BCG_EulrCentriLin.Tor_cenf_Br+IntrF_BCG_EulrCentriLin.Tor_impr_Br;

    Folder=strcat(Dir_Data_Results_Field,'\IntrF_BCG_All');
    if ~exist(Folder,'dir')
        mkdir(Folder)
    end
    
    File_InertialForce=strcat(Folder,'\IntrF_BCG_All_',Info(i_Case).CaseName,'.mat');
%     save(File_InertialForce,'IntrF_BCG','-v7.3');
    Save(File_InertialForce,IntrF_BCG); % because parfor

%% Cal force and torque Br (vector sum for all brain)   
    IntrF_Br_BCG(i_Case).t=IntrF_Br_BCG_EulrCentriLin(i_Case).t;
%     IntrF_Br_BCG(i_Case).ElementID=IntrF_Br_BCG_EulrCentriLin(i_Case).ElementID;

    IntrF_Br_BCG(i_Case).For_All_Br=IntrF_Br_BCG_Cor(i_Case).For_Cor_Br+IntrF_Br_BCG_EulrCentriLin(i_Case).For_Eulr_Br+...
        IntrF_Br_BCG_EulrCentriLin(i_Case).For_cenf_Br+IntrF_Br_BCG_EulrCentriLin(i_Case).For_impr_Br;

    IntrF_Br_BCG(i_Case).Tor_All_Br=IntrF_Br_BCG_Cor(i_Case).Tor_Cor_Br+IntrF_Br_BCG_EulrCentriLin(i_Case).Tor_Eulr_Br+...
        IntrF_Br_BCG_EulrCentriLin(i_Case).Tor_cenf_Br+IntrF_Br_BCG_EulrCentriLin(i_Case).Tor_impr_Br;
    
%%  Cal Force Max
    IntrF_Max(i_Case).t=IntrF_Br_BCG_EulrCentriLin(i_Case).t;

    num_t=length(IntrF_Max(i_Case).t);
    IntrF_Max(i_Case).For_All_max_PerMass=zeros(num_t,1);% just magnitude
    IntrF_Max(i_Case).Tor_All_max_PerMass=zeros(num_t,1);% just magnitude

    for i_t=1:num_t
        F_i_t=[IntrF_BCG_Cor.For_Cor_x_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.For_Eulr_x_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.For_cenf_x_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.For_impr_x_PerMass(i_t,:);...
            IntrF_BCG_Cor.For_Cor_y_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.For_Eulr_y_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.For_cenf_y_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.For_impr_y_PerMass(i_t,:);...
            IntrF_BCG_Cor.For_Cor_z_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.For_Eulr_z_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.For_cenf_z_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.For_impr_z_PerMass(i_t,:)];
        IntrF_Max(i_Case).For_All_max_PerMass(i_t)=max(sqrt(sum(F_i_t.^2,1)));

        Tor_i_t=[IntrF_BCG_Cor.Tor_Cor_x_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.Tor_Eulr_x_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.Tor_cenf_x_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.Tor_impr_x_PerMass(i_t,:);...
            IntrF_BCG_Cor.Tor_Cor_y_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.Tor_Eulr_y_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.Tor_cenf_y_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.Tor_impr_y_PerMass(i_t,:);...
            IntrF_BCG_Cor.Tor_Cor_z_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.Tor_Eulr_z_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.Tor_cenf_z_PerMass(i_t,:)+IntrF_BCG_EulrCentriLin.Tor_impr_z_PerMass(i_t,:)];
        IntrF_Max(i_Case).Tor_All_max_PerMass(i_t)=max(sqrt(sum(Tor_i_t.^2,1)));
    end
end

%% Save
File_InertialForce_WholeBrain=strcat(Dir_Data_Results_Field_space,'\IntrF_Br_All.mat');
save(File_InertialForce_WholeBrain,'IntrF_Br_BCG','-v7.3');

File_InertialForce_WholeBrain=strcat(Dir_Data_Results_Field_space,'\IntrF_Max_All.mat');
save(File_InertialForce_WholeBrain,'IntrF_Max','-v7.3');

function Save(File_InertialForce,IntrF_BCG)
    save(File_InertialForce,'IntrF_BCG','-v7.3');
end

