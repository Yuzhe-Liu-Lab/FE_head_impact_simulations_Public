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
% 本脚本写ls-prepost的cfile脚本，其可以自动调用ls-prepost从d3plot文件中提取结果文件
% 请在Select Fringe中注释不需要的fringe
% This script writes the ls-prepost cfile script, which can automatically call ls-prepost to extract result files from the d3plot file.
% Please comment out the fringes you do not need in the Select Fringe section.
%% ------------脚本主体 / Script Execution --------------- 

import tools_functions.*

%% Load Info
% 加载信息文件
p=load('info.mat');
Info=p.Info;

%% Directory
% 定义各个文件夹的路径
Dir_Project=Info(1).Dir_Project;  % 项目根目录

Dir_Scripts=strcat(Dir_Project,'\Scripts');  % 脚本目录
Dir_Data=strcat(Dir_Project,'\Data');  % 数据目录
Dir_Data_FEM=strcat(Dir_Project,'\Data\FEM');  % FEM数据目录
Dir_Data_Results_cfile=strcat(Dir_Project,'\Data\FEM\cfile_output');  % cfile输出目录
Dir_Data_Results_Output=strcat(Dir_Project,'\Data\Results\output');  % 结果输出目录

Dir_Simulation=Dir_Data_FEM;  % 设置仿真数据目录

%% Select Fringe
% 选择Fringe数据
Fringe=load('Fringe.mat');
Fringe=Fringe.Fringe;

id_Fringe_read=[...
%     5;  ... MPS
    10; ... MPSR
    34; ... Velocity X
    35; ... Velocity Y
    36; ... Velocity Z
    43; ... Coordinate X
    44; ... Coordinate Y
    45; ... Coordinate Z
    28; ... Displacement X
    29; ... Displacement Y
    30; ... Displacement Z
%     31; ... Displacement XY
%     32; ... Displacement YZ
%     33; ... Displacement ZX
    ];

num_Fringe=length(id_Fringe_read);  % Fringe数量

%% Select id Case
% 选择Case
id_Case=1:length(Info);  % 所有Case的ID
Info=Info(id_Case);  % 根据ID选择Case
num_Case=length(Info);  % Case的数量

num_par=1;  % 设置并行计算的数量

File_bat_t_cfile=cell(num_par,1);  % 存储bat文件路径的数组

