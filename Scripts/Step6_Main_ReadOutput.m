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
% 本脚本读取cfile输入的结果，并将结果保存为matlab的格式，每一个算例独立保存一个文件
% 保存格式为结果矩阵，第一维是时间，第二维是Element
% This script reads the results from the cfile input and saves the results in MATLAB format. 
% Each case is saved in a separate file. 
% The saving format is a result matrix, where the first dimension is time and the second dimension is Element.
%% ------------脚本主体 / Script Execution ---------------

import tools_functions.*

%% Load Info
p=load('Info.mat');
Info=p.Info;

%% Pre load all processed elements information;
% FE_Models_Name_array={'KTH','GHBMC','THUMS_og'};

p_KTH=load('Processed_ELEM_LIST_KTH.mat');
NodesIndex_ELEMConnectivity_KTH=p_KTH.NodesIndex_ELEMConnectivity;
ELEM_ID_KTH=p_KTH.ELEM_ID;

p_GHBMC=load('Processed_ELEM_LIST_GHBMC.mat');
NodesIndex_ELEMConnectivity_GHBMC=p_GHBMC.NodesIndex_ELEMConnectivity;
ELEM_ID_GHBMC=p_GHBMC.ELEM_ID;

p_THUMS_og=load('Processed_ELEM_LIST_THUMS_og.mat');
NodesIndex_ELEMConnectivity_THUMS_og=p_THUMS_og.NodesIndex_ELEMConnectivity;
ELEM_ID_THUMS_og=p_THUMS_og.ELEM_ID;


%% Directory
Dir_Project=Info(1).Dir_Project;

Dir_Scripts=strcat(Dir_Project,'\Scripts');
Dir_Data=strcat(Dir_Project,'\Data');
Dir_Data_Results=strcat(Dir_Project,'\Data\Results');
Dir_Data_Results_Output=strcat(Dir_Project,'\Data\Results\Output');
Dir_Data_Results_Field=strcat(Dir_Project,'\Data\Results\Field');

if ~exist(Dir_Data_Results_Field,'dir')
    mkdir(Dir_Data_Results_Field);
end

%% Select Fringe
Fringe=load('Fringe.mat');
Fringe=Fringe.Fringe;

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

%% Select id Case
id_Case=1:length(Info);
Info=Info(id_Case);
num_Case=length(Info);

