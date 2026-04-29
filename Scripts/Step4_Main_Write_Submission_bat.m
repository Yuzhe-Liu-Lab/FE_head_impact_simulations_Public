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
% 本脚本将生成在windows系统下的计算提交文件，可以实现多线程提交
% 在不同电脑上需要调整求解器的位置
% This script writes the batch file to submit the FE simulation based on
% ls-dyna. The location of solver should be updated for different
% enviroment
% 
%% ------------脚本主体 / Script Execution --------------- 

import tools_functions.*

%% Load Info
% 加载 info.mat 文件，其中包含所有案例的基本信息
% Load the info.mat file, which contains all case information
p = load('info.mat');  
Info = p.Info;  % 提取 Info 结构体，存储了所有案例的信息
% Extract the Info structure, storing all case information

%% Directory
% 设定项目目录路径
% Set project directory path
Dir_Project = Info(1).Dir_Project;

% 设置相关目录路径
% Set related directory paths
Dir_Scripts = strcat(Dir_Project, '\Scripts');  % 脚本目录 (Scripts directory)
Dir_Data = strcat(Dir_Project, '\Data');  % 数据目录 (Data directory)
Dir_Data_FEM = strcat(Dir_Project, '\Data\FEM');  % 有限元分析数据目录 (FEM data directory)
Dir_Data_Submission = strcat(Dir_Project, '\Data\FEM\Submission');  % 提交文件目录 (Submission directory)

% 如果提交目录不存在，则创建该目录
% Create the submission directory if it does not exist
if ~exist(Dir_Data_Submission, 'dir')
    mkdir(Dir_Data_Submission);
end

%% Select id Case
% 选择需要处理的案例 ID
% Select case IDs to process
id_Case = 1:length(Info);  % 选择所有案例 (Select all cases)
% id_Case = [19];  % 可选择特定案例，例如第19个案例 (Select a specific case, e.g., case 19)
num_Case = length(id_Case);  % 计算选中的案例数量 (Compute the number of selected cases)
Info = Info(id_Case);  % 更新 Info 结构体，仅包含选中的案例 (Update Info structure with selected cases)

%% Setting in Local
% 本地设置，包括 K 文件的输出路径和 LS-DYNA 求解器设置
% Local settings, including output path for K files and LS-DYNA solver settings

File_KFile_Output = cell(num_Case, 1);  % 存储每个案例的输出路径 (Store output paths for each case)
KFileName = cell(num_Case, 1);  % 存储每个案例的 K 文件名 (Store K file names for each case)

% 设置 K 文件的存储路径
% Set the path for storing K files
% KFilePath = 'D:\MG_Validation_5';  % 之前的路径 (Previous path, commented out)
KFilePath = Dir_Data_FEM;  % 设定 K 文件的路径 (Set K file path)

% LS-DYNA 求解器路径设置
% Set LS-DYNA solver path
% Local_Setting.LS_DYNA_Solver = 'C:\LSDYNA\program\ls-dyna_smp_d_R11_0_winx64_ifort131.exe';  % 旧的求解器路径 (Old solver path, commented out)
Local_Setting.LS_DYNA_Solver = '"C:\Program Files\ANSYS Inc\v231\ansys\bin\winx64\lsdyna_dp.exe"';  % 设定新的求解器路径 (Set new solver path)

% 设置每个案例使用的 CPU 核数
% Set the number of CPU cores for each case
% Local_Setting.num_cpus = ones(num_Case, 1);  % 默认所有案例使用 1 核 (Default: all cases use 1 CPU core, commented out)
Local_Setting.num_cpus = [1, 1, 4, 4, 4, 4];  % 指定不同案例使用的 CPU 数量 (Specify different CPU numbers for each case)

% 设置每次提交处理的案例数量
% Set the number of cases to be processed together in one submission
Local_Setting.num_Cases_Together = 6;

