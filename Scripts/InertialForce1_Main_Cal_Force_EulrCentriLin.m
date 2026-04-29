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
% 注意，因为科里奥利力计算需要相对速度，所以需要基于有限元计算结果再计算科里奥利力。因此将再另一个脚本中进行计算。
% 平动力 impressed force: f=-ma
% # is cross
% 欧拉力 Eular force: f=-m*ang_acc#r
% 离心力 Centrifugal force: f=-m*ang_vel#(ang_vel#r)
% 科里奥利里 Coriolis force: f=-2m*ang_vel#vr
% 该脚本将产生IntrF_BCG_EulrCentriLin，其中保存了平动力，欧拉力和离心力非惯性力的时空分布;IntrF_Br_BCG_EulrCentriLin，其中保存了任意时刻大脑整体上向量求和的结果
% IntrF_Max_EulrCentriLin，其中保存了任意时刻空间上最大的模量的结果
%% ------------脚本主体 / Script Execution --------------- 

import tools_functions.*

%% 加载信息
p = load('info.mat'); % 加载 info.mat 文件
Info = p.Info; % 提取 Info 结构体

%% 加载元素列表
% 加载 KTH 模型的元素列表
p_KTH = load('Processed_ELEM_LIST_KTH.mat');
Processed_ELEM_LIST_KTH = p_KTH.Processed_ELEM_LIST; % 提取处理后的元素列表
ELEM_ID_KTH = p_KTH.ELEM_ID; % 提取元素 ID

% 加载 GHBMC 模型的元素列表
p_GHBMC = load('Processed_ELEM_LIST_GHBMC.mat');
Processed_ELEM_LIST_GHBMC = p_GHBMC.Processed_ELEM_LIST; % 提取处理后的元素列表
ELEM_ID_GHBMC = p_GHBMC.ELEM_ID; % 提取元素 ID

% 加载 THUMS_og 模型的元素列表
p_THUMS_og = load('Processed_ELEM_LIST_THUMS_og.mat');
Processed_ELEM_LIST_THUMS_og = p_THUMS_og.Processed_ELEM_LIST; % 提取处理后的元素列表
ELEM_ID_THUMS_og = p_THUMS_og.ELEM_ID; % 提取元素 ID

%% 设置目录
Dir_Project = Info(1).Dir_Project; % 项目根目录

% 构建脚本、运动学数据和结果数据的目录路径
Dir_Scripts = strcat(Dir_Project, '\Scripts');
Dir_Data_Kinematics = strcat(Dir_Project, '\Data\Kinematics');
Dir_Data_Results_Field = strcat(Dir_Project, '\Data\Results\Field');
Dir_Data_Results_Field_space = strcat(Dir_Project, '\Data\Results\Field_space');

% 如果结果目录不存在，则创建
if ~exist(Dir_Data_Results_Field, 'dir')
    mkdir(Dir_Data_Results_Field);
end

if ~exist(Dir_Data_Results_Field_space, 'dir')
    mkdir(Dir_Data_Results_Field_space);
end

%% 选择案例 ID
id_Case = 1:length(Info); % 选择所有案例
Info = Info(id_Case); % 更新 Info 结构体
num_Case = length(Info); % 获取案例数量

%% 读取运动学数据
File_Kinematics = strcat(Dir_Data_Kinematics, '\Kinematics_Processed.mat');
p = load(File_Kinematics); % 加载运动学数据
mg_data = p.mg_data; % 提取运动学数据（所有模型的 SI 单位数据）

%% 计算力
IntrF_Br_BCG = struct([]); % 初始化存储脑部惯性力的结构体
IntrF_Max = struct([]); % 初始化存储最大力的结构体

mg_data_modelunit = mg_data; % 复制运动学数据以转换为模型单位

