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
% 本脚本根据mg_data中的头部平动和转动计算在固结在颅骨上，原点在大脑质心的非惯性坐标系下的平动力，欧拉力和离心力
% 注意，因为科里奥利力计算需要相对速度，所以需要基于有限元计算结果再计算科里奥利力。
% 在运行本脚本时，应现在有限元结果中提取出每个网格的速度，即DataFEM_V_X, DataFEM_V_Y, DataFEM_V_Z
% 平动力 impressed force: f=-ma
% # is cross
% 欧拉力 Eular force: f=-m*ang_acc#r
% 离心力 Centrifugal force: f=-m*ang_vel#(ang_vel#r)
% 科里奥利里 Coriolis force: f=-2m*ang_vel#vr
% 该脚本将产生IntrF_BCG_Cor，其中保存了非惯性力的时空分布;IntrF_Br_BCG_Cor，其中保存了任意时刻大脑整体上向量求和的结果
% IntrF_Max_Cor，其中保存了任意时刻空间上最大的模量的结果
%% ------------脚本主体 / Script Execution --------------- 

import tools_functions.*

%% Load Info
p=load('info.mat');
Info=p.Info;


%% Load Element list
% p=load(sprintf('Processed_ELEM_LIST_%s.mat',Info(1).FE_Model_Name));
% Processed_ELEM_LIST=p.Processed_ELEM_LIST; % SI unit for KTH, mm-ms for GHBMC
% ELEM_ID=p.ELEM_ID;

p_KTH=load('Processed_ELEM_LIST_KTH.mat');
Processed_ELEM_LIST_KTH=p_KTH.Processed_ELEM_LIST;
ELEM_ID_KTH=p_KTH.ELEM_ID;

p_GHBMC=load('Processed_ELEM_LIST_GHBMC.mat');
Processed_ELEM_LIST_GHBMC=p_GHBMC.Processed_ELEM_LIST;
ELEM_ID_GHBMC=p_GHBMC.ELEM_ID;

p_THUMS_og=load('Processed_ELEM_LIST_THUMS_og.mat');
Processed_ELEM_LIST_THUMS_og=p_THUMS_og.Processed_ELEM_LIST;
ELEM_ID_THUMS_og=p_THUMS_og.ELEM_ID;

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

%% Read Data
File_Kinematics=strcat(Dir_Data_Kinematics,'\Kinematics_Processed.mat');
Data=load(File_Kinematics);
mg_data=Data.mg_data;% in SI unit for all models

%% Load Fringe
p=load('Fringe.mat');
Fringe=p.Fringe;

%% Read Velocity field 
id_Fringe=34:36;
DataFEM_V_Y=struct([]);
v=struct([]);
DataFEM_V_X=struct([]);
DataFEM_V_Z=struct([]);