for i_F=1:num_Fringe
    
    id_Fringe=id_Fringe_read(i_F);
    
    parfor i_Case=1:num_Case
        DataFEM=struct('Field',[],'t',[],'ElementID',[]);% for parellel

        %% Read the Output

        sprintf('Processing %s Case %04u',Fringe(id_Fringe).Name,i_Case)
        Dir_Output=strcat(Dir_Data_Results_Output,'\',Fringe(id_Fringe).Name);
        
        switch Fringe(id_Fringe).At
            case 1
            % At=1 mean the finge is at elements
            % At=2 mean the finge is at nodes. We need to register it to
            % element
            [Field_Elem,t_Elem,ElementID]=ReadOutput_ELEM(Info(i_Case),Fringe(id_Fringe).Name,Dir_Output);
            DataFEM.Field=Field_Elem;
            DataFEM.t=t_Elem;
            DataFEM.ElementID=ElementID;

            case 2
            % At=1 mean the finge is at elements
            % At=2 mean the finge is at nodes. We need to register it to
            % node
            %% Load Element list
            NodesIndex_ELEMConnectivity=[];% for parellel
            ELEM_ID=[];% for parellel
            switch Info(i_Case).FE_Model_Name
                case 'KTH'
                    NodesIndex_ELEMConnectivity=NodesIndex_ELEMConnectivity_KTH;
                    ELEM_ID=ELEM_ID_KTH;
                case 'GHBMC'
                    NodesIndex_ELEMConnectivity=NodesIndex_ELEMConnectivity_GHBMC;
                    ELEM_ID=ELEM_ID_GHBMC;
                case 'THUMS_og'
                    NodesIndex_ELEMConnectivity=NodesIndex_ELEMConnectivity_THUMS_og;
                    ELEM_ID=ELEM_ID_THUMS_og;
            end
            % y=NodesIndex_ELEMConnectivity(x), 
            % x is the index of elements (element ID sorted sequentially, same as in output file)
            % y is the index of nodes (node ID sorted sequentially, same as in output file)
            [Field_node,t_node,NodeID]=ReadOutput_Node(Info(i_Case),Fringe(id_Fringe).Name,Dir_Output);
            
            [Field_New]=Register_FromELEM_ToNODE(Field_node,t_node,NodesIndex_ELEMConnectivity);
            DataFEM.Field=Field_New;
            DataFEM.ElementID=ELEM_ID;
            DataFEM.t=t_node;
        end
            
            % Unit update
            fringe_unit_m=Fringe(id_Fringe).unit_m;
            fringe_unit_s=Fringe(id_Fringe).unit_s;
            fringe_unit_kg=Fringe(id_Fringe).unit_kg;
            DataFEM.t=DataFEM.t*Info(i_Case).Model_Unit_System(2);
            DataFEM.Field=DataFEM.Field*prod(Info(i_Case).Model_Unit_System.^[fringe_unit_m,fringe_unit_s,fringe_unit_kg]);
        
        Folder=strcat(Dir_Data_Results_Field,'\',Fringe(id_Fringe).Name);
        if ~exist(Folder,'dir')
            mkdir(Folder);
        end

        File_Field=strcat(Dir_Data_Results_Field,'\',Fringe(id_Fringe).Name,'\',Fringe(id_Fringe).Name,'_',Info(i_Case).CaseName,'.mat');
        Save(File_Field,DataFEM)
    end
end

function Save(File_Field,DataFEM)
    save(File_Field,'DataFEM','-v7.3');
end


%% Function

function [Field,t,Element_ID]=ReadOutput_ELEM(Info,FringeName,Dir_Output)
% 该函数读取LS-prepost输出的csv文件，并将其转化为.mat文件
% 编辑者：Yuzhe

%% 目录设置
t0 = Info.t; % FE输入文件中的时间t
num_t0 = length(t0);

t = zeros(num_t0, 1); % FE输出文件中的时间t

% StartFrame=1;
EndFrame = num_t0;
FrameInterval = 1;

%% 读取第1帧数据
% delimiterIn=' ';
% headerlinesIn=8;

% 数据起始行
DataStartLine = 7;
NumVariables = 2;
VariableNames = {'ID', 'Value'};
VariableWidths = [10, 30];
DataType = {'double', 'double'};

% 设置读取选项
opts = fixedWidthImportOptions('NumVariables', NumVariables, ...
                               'DataLines', DataStartLine, ...
                               'VariableNames', VariableNames, ...
                               'VariableWidths', VariableWidths, ...
                               'VariableTypes', DataType);

i_Frame = 1;
    
    % 拼接输出文件名
    OutputFile = strcat(Dir_Output, '\', FringeName, '_', Info.CaseName, '\', FringeName, '_', Info.CaseName, sprintf('_Frame%04u', i_Frame));
    
    % 读取数据
    T = readtable(OutputFile, opts);
    A = table2array(T);

    % 去除包含NaN的行
    pA = isnan(A);
    IDrowKill = pA(:, 1) | pA(:, 2);
    A(IDrowKill, :) = [];

    num_Elem = size(A, 1);   
    Element_ID = A(:, 1);
    Field = zeros(num_t0, num_Elem);
    Field(i_Frame, :) = (A(:, 2))';
    
    % 读取时间信息
    fid = fopen(OutputFile);
    fgetl(fid); % 忽略第一行
    l = fgetl(fid); % 使用第二行获取时间信息
    Time_Text = l(16:end);
    t(i_Frame) = str2num(Time_Text); %#ok<ST2NM>
    fclose(fid);
    
for i_Frame = 2:FrameInterval:EndFrame
    OutputFile = strcat(Dir_Output, '\', FringeName, '_', Info.CaseName, '\', FringeName, '_', Info.CaseName, sprintf('_Frame%04u', i_Frame));
    
    % 读取数据
    T = readtable(OutputFile, opts);
    A = table2array(T);

    % 去除包含NaN的行
    pA = isnan(A);
    IDrowKill = pA(:, 1) | pA(:, 2);
    A(IDrowKill, :) = [];

    Field(i_Frame, :) = (A(:, 2))';
    
    % 读取时间信息
    fid = fopen(OutputFile);
    fgetl(fid); % 忽略第一行
    l = fgetl(fid); % 使用第二行获取时间信息
    Time_Text = l(16:end);
    t(i_Frame) = str2num(Time_Text); %#ok<ST2NM>
    fclose(fid);
end
end

function [Field,t,NodeID]=ReadOutput_Node(Info,FringeName,Dir_Output)
% 该函数读取LS-prepost输出的csv文件，并将其转化为.mat文件
% 编辑者：Yuzhe

%% 目录设置
t0 = Info.t; % FE输入文件中的时间t
num_t0 = length(t0);

t = zeros(num_t0, 1); % FE输出文件中的时间t

% StartFrame=1;
EndFrame = num_t0;
FrameInterval = 1;

%% 读取第1帧数据
% delimiterIn=' ';
% headerlinesIn=8;

% 数据起始行
DataStartLine = 7;
NumVariables = 2;
VariableNames = {'ID', 'Value'};
VariableWidths = [10, 30];
DataType = {'double', 'double'};

% 设置读取选项
opts = fixedWidthImportOptions('NumVariables', NumVariables, ...
                               'DataLines', DataStartLine, ...
                               'VariableNames', VariableNames, ...
                               'VariableWidths', VariableWidths, ...
                               'VariableTypes', DataType);

i_Frame = 1;
    
    % 拼接输出文件名
    OutputFile = strcat(Dir_Output, '\', FringeName, '_', Info.CaseName, '\', FringeName, '_', Info.CaseName, sprintf('_Frame%04u', i_Frame));
    
    % 读取数据
    T = readtable(OutputFile, opts);
    A = table2array(T);

    num_Elem = size(A, 1);   
    NodeID = A(:, 1);
    Field = zeros(num_t0, num_Elem);
    Field(i_Frame, :) = (A(:, 2))';
    
    % 读取时间信息
    fid = fopen(OutputFile);
    fgetl(fid); % 忽略第一行
    l = fgetl(fid); % 使用第二行获取时间信息
    Time_Text = l(16:end);
    t(i_Frame) = str2num(Time_Text); %#ok<ST2NM>
    fclose(fid);
    
for i_Frame = 2:FrameInterval:EndFrame
    OutputFile = strcat(Dir_Output, '\', FringeName, '_', Info.CaseName, '\', FringeName, '_', Info.CaseName, sprintf('_Frame%04u', i_Frame));
    
    % 读取数据
    T = readtable(OutputFile, opts);
    A = table2array(T);

    Field(i_Frame, :) = (A(:, 2))';
    
    % 读取时间信息
    fid = fopen(OutputFile);
    fgetl(fid); % 忽略第一行
    l = fgetl(fid); % 使用第二行获取时间信息
    Time_Text = l(16:end);
    t(i_Frame) = str2num(Time_Text); %#ok<ST2NM>
    fclose(fid);
end

%% 最后一行返回NaN值
Field = Field(:, 1:end-1);
NodeID = NodeID(1:end-1);
end

function [Field_New] = Register_FromELEM_ToNODE(Field, t, NodesIndex_ELEMConnectivity)
% 该函数将元素的信息注册到节点上
% 例如：六面体元素

num_ELEM = size(NodesIndex_ELEMConnectivity, 1);
num_t = length(t);
Field_New = zeros(num_t, num_ELEM);

% 对每个元素，按节点累加
for i_ELEM = 1:num_ELEM
    for i_node = 1:8 % 每个元素有8个节点
        Index_node = NodesIndex_ELEMConnectivity(i_ELEM, i_node);
        Field_New(:, i_ELEM) = Field_New(:, i_ELEM) + Field(:, Index_node);
    end
end

% 求平均值
Field_New = Field_New / 8;
end

    
    