% 遍历每个案例
parfor i_Case=1:num_Case
% for i_Case = 1:num_Case
    %% 更新模型单位（因为节点数据使用模型单位）
    Model_Unit_System = Info(i_Case).Model_Unit_System; % 获取模型单位系统

    m_modelorder = Model_Unit_System(1); % 长度单位
    s_modelorder = Model_Unit_System(2); % 时间单位
    kg_modelorder = Model_Unit_System(3); % 质量单位

    TorqueCenter = Info(i_Case).Brain_Center / m_modelorder; % 脑部扭矩中心
    rho = Info(i_Case).Density / (kg_modelorder / m_modelorder^3); % 密度

    % 将运动学数据转换为模型单位
    mg_data_modelunit(i_Case).t = mg_data(i_Case).t / s_modelorder;
    mg_data_modelunit(i_Case).ang_acc = mg_data(i_Case).ang_acc * s_modelorder^2;
    mg_data_modelunit(i_Case).ang_vel = mg_data(i_Case).ang_vel * s_modelorder;
    mg_data_modelunit(i_Case).lin_acc_CG = mg_data(i_Case).lin_acc_CG / (m_modelorder / s_modelorder^2);
    mg_data_modelunit(i_Case).lin_acc_BCG = mg_data(i_Case).lin_acc_BCG / (m_modelorder / s_modelorder^2);
    mg_data_modelunit(i_Case).G_ang_acc = mg_data(i_Case).G_ang_acc * s_modelorder^2;
    mg_data_modelunit(i_Case).G_ang_vel = mg_data(i_Case).G_ang_vel * s_modelorder;
    mg_data_modelunit(i_Case).G_lin_acc_CG = mg_data(i_Case).G_lin_acc_CG / (m_modelorder / s_modelorder^2);
    mg_data_modelunit(i_Case).G_lin_acc_BCG = mg_data(i_Case).G_lin_acc_BCG / (m_modelorder / s_modelorder^2);

    sprintf('Processing EulrCentriLinear %u in %u', i_Case, num_Case) % 打印处理进度

    % 根据模型名称选择元素列表
    Processed_ELEM_LIST = [];
    switch Info(i_Case).FE_Model_Name
        case 'KTH'
            Processed_ELEM_LIST = Processed_ELEM_LIST_KTH;
        case 'GHBMC'
            Processed_ELEM_LIST = Processed_ELEM_LIST_GHBMC;
        case 'THUMS_og'
            Processed_ELEM_LIST = Processed_ELEM_LIST_THUMS_og;
    end

    % 计算惯性力
    [IntrF_BCG, IntrF_Br_BCG_i, IntrF_Max_i] = Cal_InertialForce_EulrCentriLin(mg_data_modelunit(i_Case), Processed_ELEM_LIST, rho, TorqueCenter);

    % 将结果转换为 SI 单位
    IntrF_BCG_SIunit = Transfer_UnitSystem_IntrF(IntrF_BCG, Model_Unit_System);
    IntrF_Br_BCG_i_SIunit = Transfer_UnitSystem_IntrF(IntrF_Br_BCG_i, Model_Unit_System);
    IntrF_Max_i_SIunit = Transfer_UnitSystem_IntrF(IntrF_Max_i, Model_Unit_System);

    % 保存结果
    Folder = strcat(Dir_Data_Results_Field, '\IntrF_BCG_EulrCentriLin');
    if ~exist(Folder, 'dir')
        mkdir(Folder)
    end

    File_InertialForce = strcat(Folder, '\IntrF_BCG_EulrCentriLin_', Info(i_Case).CaseName, '.mat');
    IntrF_BCG = IntrF_BCG_SIunit;
    Save(File_InertialForce, IntrF_BCG); % 保存结果

    %% 计算脑部惯性力和扭矩
    IntrF_Br_BCG(i_Case).t = IntrF_Br_BCG_i_SIunit.t;
    IntrF_Max(i_Case).t = IntrF_Br_BCG_i_SIunit.t;

    %% 组装惯性力
    IntrF_Br_BCG(i_Case).For_impr_Br = IntrF_Br_BCG_i_SIunit.For_impr_Br;
    IntrF_Br_BCG(i_Case).Tor_impr_Br = IntrF_Br_BCG_i_SIunit.Tor_impr_Br;
    IntrF_Max(i_Case).For_impr_max_PerMass = IntrF_Max_i_SIunit.For_impr_max_PerMass;
    IntrF_Max(i_Case).Tor_impr_max_PerMass = IntrF_Max_i_SIunit.Tor_impr_max_PerMass;

    %% 组装离心力
    IntrF_Br_BCG(i_Case).For_cenf_Br = IntrF_Br_BCG_i_SIunit.For_cenf_Br;
    IntrF_Br_BCG(i_Case).Tor_cenf_Br = IntrF_Br_BCG_i_SIunit.Tor_cenf_Br;
    IntrF_Max(i_Case).For_cenf_max_PerMass = IntrF_Max_i_SIunit.For_cenf_max_PerMass;
    IntrF_Max(i_Case).Tor_cenf_max_PerMass = IntrF_Max_i_SIunit.Tor_cenf_max_PerMass;

    %% 组装欧拉力
    IntrF_Br_BCG(i_Case).For_Eulr_Br = IntrF_Br_BCG_i_SIunit.For_Eulr_Br;
    IntrF_Br_BCG(i_Case).Tor_Eulr_Br = IntrF_Br_BCG_i_SIunit.Tor_Eulr_Br;
    IntrF_Max(i_Case).For_Eulr_max_PerMass = IntrF_Max_i_SIunit.For_Eulr_max_PerMass;
    IntrF_Max(i_Case).Tor_Eulr_max_PerMass = IntrF_Max_i_SIunit.Tor_Eulr_max_PerMass;

    %% 组装总力
    IntrF_Br_BCG(i_Case).Tor_EulrCentriLin = IntrF_Br_BCG_i_SIunit.Tor_EulrCentriLin;
    IntrF_Max(i_Case).For_EulrCentriLin_max = IntrF_Max_i_SIunit.For_EulrCentriLin_max;
    IntrF_Max(i_Case).Tor_EulrCentriLin_max = IntrF_Max_i_SIunit.Tor_EulrCentriLin_max;