for i_Case=1:num_Case

    % read x velocity
    i=1;
    id_Fringe_0=id_Fringe(i);
    File_Field=strcat(Dir_Data_Results_Field,'\',Fringe(id_Fringe_0).Name,'\',Fringe(id_Fringe_0).Name,'_',Info(i_Case).CaseName,'.mat');
    p=load(File_Field);
    DataFEM_V_X(i_Case).Field=p.DataFEM.Field;
    DataFEM_V_X(i_Case).t=p.DataFEM.t;
    DataFEM_V_X(i_Case).ElementID=p.DataFEM.ElementID;

    % read y velocity
    i=2;
    id_Fringe_0=id_Fringe(i);
    File_Field=strcat(Dir_Data_Results_Field,'\',Fringe(id_Fringe_0).Name,'\',Fringe(id_Fringe_0).Name,'_',Info(i_Case).CaseName,'.mat');
    p=load(File_Field);
    DataFEM_V_Y(i_Case).Field=p.DataFEM.Field;
    DataFEM_V_Y(i_Case).t=p.DataFEM.t;
    DataFEM_V_Y(i_Case).ElementID=p.DataFEM.ElementID;
    
    % read z velocity
    i=3;
    id_Fringe_0=id_Fringe(i);
    File_Field=strcat(Dir_Data_Results_Field,'\',Fringe(id_Fringe_0).Name,'\',Fringe(id_Fringe_0).Name,'_',Info(i_Case).CaseName,'.mat');
    p=load(File_Field);
    DataFEM_V_Z(i_Case).Field=p.DataFEM.Field;
    DataFEM_V_Z(i_Case).t=p.DataFEM.t;
    DataFEM_V_Z(i_Case).ElementID=p.DataFEM.ElementID;
end

%% Calculate the force

IntrF_Br_BCG=struct([]);
IntrF_Max=struct([]);

mg_data_modelunit=mg_data;

parfor i_Case=1:num_Case
% for i_Case=1:num_Case

    %% update unit for the model (because the node is in model unit system)

    Model_Unit_System=Info(i_Case).Model_Unit_System;

    m_modelorder=Model_Unit_System(1);
    s_modelorder=Model_Unit_System(2);
    kg_modelorder=Model_Unit_System(3);

    TorqueCenter=Info(i_Case).Brain_Center/m_modelorder;
	rho=Info(i_Case).Density/(kg_modelorder/m_modelorder^3);

    mg_data_modelunit(i_Case).t=mg_data(i_Case).t/s_modelorder;
    mg_data_modelunit(i_Case).ang_acc=mg_data(i_Case).ang_acc*s_modelorder^2;
    mg_data_modelunit(i_Case).ang_vel=mg_data(i_Case).ang_vel*s_modelorder;
    mg_data_modelunit(i_Case).lin_acc_CG=mg_data(i_Case).lin_acc_CG/(m_modelorder/s_modelorder^2);
    mg_data_modelunit(i_Case).lin_acc_BCG=mg_data(i_Case).lin_acc_BCG/(m_modelorder/s_modelorder^2);
    mg_data_modelunit(i_Case).G_ang_acc=mg_data(i_Case).G_ang_acc*s_modelorder^2;
    mg_data_modelunit(i_Case).G_ang_vel=mg_data(i_Case).G_ang_vel*s_modelorder;
    mg_data_modelunit(i_Case).G_lin_acc_CG=mg_data(i_Case).G_lin_acc_CG/(m_modelorder/s_modelorder^2);
    mg_data_modelunit(i_Case).G_lin_acc_BCG=mg_data(i_Case).G_lin_acc_BCG/(m_modelorder/s_modelorder^2);
    
    DataFEM_V_X_modelunit=struct();
    DataFEM_V_X_modelunit.t=DataFEM_V_X(i_Case).t/s_modelorder;
    DataFEM_V_X_modelunit.Field=DataFEM_V_X(i_Case).Field/(m_modelorder/s_modelorder);
    DataFEM_V_X_modelunit.ElementID=DataFEM_V_X(i_Case).ElementID;
    
    DataFEM_V_Y_modelunit=struct();
    DataFEM_V_Y_modelunit.t=DataFEM_V_Y(i_Case).t/s_modelorder;
    DataFEM_V_Y_modelunit.Field=DataFEM_V_Y(i_Case).Field/(m_modelorder/s_modelorder);
    DataFEM_V_Y_modelunit.ElementID=DataFEM_V_Y(i_Case).ElementID;
    
    DataFEM_V_Z_modelunit=struct();
    DataFEM_V_Z_modelunit.t=DataFEM_V_Z(i_Case).t/s_modelorder;
    DataFEM_V_Z_modelunit.Field=DataFEM_V_Z(i_Case).Field/(m_modelorder/s_modelorder);
    DataFEM_V_Z_modelunit.ElementID=DataFEM_V_Z(i_Case).ElementID;

    sprintf('Processing Coriolis %u in %u',i_Case,num_Case)
    
    Processed_ELEM_LIST=[];
    switch Info(i_Case).FE_Model_Name
        case 'KTH'
            Processed_ELEM_LIST=Processed_ELEM_LIST_KTH;
        case 'GHBMC'
            Processed_ELEM_LIST=Processed_ELEM_LIST_GHBMC;
        case 'THUMS_og'
            Processed_ELEM_LIST=Processed_ELEM_LIST_THUMS_og;
    end

    [IntrF_BCG,IntrF_Br_BCG_i,IntrF_Max_i]=Cal_InertialForce_Coriolis(mg_data_modelunit(i_Case),Processed_ELEM_LIST,DataFEM_V_X_modelunit,DataFEM_V_Y_modelunit,DataFEM_V_Z_modelunit,rho,TorqueCenter);

    % update the unit
    IntrF_BCG_SIunit=Transfer_UnitSystem_IntrF(IntrF_BCG,Model_Unit_System);
    IntrF_Br_BCG_i_SIunit=Transfer_UnitSystem_IntrF(IntrF_Br_BCG_i,Model_Unit_System);
    IntrF_Max_i_SIunit=Transfer_UnitSystem_IntrF(IntrF_Max_i,Model_Unit_System);

    Folder=strcat(Dir_Data_Results_Field,'\IntrF_BCG_Cor');
    if ~exist(Folder,'dir')
        mkdir(Folder)
    end

    File_InertialForce=strcat(Folder,'\IntrF_BCG_Cor_',Info(i_Case).CaseName,'.mat');
    IntrF_BCG=IntrF_BCG_SIunit;
    Save(File_InertialForce,IntrF_BCG); % because parfor

    %% Calculate Inertial Force and torque at brain CoG

    IntrF_Br_BCG(i_Case).t=IntrF_Br_BCG_i_SIunit.t;
    IntrF_Max(i_Case).t=IntrF_Br_BCG_i_SIunit.t;

    %% Assembly Impressed force   
    IntrF_Br_BCG(i_Case).For_Cor_Br=IntrF_Br_BCG_i_SIunit.For_Cor_Br;
    IntrF_Br_BCG(i_Case).Tor_Cor_Br=IntrF_Br_BCG_i_SIunit.Tor_Cor_Br;
    IntrF_Br_BCG(i_Case).Vel_Br=IntrF_Br_BCG_i_SIunit.Vel_Br;
    IntrF_Max(i_Case).For_Cor_max_PerMass=IntrF_Max_i_SIunit.For_Cor_max_PerMass;
    IntrF_Max(i_Case).Tor_Cor_max_PerMass=IntrF_Max_i_SIunit.Tor_Cor_max_PerMass;
    IntrF_Max(i_Case).Vel_max=IntrF_Max_i_SIunit.Vel_max;


    %%%%%%%%%%%%%%%%%%%%%%% Important Note 
%     Here IntrF_Br recorde the vector sum of the force vector on every
%     elements across the brain, so it is a vector, same to torque
%   and IntrF_Max record the maximum magnititude across the brain, this is
%   only for force per mass

end

%% Save

File_InertialForce=strcat(Dir_Data_Results_Field_space,'\IntrF_Br_Cor.mat');
save(File_InertialForce,'IntrF_Br_BCG','-v7.3');

File_InertialForce_WholeBrain=strcat(Dir_Data_Results_Field_space,'\IntrF_Max_Cor.mat');
save(File_InertialForce_WholeBrain,'IntrF_Max','-v7.3');

% this function calculates the inertial force and torque at brain CoG
% impressed force: f=-ma
% # is cross
% Eular force: f=-m*ang_acc#r
% Centrifugal force: f=-m*ang_vel#(ang_vel#r)
% Coriolis force: f=-2m*ang_vel#vr
% Make sure all inputs are in the same frame.

function Save(File_InertialForce,IntrF_BCG)
    save(File_InertialForce,'IntrF_BCG','-v7.3');
end

function [IntrF,IntrF_Br,IntrF_Max]=Cal_InertialForce_Coriolis(mg_data,Processed_ELEM_LIST,DataFEM_V_X,DataFEM_V_Y,DataFEM_V_Z,rho,TorqueCenter)
num_Case=length(mg_data);
num_ELEM=length(Processed_ELEM_LIST);
IntrF=struct([]);
IntrF_Br=struct([]);
IntrF_Max=struct([]);

num_Elem=length(Processed_ELEM_LIST);
ElementID=zeros(1,num_Elem);
for i_Elem=1:num_Elem
    ElementID(i_Elem)=Processed_ELEM_LIST{i_Elem}.elID;
end

for i_Case=1:num_Case
    
%     i_Case
    
    t=mg_data(i_Case).t;
    num_t=length(t);
    
    IntrF(i_Case).t=t;
    IntrF(i_Case).ElementID=ElementID;
    IntrF_Br(i_Case).t=t;
    IntrF_Br(i_Case).ElementID=ElementID;
    
    For_Cor_x=zeros(num_t,num_ELEM);
    For_Cor_y=zeros(num_t,num_ELEM);
    For_Cor_z=zeros(num_t,num_ELEM);
    For_Cor_Br=zeros(num_t,3);
        
    Tor_Cor_x=zeros(num_t,num_ELEM);
    Tor_Cor_y=zeros(num_t,num_ELEM);
    Tor_Cor_z=zeros(num_t,num_ELEM);
    Tor_Cor_Br=zeros(num_t,3);

   

    r=zeros(num_ELEM,3);
    m=zeros(num_ELEM,1);

    for i_ELEM=1:num_ELEM
        Volume=Processed_ELEM_LIST{i_ELEM}.Volume;
        centroid=Processed_ELEM_LIST{i_ELEM}.centroid;
        m(i_ELEM)=Volume*rho;
        r(i_ELEM,:)=centroid-TorqueCenter;

        for i_t=1:num_t
                        
            ang_vel=mg_data(i_Case).G_ang_vel(i_t,:);
            vr_toHead=[DataFEM_V_X(i_Case).Field(i_t,i_ELEM),DataFEM_V_Y(i_Case).Field(i_t,i_ELEM),DataFEM_V_Z(i_Case).Field(i_t,i_ELEM)];
            
            %% lin acc calculation
           
            r_i=r(i_ELEM,:);
            m_i=m(i_ELEM);
            
            %% Calculate Coriolis force
            [For_Cor_i,Tor_Cor_i]=Cal_For_Cor(ang_vel,vr_toHead,r_i,m_i);% change unit as m/s^2
            
            For_Cor_x(i_t,i_ELEM)=For_Cor_i(1);
            For_Cor_y(i_t,i_ELEM)=For_Cor_i(2);
            For_Cor_z(i_t,i_ELEM)=For_Cor_i(3);
            
            Tor_Cor_x(i_t,i_ELEM)=Tor_Cor_i(1);
            Tor_Cor_y(i_t,i_ELEM)=Tor_Cor_i(2);
            Tor_Cor_z(i_t,i_ELEM)=Tor_Cor_i(3);
        end
    end

    %% calculate the relative velocity of the whole brain weighted by the mass
    Vel_Br=[sum(DataFEM_V_X(i_Case).Field.*repmat(m',num_t,1),2),sum(DataFEM_V_Y(i_Case).Field.*repmat(m',num_t,1),2),sum(DataFEM_V_Z(i_Case).Field.*repmat(m',num_t,1),2)]/sum(m);
    

    %% Calculate Coriolis force for whole brain
    For_Cor_Br(:,1)=sum(For_Cor_x,2);
    For_Cor_Br(:,2)=sum(For_Cor_y,2);
    For_Cor_Br(:,3)=sum(For_Cor_z,2);
    
    Tor_Cor_Br(:,1)=sum(Tor_Cor_x,2);
    Tor_Cor_Br(:,2)=sum(Tor_Cor_y,2);
    Tor_Cor_Br(:,3)=sum(Tor_Cor_z,2);
    
    %% Assembly Coriolis force
    IntrF(i_Case).For_Cor_x_PerMass=For_Cor_x./m_i;
    IntrF(i_Case).For_Cor_y_PerMass=For_Cor_y./m_i;
    IntrF(i_Case).For_Cor_z_PerMass=For_Cor_z./m_i;

    IntrF(i_Case).For_Cor_x=For_Cor_x;
    IntrF(i_Case).For_Cor_y=For_Cor_y;
    IntrF(i_Case).For_Cor_z=For_Cor_z;

    IntrF(i_Case).Tor_Cor_x_PerMass=Tor_Cor_x./m_i;
    IntrF(i_Case).Tor_Cor_y_PerMass=Tor_Cor_y./m_i;
    IntrF(i_Case).Tor_Cor_z_PerMass=Tor_Cor_z./m_i;

    IntrF(i_Case).Tor_Cor_x=Tor_Cor_x;
    IntrF(i_Case).Tor_Cor_y=Tor_Cor_y;
    IntrF(i_Case).Tor_Cor_z=Tor_Cor_z;
    
    IntrF(i_Case).For_Cor_Br=For_Cor_Br;
    IntrF(i_Case).Tor_Cor_Br=Tor_Cor_Br;

    IntrF(i_Case).Vel_x=DataFEM_V_X(i_Case).Field;
    IntrF(i_Case).Vel_y=DataFEM_V_Y(i_Case).Field;
    IntrF(i_Case).Vel_z=DataFEM_V_Z(i_Case).Field;

    
    IntrF_Br(i_Case).For_Cor_Br=For_Cor_Br;
    IntrF_Br(i_Case).Tor_Cor_Br=Tor_Cor_Br;
    IntrF_Br(i_Case).Vel_Br=Vel_Br;
    
    %% Find the max
    IntrF_Max(i_Case).For_Cor_max=zeros(num_t,1);% just magnitude
    IntrF_Max(i_Case).For_Cor_max=zeros(num_t,1);% just magnitude

    IntrF_Max(i_Case).Vel_max=zeros(num_t,1);% just magnitude of relative velocity
    for i_t=1:num_t
        F_i_t=[IntrF(i_Case).For_Cor_x_PerMass(i_t,:);IntrF(i_Case).For_Cor_y_PerMass(i_t,:);IntrF(i_Case).For_Cor_z_PerMass(i_t,:)];
        IntrF_Max(i_Case).For_Cor_max_PerMass(i_t)=max(sqrt(sum(F_i_t.^2,1)));

        T_i_t=[IntrF(i_Case).Tor_Cor_x_PerMass(i_t,:);IntrF(i_Case).Tor_Cor_y_PerMass(i_t,:);IntrF(i_Case).Tor_Cor_z_PerMass(i_t,:)];
        IntrF_Max(i_Case).Tor_Cor_max_PerMass(i_t)=max(sqrt(sum(T_i_t.^2,1)));

        Vel_i_t=[IntrF(i_Case).Vel_x(i_t,:);IntrF(i_Case).Vel_y(i_t,:);IntrF(i_Case).Vel_z(i_t,:)];
        IntrF_Max(i_Case).Vel_max(i_t)=max(sqrt(sum(Vel_i_t.^2,1)));
    end
    
end
end

function [For_Cor,Tor_Cor]=Cal_For_Cor(ang_vel,vr_toHead,r_i,m)
    For_Cor=-2*m*cross(ang_vel,vr_toHead);
    Tor_Cor=cross(r_i,For_Cor);
end
            
    