% 遍历所有选中的案例，生成 K 文件路径和文件名
% Loop through all selected cases to generate K file paths and names
for i_Case = 1:num_Case
    File_KFile_Output{i_Case} = strcat(KFilePath, '\', Info(i_Case).CaseName);  % 生成 K 文件输出路径 (Generate K file output path)
    % KFileName{i_Case} = Info(i_Case).CaseName;  % 直接使用案例名 (Use case name directly, commented out)
    KFileName{i_Case} = strcat(Info(i_Case).CaseName, '.k');  % 生成 K 文件名 (Generate K file name)
end

% 生成提交批处理文件
% Generate the batch submission files
Write_Submission_bat(Local_Setting, KFileName, File_KFile_Output, Dir_Data_Submission);

%% Function: Write Submission Batch Files
% 编写提交批处理文件的函数
% Function to write batch submission files

function Write_Submission_bat(Local_Setting, KFileName, KFilePath, Dir_Output)  
    %% Load setting 
    % 加载本地设置，包括求解器路径、案例并行处理数量、CPU 核数
    % Load local settings, including solver path, number of cases processed together, and CPU cores per case
    LS_DYNA_Solver = Local_Setting.LS_DYNA_Solver;
    num_Cases_Together = Local_Setting.num_Cases_Together;
    num_cpus = Local_Setting.num_cpus;  % 每个案例的 CPU 数量 (CPU number per case)

    %% Split project into num_Cases_Together
    % 计算案例数量，并将案例分组
    % Compute the number of cases and split them into groups
    Dir_Current = cd;  % 记录当前目录 (Store current directory)
    num_Impact_ID = length(KFileName);  % 计算案例总数 (Compute the total number of cases)
    num_Sequence = floor(num_Impact_ID / num_Cases_Together);  % 计算完整的案例分组数 (Compute the number of full case groups)
    Name_Sequence_bat = cell(num_Cases_Together, 1);  % 存储批处理文件名 (Store batch file names)
    fid_Together = cell(num_Cases_Together, 1);  % 存储文件 ID (Store file IDs)

    % 生成多个批处理文件，每个处理 num_Cases_Together 个案例
    % Generate multiple batch files, each handling num_Cases_Together cases
    for ind_Cases_Together = 1:num_Cases_Together
        %% Write each submit file
        % 生成每个批处理文件的文件名
        % Generate file name for each batch submission file
        Name_Sequence_bat{ind_Cases_Together} = sprintf('submit_Sequence_%u.bat', ind_Cases_Together);
        cd(Dir_Output);
        fid_Together{ind_Cases_Together} = fopen(Name_Sequence_bat{ind_Cases_Together}, 'w+');  % 打开文件 (Open file)
        cd(Dir_Current);
        
        % 遍历每个分组内的案例
        % Loop through each case sequence in the group
        for ind_Cases_Sequence = 1:num_Sequence
            ind_Case = num_Cases_Together * (ind_Cases_Sequence - 1) + ind_Cases_Together;
            fprintf(fid_Together{ind_Cases_Together}, 'cd %s\n', KFilePath{ind_Case});
            fprintf(fid_Together{ind_Cases_Together}, '%s i="%s" ncpu=%u\n\n', LS_DYNA_Solver, KFileName{ind_Case}, num_cpus(ind_Case));
            fprintf(fid_Together{ind_Cases_Together}, 'cd ..\n');
        end
    end

    %% Write each submit file for the last round
    % 处理剩余案例，写入最后一轮的批处理文件
    % Process remaining cases and write the last batch submission file
    num_Cases_Left = num_Impact_ID - num_Cases_Together * num_Sequence;
    for ind_Cases_Left = 1:num_Cases_Left
        ind_Case = num_Cases_Together * (num_Sequence - 1) + num_Cases_Together + ind_Cases_Left;
        fprintf(fid_Together{ind_Cases_Left}, 'cd %s\n', KFilePath{ind_Case});
        fprintf(fid_Together{ind_Cases_Left}, '%s i="%s" ncpu=%u\n', LS_DYNA_Solver, KFileName{ind_Case}, num_cpus(ind_Case));
    end

    for ind_Cases_Together = 1:num_Cases_Together
        fclose(fid_Together{ind_Cases_Together});
    end

    %% Write the final submit bat file
    % 生成最终的提交批处理文件
    % Generate the final batch submission file
    Name_bat = sprintf('submit.bat');
    cd(Dir_Output);
    fid = fopen(Name_bat, 'w+');
    cd(Dir_Current);
    for ind_Cases_Together = 1:num_Cases_Together
        fprintf(fid, 'start %s\n', Name_Sequence_bat{ind_Cases_Together});
    end
    fclose(fid);
end
