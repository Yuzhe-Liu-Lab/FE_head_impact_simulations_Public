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
% 本脚本将生成在Slurm系统下的计算提交文件，可以实现多线程提交
% 在不同电脑上需要调整求解器的位置
% This script writes the batch file to submit the FE simulation based on
% ls-dyna. The location of solver should be updated for different
% enviroment

%% ------------脚本主体 / Script Execution --------------- 

import tools_functions.*

%% Load Info
% 加载 info.mat 文件，其中包含所有案例的基本信息
% Load the info.mat file, which contains all case information
p = load('Info.mat');  
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

% id_Case=[58,60,63,65,68,69]+1;  % 选择特定案例 (Select specific cases, commented out)
id_Case = 1:length(Info);  % 选择所有案例 (Select all cases)
num_Case = length(id_Case);  % 计算选中的案例数量 (Compute the number of selected cases)

%% Setting in Sherlock
% 设置 Sherlock 计算集群的运行参数
% Set the computation parameters for Sherlock cluster

File_KFile_Output = cell(num_Case, 1);  % 存储每个案例的输出路径 (Store output paths for each case)
KFileName = cell(num_Case, 1);  % 存储每个案例的 K 文件名 (Store K file names for each case)

% 设定 K 文件路径
% Set K file path
KFilePath = strcat('/scratch/groups/camarilo/Simulation_Yuzhe_HeadModel/', Info(1).Name_Project);

% Sherlock 计算设置
% Sherlock computing settings
Sherlock_Setting.LS_DYNA_Solver = '/home/groups/camarilo/Simulation_Yuzhe/MG_Validation_5/ls-dyna_smp_d_r1010_x64_redhat5_ifort160';
Sherlock_Setting.num_cpus = 1;  % 每个案例使用的 CPU 核数 (Number of CPU cores per case)
Sherlock_Setting.num_Cases_Together = 120;  % 每批提交的案例数 (Number of cases submitted together)
Sherlock_Setting.CalculationTime = 48; % 计算时间，单位：小时 (Calculation time in hours)
Sherlock_Setting.Email = 'yuzheliu@stanford.edu';  % 计算任务完成后通知的邮箱 (Email for job notification)
Sherlock_Setting.Memory = 100; % 计算任务分配的内存，单位：MB (Memory allocation per CPU in MB)
Sherlock_Setting.Memory_Applied = 1200; % 每个任务申请的总内存，单位：MB (Total memory allocated per job in MB)
Sherlock_Setting.JobName = Info(1).Name_Project;  % 计算任务名称 (Job name)

%% Write the file
% 遍历所有案例，设置 K 文件的路径和名称
% Loop through all cases to set K file paths and names
for i_Case = 1:num_Case
    id_Case_i = id_Case(i_Case);
    File_KFile_Output{i_Case} = strcat(KFilePath, '/', Info(id_Case_i).CaseName);  % K 文件输出路径 (Output path for K file)
    KFileName{i_Case} = Info(id_Case_i).CaseName;  % K 文件名 (K file name)
end

% 生成 SLURM 作业提交脚本 (Job submission script for SLURM)
Write_Submission_sh_JobArray(Sherlock_Setting, KFileName, File_KFile_Output, Dir_Data_Submission);

%% Function: Write Submission Job Array for Sherlock Cluster
% 生成 Sherlock 计算集群的作业数组提交脚本
% Function to generate job array submission script for Sherlock cluster