end

%% 保存结果
File_InertialForce_WholeBrain = strcat(Dir_Data_Results_Field_space, '\IntrF_Br_EulrCentriLin.mat');
save(File_InertialForce_WholeBrain, 'IntrF_Br_BCG', '-v7.3'); % 保存脑部惯性力结果

File_InertialForce_WholeBrain = strcat(Dir_Data_Results_Field_space, '\IntrF_Max_EulrCentriLin.mat');
save(File_InertialForce_WholeBrain, 'IntrF_Max', '-v7.3'); % 保存最大力结果

%% 辅助函数
function Save(File_InertialForce, IntrF_BCG)
    save(File_InertialForce, 'IntrF_BCG', '-v7.3'); % 保存惯性力数据
end

function [IntrF, IntrF_Br, IntrF_Max] = Cal_InertialForce_EulrCentriLin(mg_data, Processed_ELEM_LIST, rho, TorqueCenter)
    % 计算惯性力、离心力和欧拉力
    % 确保运动学数据、元素位置、密度和扭矩中心使用相同的单位系统

    num_Case = length(mg_data);
    num_ELEM = length(Processed_ELEM_LIST);
    IntrF = struct([]);
    IntrF_Br = struct([]);
    IntrF_Max = struct([]); % 用于保存每个元素的最大力

    num_Elem = length(Processed_ELEM_LIST);
    ElementID = zeros(1, num_Elem);
    for i_Elem = 1:num_Elem
        ElementID(i_Elem) = Processed_ELEM_LIST{i_Elem}.elID; % 提取元素 ID
    end

    % 计算每个元素的质量和位置
    r = zeros(num_ELEM, 3);
    m = zeros(num_ELEM, 1);
    for i_ELEM = 1:num_ELEM
        Volume = Processed_ELEM_LIST{i_ELEM}.Volume; % 元素体积
        centroid = Processed_ELEM_LIST{i_ELEM}.centroid; % 元素质心
        m(i_ELEM) = Volume * rho; % 计算质量
        r(i_ELEM, :) = centroid - TorqueCenter; % 计算位置
    end

    % 计算每个时间步的力
    for i_Case = 1:num_Case
        t = mg_data(i_Case).t;
        num_t = length(t);

        IntrF(i_Case).t = t;
        IntrF(i_Case).ElementID = ElementID;
        IntrF_Br(i_Case).t = t;
        IntrF_Br(i_Case).ElementID = ElementID;

        % 初始化力矩阵
        For_impr_x = zeros(num_t, num_ELEM);
        For_impr_y = zeros(num_t, num_ELEM);
        For_impr_z = zeros(num_t, num_ELEM);
        For_impr_Br = zeros(num_t, 3);

        Tor_impr_x = zeros(num_t, num_ELEM);
        Tor_impr_y = zeros(num_t, num_ELEM);
        Tor_impr_z = zeros(num_t, num_ELEM);
        Tor_impr_Br = zeros(num_t, 3);

        For_cenf_x = zeros(num_t, num_ELEM);
        For_cenf_y = zeros(num_t, num_ELEM);
        For_cenf_z = zeros(num_t, num_ELEM);
        For_cenf_Br = zeros(num_t, 3);

        Tor_cenf_x = zeros(num_t, num_ELEM);
        Tor_cenf_y = zeros(num_t, num_ELEM);
        Tor_cenf_z = zeros(num_t, num_ELEM);
        Tor_cenf_Br = zeros(num_t, 3);

        For_Eulr_x = zeros(num_t, num_ELEM);
        For_Eulr_y = zeros(num_t, num_ELEM);
        For_Eulr_z = zeros(num_t, num_ELEM);
        For_Eulr_Br = zeros(num_t, 3);

        Tor_Eulr_x = zeros(num_t, num_ELEM);
        Tor_Eulr_y = zeros(num_t, num_ELEM);
        Tor_Eulr_z = zeros(num_t, num_ELEM);
        Tor_Eulr_Br = zeros(num_t, 3);

        % 计算每个时间步的力
        for i_t = 1:num_t
            ang_vel = mg_data(i_Case).G_ang_vel(i_t, :);
            ang_acc = mg_data(i_Case).G_ang_acc(i_t, :);
            lin_acc = mg_data(i_Case).G_lin_acc_BCG(i_t, :);

            g = 9.81; % 重力加速度

            %% 计算惯性力
            [F_impr_i, Tor_impr_i] = Cal_F_impr(lin_acc * g, r, m);
            For_impr_x(i_t, :) = F_impr_i(:, 1)';
            For_impr_y(i_t, :) = F_impr_i(:, 2)';
            For_impr_z(i_t, :) = F_impr_i(:, 3)';

            Tor_impr_x(i_t, :) = Tor_impr_i(:, 1)';
            Tor_impr_y(i_t, :) = Tor_impr_i(:, 2)';
            Tor_impr_z(i_t, :) = Tor_impr_i(:, 3)';

            %% 计算离心力
            [F_cenf_i, Tor_cenf_i] = Cal_F_cenf(ang_vel, r, m);
            For_cenf_x(i_t, :) = F_cenf_i(:, 1)';
            For_cenf_y(i_t, :) = F_cenf_i(:, 2)';
            For_cenf_z(i_t, :) = F_cenf_i(:, 3)';

            Tor_cenf_x(i_t, :) = Tor_cenf_i(:, 1)';
            Tor_cenf_y(i_t, :) = Tor_cenf_i(:, 2)';
            Tor_cenf_z(i_t, :) = Tor_cenf_i(:, 3)';

            %% 计算欧拉力
            [F_Eulr_i, Tor_Eulr_i] = Cal_F_Eulr(ang_acc, r, m);
            For_Eulr_x(i_t, :) = F_Eulr_i(:, 1)';
            For_Eulr_y(i_t, :) = F_Eulr_i(:, 2)';
            For_Eulr_z(i_t, :) = F_Eulr_i(:, 3)';

            Tor_Eulr_x(i_t, :) = Tor_Eulr_i(:, 1)';
            Tor_Eulr_y(i_t, :) = Tor_Eulr_i(:, 2)';
            Tor_Eulr_z(i_t, :) = Tor_Eulr_i(:, 3)';
        end

        %% 组装脑部惯性力
        For_impr_Br(:, 1) = sum(For_impr_x, 2);
        For_impr_Br(:, 2) = sum(For_impr_y, 2);
        For_impr_Br(:, 3) = sum(For_impr_z, 2);

        Tor_impr_Br(:, 1) = sum(Tor_impr_x, 2);
        Tor_impr_Br(:, 2) = sum(Tor_impr_y, 2);
        Tor_impr_Br(:, 3) = sum(Tor_impr_z, 2);

        %% 组装脑部离心力
        For_cenf_Br(:, 1) = sum(For_cenf_x, 2);
        For_cenf_Br(:, 2) = sum(For_cenf_y, 2);
        For_cenf_Br(:, 3) = sum(For_cenf_z, 2);

        Tor_cenf_Br(:, 1) = sum(Tor_cenf_x, 2);
        Tor_cenf_Br(:, 2) = sum(Tor_cenf_y, 2);
        Tor_cenf_Br(:, 3) = sum(Tor_cenf_z, 2);

        %% 组装脑部欧拉力
        For_Eulr_Br(:, 1) = sum(For_Eulr_x, 2);
        For_Eulr_Br(:, 2) = sum(For_Eulr_y, 2);
        For_Eulr_Br(:, 3) = sum(For_Eulr_z, 2);

        Tor_Eulr_Br(:, 1) = sum(Tor_Eulr_x, 2);
        Tor_Eulr_Br(:, 2) = sum(Tor_Eulr_y, 2);
        Tor_Eulr_Br(:, 3) = sum(Tor_Eulr_z, 2);

        %% 组装惯性力
        IntrF(i_Case).For_impr_x = For_impr_x;
        IntrF(i_Case).For_impr_y = For_impr_y;
        IntrF(i_Case).For_impr_z = For_impr_z;

        IntrF(i_Case).For_impr_x_PerMass = For_impr_x ./ repelem(m', size(For_impr_x, 1), 1);
        IntrF(i_Case).For_impr_y_PerMass = For_impr_y ./ repelem(m', size(For_impr_y, 1), 1);
        IntrF(i_Case).For_impr_z_PerMass = For_impr_z ./ repelem(m', size(For_impr_z, 1), 1);

        IntrF(i_Case).Tor_impr_x = Tor_impr_x;
        IntrF(i_Case).Tor_impr_y = Tor_impr_y;
        IntrF(i_Case).Tor_impr_z = Tor_impr_z;

        IntrF(i_Case).Tor_impr_x_PerMass = Tor_impr_x ./ repelem(m', size(Tor_impr_x, 1), 1);
        IntrF(i_Case).Tor_impr_y_PerMass = Tor_impr_y ./ repelem(m', size(Tor_impr_y, 1), 1);
        IntrF(i_Case).Tor_impr_z_PerMass = Tor_impr_z ./ repelem(m', size(Tor_impr_z, 1), 1);

        IntrF(i_Case).For_impr_Br = For_impr_Br;
        IntrF(i_Case).Tor_impr_Br = Tor_impr_Br;

        IntrF_Br(i_Case).For_impr_Br = For_impr_Br;
        IntrF_Br(i_Case).Tor_impr_Br = Tor_impr_Br;

        %% 组装离心力
        IntrF(i_Case).For_cenf_x = For_cenf_x;
        IntrF(i_Case).For_cenf_y = For_cenf_y;
        IntrF(i_Case).For_cenf_z = For_cenf_z;

        IntrF(i_Case).For_cenf_x_PerMass = For_cenf_x ./ repelem(m', size(For_cenf_x, 1), 1);
        IntrF(i_Case).For_cenf_y_PerMass = For_cenf_y ./ repelem(m', size(For_cenf_y, 1), 1);
        IntrF(i_Case).For_cenf_z_PerMass = For_cenf_z ./ repelem(m', size(For_cenf_z, 1), 1);

        IntrF(i_Case).Tor_cenf_x = Tor_cenf_x;
        IntrF(i_Case).Tor_cenf_y = Tor_cenf_y;
        IntrF(i_Case).Tor_cenf_z = Tor_cenf_z;

        IntrF(i_Case).Tor_cenf_x_PerMass = Tor_cenf_x ./ repelem(m', size(Tor_cenf_x, 1), 1);
        IntrF(i_Case).Tor_cenf_y_PerMass = Tor_cenf_y ./ repelem(m', size(Tor_cenf_y, 1), 1);
        IntrF(i_Case).Tor_cenf_z_PerMass = Tor_cenf_z ./ repelem(m', size(Tor_cenf_z, 1), 1);

        IntrF(i_Case).For_cenf_Br = For_cenf_Br;
        IntrF(i_Case).Tor_cenf_Br = Tor_cenf_Br;

        IntrF_Br(i_Case).For_cenf_Br = For_cenf_Br;
        IntrF_Br(i_Case).Tor_cenf_Br = Tor_cenf_Br;

        %% 组装欧拉力
        IntrF(i_Case).For_Eulr_x = For_Eulr_x;
        IntrF(i_Case).For_Eulr_y = For_Eulr_y;
        IntrF(i_Case).For_Eulr_z = For_Eulr_z;

        IntrF(i_Case).For_Eulr_x_PerMass = For_Eulr_x ./ repelem(m', size(For_Eulr_x, 1), 1);
        IntrF(i_Case).For_Eulr_y_PerMass = For_Eulr_y ./ repelem(m', size(For_Eulr_y, 1), 1);
        IntrF(i_Case).For_Eulr_z_PerMass = For_Eulr_z ./ repelem(m', size(For_Eulr_z, 1), 1);

        IntrF(i_Case).Tor_Eulr_x = Tor_Eulr_x;
        IntrF(i_Case).Tor_Eulr_y = Tor_Eulr_y;
        IntrF(i_Case).Tor_Eulr_z = Tor_Eulr_z;

        IntrF(i_Case).Tor_Eulr_x_PerMass = Tor_Eulr_x ./ repelem(m', size(Tor_Eulr_x, 1), 1);
        IntrF(i_Case).Tor_Eulr_y_PerMass = Tor_Eulr_y ./ repelem(m', size(Tor_Eulr_y, 1), 1);
        IntrF(i_Case).Tor_Eulr_z_PerMass = Tor_Eulr_z ./ repelem(m', size(Tor_Eulr_z, 1), 1);

        IntrF(i_Case).For_Eulr_Br = For_Eulr_Br;
        IntrF(i_Case).Tor_Eulr_Br = Tor_Eulr_Br;

        IntrF_Br(i_Case).For_Eulr_Br = For_Eulr_Br;
        IntrF_Br(i_Case).Tor_Eulr_Br = Tor_Eulr_Br;

        IntrF_Br(i_Case).Tor_EulrCentriLin = IntrF_Br(i_Case).Tor_Eulr_Br + IntrF_Br(i_Case).Tor_cenf_Br + IntrF_Br(i_Case).Tor_impr_Br;

        %% 计算最大力
        % 力
        IntrF_Max(i_Case).For_Eulr_max = zeros(num_t, 1); % 最大欧拉力
        for i_t = 1:num_t
            F_i_t = [IntrF(i_Case).For_Eulr_x_PerMass(i_t, :); IntrF(i_Case).For_Eulr_y_PerMass(i_t, :); IntrF(i_Case).For_Eulr_z_PerMass(i_t, :)];
            IntrF_Max(i_Case).For_Eulr_max_PerMass(i_t) = max(sqrt(sum(F_i_t.^2, 1)));
        end

        IntrF_Max(i_Case).F_cenf_max = zeros(num_t, 1); % 最大离心力
        for i_t = 1:num_t
            F_i_t = [IntrF(i_Case).For_cenf_x_PerMass(i_t, :); IntrF(i_Case).For_cenf_y_PerMass(i_t, :); IntrF(i_Case).For_cenf_z_PerMass(i_t, :)];
            IntrF_Max(i_Case).For_cenf_max_PerMass(i_t) = max(sqrt(sum(F_i_t.^2, 1)));
        end

        IntrF_Max(i_Case).For_impr_max = zeros(num_t, 1); % 最大惯性力
        for i_t = 1:num_t
            F_i_t = [IntrF(i_Case).For_impr_x_PerMass(i_t, :); IntrF(i_Case).For_impr_y_PerMass(i_t, :); IntrF(i_Case).For_impr_z_PerMass(i_t, :)];
            IntrF_Max(i_Case).For_impr_max_PerMass(i_t) = max(sqrt(sum(F_i_t.^2, 1)));
        end

        IntrF_Max(i_Case).For_EulrCentriLin_max = zeros(num_t, 1); % 最大总力
        for i_t = 1:num_t
            F_i_t = [IntrF(i_Case).For_Eulr_x_PerMass(i_t, :) + IntrF(i_Case).For_cenf_x_PerMass(i_t, :) + IntrF(i_Case).For_impr_x_PerMass; ...
                IntrF(i_Case).For_Eulr_y_PerMass(i_t, :) + IntrF(i_Case).For_cenf_y_PerMass(i_t, :) + IntrF(i_Case).For_impr_y_PerMass; ...
                IntrF(i_Case).For_Eulr_z_PerMass(i_t, :) + IntrF(i_Case).For_cenf_z_PerMass(i_t, :) + IntrF(i_Case).For_impr_z_PerMass];
            IntrF_Max(i_Case).For_EulrCentriLin_max(i_t) = max(sqrt(sum(F_i_t.^2, 1)));
        end

        % 扭矩
        IntrF_Max(i_Case).Tor_Eulr_max = zeros(num_t, 1); % 最大欧拉扭矩
        for i_t = 1:num_t
            F_i_t = [IntrF(i_Case).Tor_Eulr_x_PerMass(i_t, :); IntrF(i_Case).Tor_Eulr_y_PerMass(i_t, :); IntrF(i_Case).Tor_Eulr_z_PerMass(i_t, :)];
            IntrF_Max(i_Case).Tor_Eulr_max_PerMass(i_t) = max(sqrt(sum(F_i_t.^2, 1)));
        end

        IntrF_Max(i_Case).For_cenf_max = zeros(num_t, 1); % 最大离心扭矩
        for i_t = 1:num_t
            F_i_t = [IntrF(i_Case).Tor_cenf_x_PerMass(i_t, :); IntrF(i_Case).Tor_cenf_y_PerMass(i_t, :); IntrF(i_Case).Tor_cenf_z_PerMass(i_t, :)];
            IntrF_Max(i_Case).Tor_cenf_max_PerMass(i_t) = max(sqrt(sum(F_i_t.^2, 1)));
        end

        IntrF_Max(i_Case).Tor_impr_max = zeros(num_t, 1); % 最大惯性扭矩
        for i_t = 1:num_t
            F_i_t = [IntrF(i_Case).Tor_impr_x_PerMass(i_t, :); IntrF(i_Case).Tor_impr_y_PerMass(i_t, :); IntrF(i_Case).Tor_impr_z_PerMass(i_t, :)];
            IntrF_Max(i_Case).Tor_impr_max_PerMass(i_t) = max(sqrt(sum(F_i_t.^2, 1)));
        end

        IntrF_Max(i_Case).Tor_EulrCentriLin_max = zeros(num_t, 1); % 最大总扭矩
        for i_t = 1:num_t
            F_i_t = [IntrF(i_Case).Tor_Eulr_x_PerMass(i_t, :) + IntrF(i_Case).Tor_cenf_x_PerMass(i_t, :) + IntrF(i_Case).Tor_impr_x_PerMass; ...
                IntrF(i_Case).Tor_Eulr_y_PerMass(i_t, :) + IntrF(i_Case).Tor_cenf_y_PerMass(i_t, :) + IntrF(i_Case).Tor_impr_y_PerMass; ...
                IntrF(i_Case).Tor_Eulr_z_PerMass(i_t, :) + IntrF(i_Case).Tor_cenf_z_PerMass(i_t, :) + IntrF(i_Case).Tor_impr_z_PerMass];
            IntrF_Max(i_Case).Tor_EulrCentriLin_max(i_t) = max(sqrt(sum(F_i_t.^2, 1)));
        end
    end
end

function [F_impr, Tor_impr] = Cal_F_impr(lin_acc_CG, r, m)
    % 计算惯性力
    num_ELEM = size(r, 1);
    m_m = repelem(m, 1, 3);
    lin_acc_CG_m = repelem(lin_acc_CG, num_ELEM, 1);

    F_impr = -m_m .* lin_acc_CG_m; % 惯性力
    Tor_impr = cross(r, F_impr, 2); % 惯性扭矩
end

function [F_cenf, Tor_cenf] = Cal_F_cenf(ang_vel, r, m)
    % 计算离心力
    num_ELEM = size(r, 1);
    m_m = repelem(m, 1, 3);
    ang_vel_m = repelem(ang_vel, num_ELEM, 1);

    F_cenf = -m_m .* cross(ang_vel_m, cross(ang_vel_m, r, 2), 2); % 离心力
    Tor_cenf = cross(r, F_cenf, 2); % 离心扭矩
end

function [F_Eulr, Tor_Eulr] = Cal_F_Eulr(ang_acc, r, m)
    % 计算欧拉力
    num_ELEM = size(r, 1);
    m_m = repelem(m, 1, 3);
    ang_acc_m = repelem(ang_acc, num_ELEM, 1);

    F_Eulr = -m_m .* cross(ang_acc_m, r, 2); % 欧拉力
    Tor_Eulr = cross(r, F_Eulr, 2); % 欧拉扭矩
end