% 遍历每个Fringe
for i_F=1:num_Fringe
    
    File_cfile=cell(num_Case,1);  % 存储每个Case的cfile路径
    
    % 遍历每个Case
    for i_Case=1:num_Case
        
        id_Fringe=id_Fringe_read(i_F);  % 获取当前Fringe的ID
        
        FringeName=Fringe(id_Fringe).Name;  % Fringe名称
        FringeID=Fringe(id_Fringe).ID;  % Fringe ID

        Dir_cfileOutput=strcat(Dir_Data_Results_cfile,'\',FringeName);  % cfile输出路径
        Dir_FEMResults=strcat(Dir_Simulation,'\',Info(i_Case).CaseName);  % FEM仿真结果路径
        Dir_Output=strcat(Dir_Data_Results_Output,'\',Fringe(id_Fringe).Name);  % 结果输出路径
        if Fringe(id_Fringe).At==1
            % At=1 表示Fringe在元素上
            % At=2 表示Fringe在节点上，需注册到节点
            File_cfile{i_Case}=Write_cfile_output_ELEM(Info(i_Case),FringeName,FringeID,Dir_cfileOutput,Dir_FEMResults,Dir_Output);
        else
            if Fringe(id_Fringe).At==2
                File_cfile{i_Case}=Write_cfile_output_Node(Info(i_Case),FringeName,FringeID,Dir_cfileOutput,Dir_FEMResults,Dir_Output);
            end
        end
    end
    
%% 创建文件夹（当使用LS-PrePost时，输出文件夹不会自动创建）
    if ~exist(Dir_Output,'dir')
        mkdir(Dir_Output);  % 如果文件夹不存在，创建它
    end
    
%% 写入bat文件以启动该Fringe的cfile计算

    num_interval=round(num_Case/num_par);  % 计算每个bat文件包含的Case数量
    File_bat_cfile_array={};  % 存储所有bat文件路径的数组

    for i_par=1:num_par-1
        File_bat_cfile=strcat(Dir_cfileOutput,'\',FringeName,'_',num2str(i_par),'.bat');  % 创建bat文件路径
        fid=fopen(File_bat_cfile,'w+');
        for j=(i_par-1)*num_interval+1:i_par*num_interval
            fprintf(fid,'"%s"\n',File_cfile{j});  % 将对应的cfile写入bat文件
        end
        fprintf(fid,'cd ..');
        fclose(fid);
        File_bat_cfile_array{end+1}=File_bat_cfile;  % 将bat文件路径存入数组
    end
    
    i_par=num_par;  % 最后一个bat文件
    File_bat_cfile=strcat(Dir_cfileOutput,'\',FringeName,'_',num2str(i_par),'.bat');
    fid=fopen(File_bat_cfile,'w+');
    for j=(i_par-1)*num_interval+1:num_Case
        fprintf(fid,'"%s"\n',File_cfile{j});  % 将对应的cfile写入bat文件
    end
    fprintf(fid,'cd ..');
    fclose(fid);
    File_bat_cfile_array{end+1}=File_bat_cfile;   

%% 为每个Fringe创建一个batch文件，用于同时运行多个bat文件
    File_bat_t_cfile{i_F}=strcat(Dir_cfileOutput,'\',FringeName,'_Start.bat');
    fid=fopen(File_bat_t_cfile{i_F},'w+');
    for i_bat=1:length(File_bat_cfile_array)
        fprintf(fid,'start "" "%s"\n',File_bat_cfile_array{i_bat});  % 在新窗口中运行bat文件
    end
    fprintf(fid,'cd ..');
    fclose(fid);
end

%% 创建一个批量文件来同时运行所有Fringe的batch文件
File_bat_startall_cfile=strcat(Dir_Data_Results_cfile,'\Start_All_Fringe.bat');
fid=fopen(File_bat_startall_cfile,'w+');
for i_F=1:num_Fringe
    fprintf(fid,'start /B cmd /c ""%s""\n',File_bat_t_cfile{i_F});  % 在当前窗口中运行所有Fringe的batch文件
end
fprintf(fid,'cd ..');
fclose(fid);

%% 写入cfile函数（ELEM）
function [File_cfile]=Write_cfile_output_ELEM(Info,FringeName,FringeID,Dir_cfile,Dir_FEM,Dir_Output)
% 此函数用于生成cfile文件以提取LS-Dyna仿真结果
% 编辑：Yuzhe

StartFrame=1;
EndFrame=length(Info.t);  % 总帧数
FrameInterval=1;

if ~exist(Dir_cfile,'dir')
    mkdir(Dir_cfile);  % 创建cfile目录
end
File_cfile=sprintf('%s\\%s_%s.cfile',Dir_cfile,FringeName,Info.CaseName);
fid=fopen(File_cfile,'w+');
File_d3plot=sprintf('%s\\d3plot',Dir_FEM);
fprintf(fid,'open d3plot "%s"\n',File_d3plot);  % 打开d3plot文件
fprintf(fid,'ac\n');
fprintf(fid,'postmodel off \n');

folder=sprintf('%s\\%s_%s',Dir_Output,FringeName,Info.CaseName);
if ~exist(folder,'dir')
    mkdir(folder);  % 为每个Case创建文件夹
end

switch Info.FE_Model_Name  % 根据不同的FE模型选择PartID
    case 'KTH'   
        PartID={'1','49','51','52','54','152','601','3001'}';
    case 'GHBMC' 
        PartID={'1100000','1100001','1100002','1100003','1100004','1100006','1100007','1100009','1100020'}';
    case 'THUMS_og'
        PartID={'88000100','88000101','88000102','88000103','88000104','88000105','88000120','88000121','88000122','88000123','88000124','88000125'}';
end

num_PartID=length(PartID);
for i=1:num_PartID
    fprintf(fid,'+M %s\n',PartID{i});  % 写入PartID
end
fprintf(fid,'fringe 0\n');
fprintf(fid,'fringe %u\n',FringeID);  % Fringe ID
fprintf(fid,'pfringe\n');
for i_Frame=(StartFrame:FrameInterval:EndFrame)
    fprintf(fid,'output "%s\\%s_%s\\%s_%s_FRAME%04u" %u 1 0 1 0 0 0 0 1 0 0 0 0 0 0 1.000000\n',Dir_Output,FringeName,Info.CaseName,FringeName,Info.CaseName,i_Frame,i_Frame);  % 输出数据
end
fprintf(fid,'exit\n');
fprintf(fid,'\n');
fclose(fid);

end

%% 写入cfile函数（Node）
function [File_cfile]=Write_cfile_output_Node(Info,FringeName,FringeID,Dir_cfile,Dir_FEM,Dir_Output)
% 此函数用于生成cfile文件以提取LS-Dyna仿真结果（节点级别）

StartFrame=1;
EndFrame=length(Info.t);  % 总帧数
FrameInterval=1;

if ~exist(Dir_cfile,'dir')
    mkdir(Dir_cfile);  % 创建cfile目录
end
File_cfile=sprintf('%s\\%s_%s.cfile',Dir_cfile,FringeName,Info.CaseName);
fid=fopen(File_cfile,'w+');
File_d3plot=sprintf('%s\\d3plot',Dir_FEM);
fprintf(fid,'open d3plot "%s"\n',File_d3plot);  % 打开d3plot文件
fprintf(fid,'ac\n');
fprintf(fid,'postmodel off \n');

folder=sprintf('%s\\%s_%s',Dir_Output,FringeName,Info.CaseName);
if ~exist(folder,'dir')
    mkdir(folder);  % 为每个Case创建文件夹
end

switch Info.FE_Model_Name  % 根据不同的FE模型选择PartID
    case 'KTH'   
        PartID={'1','49','51','52','54','152','601','3001'}';
    case 'GHBMC' 
        PartID={'1100000','1100001','1100002','1100003','1100004','1100006','1100007','1100009','1100020'}';
    case 'THUMS_og'
        PartID={'88000100','88000101','88000102','88000103','88000104','88000105','88000120','88000121','88000122','88000123','88000124','88000125'}';
end

num_PartID=length(PartID);
for i=1:num_PartID
    fprintf(fid,'+M %s\n',PartID{i});  % 写入PartID
end
fprintf(fid,'fringe 0\n');
fprintf(fid,'fringe %u\n',FringeID);  % Fringe ID
fprintf(fid,'pfringe\n');
for i_Frame=(StartFrame:FrameInterval:EndFrame)
    fprintf(fid,'output "%s\\%s_%s\\%s_%s_FRAME%04u" %u 1 0 1 0 0 0 0 0 1 0 0 0 0 0 1.000000\n',Dir_Output,FringeName,Info.CaseName,FringeName,Info.CaseName,i_Frame,i_Frame);  % 输出数据
end
fprintf(fid,'exit\n');
fprintf(fid,'\n');
fclose(fid);

end

    