function Write_Submission_sh_JobArray(Sherlock_Setting, KFileName, KFilePath, Dir_SubmitBatFile)  
    %% Load Settings
    % 加载 Sherlock 计算设置
    % Load computation settings for Sherlock cluster
    LS_DYNA_Solver = Sherlock_Setting.LS_DYNA_Solver;
    num_Cases_Together = Sherlock_Setting.num_Cases_Together;
    num_cpus = Sherlock_Setting.num_cpus; % 每个案例使用的 CPU 数量 (Number of CPU cores per case)
    CalculationTime = Sherlock_Setting.CalculationTime; % 计算时间，单位：小时 (Calculation time in hours)
    Email = Sherlock_Setting.Email; % 任务完成后通知的邮箱 (Email for job notification)
    Memory = Sherlock_Setting.Memory; % 计算任务分配的内存，单位：MB (Memory allocation per CPU in MB)
    JobName = Sherlock_Setting.JobName; % 计算任务名称 (Job name)
    Memory_Applied = Sherlock_Setting.Memory_Applied; % 计算任务申请的总内存，单位：MB (Total memory allocation per job in MB)

    num_Case = length(KFileName); % 获取案例数量 (Get number of cases)

    %% Open submission script file
    % 打开提交脚本文件 (Open submission script file)
    fid = fopen(strcat(Dir_SubmitBatFile, '\Submission.sh'), 'w+');

    % 写入 SLURM 作业调度参数
    % Write SLURM job scheduling parameters
    fprintf(fid, '#!/bin/bash\n');
    fprintf(fid, '#\n');
    fprintf(fid, '#SBATCH --job-name=%s\n', JobName);
    fprintf(fid, '#SBATCH --output=%s_%%A_%%a.outa\n', JobName);
    fprintf(fid, '#SBATCH --error=%s_%%A_%%a.erra\n', JobName);
    fprintf(fid, '#SBATCH --time=%02u:00:00\n', CalculationTime);
    fprintf(fid, '#SBATCH -p normal\n'); % 计算分区 (Compute partition)
    fprintf(fid, '#SBATCH --ntasks=1\n'); % 任务数 (Number of tasks)
    fprintf(fid, '#SBATCH --cpus-per-task=%u\n', num_cpus); % 每个任务使用的 CPU 核数 (Number of CPUs per task)
    fprintf(fid, '#SBATCH --mem-per-cpu=%uM\n', Memory_Applied); % 每个 CPU 核分配的内存 (Memory allocation per CPU in MB)
    fprintf(fid, '#SBATCH --array=0-%u%%%u\n', num_Case-1, num_Cases_Together); % 作业数组 (Job array setting)
    fprintf(fid, '#SBATCH --mail-type=ALL\n'); % 任务通知类型 (Job notification type)
    fprintf(fid, '#SBATCH --mail-user=%s\n\n', Email); % 任务通知邮箱 (Job notification email)

    fprintf(fid, 'ml load devel\n'); % 加载开发模块 (Load development module)

    %% Set the license
    % 设置 LS-DYNA 许可证 (Set LS-DYNA license)
    fprintf(fid, '\nexport LSTC_LICENSE=network    # 设置许可证环境变量 (Set environment variables for license)\n');
    fprintf(fid, '\nexport LSTC_LICENSE_SERVER=171.64.80.6   # LS-DYNA 许可证服务器 IP (License server IP for LS-DYNA)\n');
    fprintf(fid, '\nchmod a+x %s\n', LS_DYNA_Solver');

    %% Set the input
    % 设置输入文件 (Set input files)
    fprintf(fid, '#\n');
    fprintf(fid, 'arrVar=()\n');
    fprintf(fid, 'arrLoc=()\n\n');
    fprintf(fid, '#\n');

    % 记录每个案例的 K 文件路径
    % Store each case's K file path
    for i_Case = 1:num_Case
        fprintf(fid, 'arrVar+=("%s")\n', KFileName{i_Case});
        fprintf(fid, 'arrLoc+=("%s")\n\n', KFilePath{i_Case});
    end

    fprintf(fid, 'echo ${arrVar[${SLURM_ARRAY_TASK_ID}]}\n');
    fprintf(fid, 'echo ${arrLoc[${SLURM_ARRAY_TASK_ID}]}\n\n');

    fprintf(fid, 'cd ${arrLoc[${SLURM_ARRAY_TASK_ID}]}\n');

    fprintf(fid, '"%s" i=${arrVar[${SLURM_ARRAY_TASK_ID}]}.k ncpu=%u memory=%um \n', LS_DYNA_Solver, num_cpus, Memory);

    fclose(fid); % 关闭脚本文件 (Close script file)
end

