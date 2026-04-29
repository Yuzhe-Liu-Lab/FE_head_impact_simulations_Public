% Author: Yuzhe Liu from TBI Biomechanics Lab, Beihang University
% Contacts: yuzheliu@buaa.edu.cn
% Version: 20250130 by Egge

% This function transfers the kinematics in mg_data (which is in the
% anatomical reference) to the mg_data_G (which is 
% in the global reference).
% The function will integrate the rotation at the first time point in t
% 这个函数将mg_data（在解剖学参考坐标系下）中的运动学数据转换为mg_data_G（在全局参考坐标系下）的数据。
% 该函数将在t的第一个时间点对旋转进行积分。

function [mg_data_G] = Transfer_Reference_Local2Global_mg_data(mg_data)
    num_Case = length(mg_data);  % 获取数据的案例数

    % mg_data_G=mg_data;  % 注释掉的代码行

    for i_Case = 1:num_Case
        %% Integration
        t = mg_data(i_Case).t;  % 获取时间数据
        num_t = length(t);  % 获取时间点的数量
        ang_vel = mg_data(i_Case).ang_vel;  % 获取角速度数据
        
        %% Check if ang_vel is all zero at a certain time point
        ang_vel_mag = sqrt(sum(ang_vel.^2, 2));  % 计算角速度的大小
        ang_vel_mag_max = max(ang_vel_mag);  % 获取最大角速度大小
        [~, ind_zero] = find(ang_vel_mag == 0);  % 查找角速度为零的时间点
        ratio_quasiZero = 1e-15;  % 定义一个接近零的常数
        ang_vel(ind_zero, 1) = ratio_quasiZero * ang_vel_mag_max * ones(length(ind_zero), 1);  % 将零角速度设为一个很小的数值
        
        q0 = [1, 0, 0, 0];  % 初始传感器框架与全局框架完全一致
        dt = mean(diff(t));  % 计算时间步长
        rot_matrix_mg = compute_rotation_matrix_from_angular_velocity(ang_vel, q0, dt);  % 根据角速度计算旋转矩阵
        
        %% Rotate each parameter
        [FieldNames_Data] = FindDataFieldName(mg_data(i_Case));  % 查找数据字段名称
        num_FieldNames = length(FieldNames_Data);  % 获取字段数
        mg_data_G_i = mg_data(i_Case);  % 初始化存储旋转后的数据
        for i_FM = 1:num_FieldNames
            Field = getfield(mg_data(i_Case), FieldNames_Data{i_FM});  % 获取对应字段的数据
            Field_1 = Field;  % 初始化旋转后的字段数据
            if size(Field, 1) == num_t && size(Field, 2) == 3  % 检查字段数据的维度
                for i_t = 1:num_t
                    Field_1(i_t, :) = (rot_matrix_mg(:, :, i_t) * Field(i_t, :)')';  % 对每个时间点的数据进行旋转
                end
                mg_data_G_i = setfield(mg_data_G_i, strcat('G_', FieldNames_Data{i_FM}), Field_1);  % 将旋转后的数据存入新的结构体中
            end
        end
        mg_data_G(i_Case) = mg_data_G_i;  % 将处理后的数据存入输出结果中
    end
end

% Function to compute the rotation matrix from angular velocity and quaternion
% 计算角速度和四元数的旋转矩阵
function rot_matrix = compute_rotation_matrix_from_angular_velocity(w, q0, dt)
    ang_pos_quaternion = compute_quaternion_from_angular_velocity(w, q0, dt);  % 根据角速度计算四元数
    rot_matrix = compute_rotation_matrix_from_quaternions(ang_pos_quaternion);  % 根据四元数计算旋转矩阵
end

% Function to compute the quaternion from angular velocity
% 计算角速度的四元数
function q = compute_quaternion_from_angular_velocity(w, q0, dt)
    %COMPUTE_QUATERNION_FROM_ANGULAR_VELOCITY   Quaternion from rotational velocity
    %   q = COMPUTE_QUATERNION_FROM_ANGULAR_VELOCITY(w,q0,dt)
    %       Computes quaternion time history, q, of a rigid body with angular
    %       velocity given by w. q0 is the initial condition for the 
    %       quaternion and dt is the desired time step.
    %       通过角速度计算刚体的四元数时间历史记录q。q0是四元数的初始条件，dt是所需的时间步长。

    % Example:
    %   % Constant angular velocity about x-axis
    %   w = repmat([1,0,0])

    % Author: Fidel Hernandez
    % Date: 5/9/2013

    % Initialize quaternion vector to input argument, and normalize
    q(:, 1) = q0 / norm(q0);  % 初始化四元数并归一化
    
    % Set time dimension of angular velocity vector
    if any(size(w) == 3)
        if find(size(w) ~= 3) == 1, w = w'; end  % 如果时间维度不是列向量，转置角速度向量
    else
        error('Angular velocity vector must have at least one dimension of length 3 representing x-y-z rotation');  % 如果角速度的维度不对，报错
    end

    % Iterate through length of angular velocity vector
    for i = 2:size(w, 2)
        q(:, i) = quatmultiply(q_hat(w(:, i - 1) * dt)', q(:, i - 1)')';  % 计算四元数
    end
end

% Function to compute the unit quaternion (rotation)
% 计算单位四元数（旋转）
function qh = q_hat(w)
    if ~norm(w) == 0
        qh = [cos(norm(w)/2); sin(norm(w)/2) * w/norm(w)];  % 计算旋转四元数
    else
        qh = [1; 0; 0; 0];  % 如果角速度为零，返回单位四元数
    end
end

% Function to compute the rotation matrix from quaternion
% 从四元数计算旋转矩阵
function R = compute_rotation_matrix_from_quaternions(q)
    % Set time dimension of quaternion vector
    if any(size(q) == 4)
        if find(size(q) ~= 4) == 1, q = q'; end  % 如果四元数的时间维度不是列向量，转置
    else
        error('Quaternion vector must have at least one dimension of length 4 representing the four quaternions');  % 如果四元数的维度不对，报错
    end

    % Iterate through length of quaternion vector
    for i = 1:size(q, 2)
        R(:, :, i) = [2 * q(2, i)^2 + 2 * q(1, i)^2 - 1, 2 * (q(2, i) * q(3, i) - q(4, i) * q(1, i)), 2 * (q(2, i) * q(4, i) + q(3, i) * q(1, i));
                      2 * (q(2, i) * q(3, i) + q(4, i) * q(1, i)), 2 * q(3, i)^2 + 2 * q(1, i)^2 - 1, 2 * (q(3, i) * q(4, i) - q(2, i) * q(1, i));
                      2 * (q(2, i) * q(4, i) - q(3, i) * q(1, i)), 2 * (q(3, i) * q(4, i) + q(2, i) * q(1, i)), 2 * q(4, i)^2 + 2 * q(1, i)^2 - 1];
    end
end

% Function to find field names that contain data in the input structure
% 查找包含数据的字段名称
function [FieldNames_Data] = FindDataFieldName(impact_i)
    % This function gives the names of fields that contain data in the impact_i structure
    % 这个函数返回impact_i结构中包含数据的字段名称
    FieldNames = fieldnames(impact_i);  % 获取字段名称
    num_FieldNames = length(FieldNames);  % 获取字段数量

    num_t0 = length(impact_i.t);  % 用于检查字段是否是数据

    FieldNames_Data = cell(num_FieldNames, 1);  % 初始化字段名称的存储
    num_FieldNames_Data = 0;  % 初始化包含数据的字段数目
    for i_FM = 1:num_FieldNames
        Field = getfield(impact_i, FieldNames{i_FM});  % 获取字段数据
        if size(Field, 1) == num_t0  % 判断字段是否是数据
            num_FieldNames_Data = num_FieldNames_Data + 1;  % 增加包含数据的字段数目
            FieldNames_Data{num_FieldNames_Data} = FieldNames{i_FM};  % 存储包含数据的字段名称
        end
    end
    FieldNames_Data = FieldNames_Data(1:num_FieldNames_Data);  % 返回最终的字段名称
end
