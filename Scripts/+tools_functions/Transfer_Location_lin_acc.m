% Author: Yuzhe Liu from TBI Biomechanics Lab, Beihang University
% Contacts: yuzheliu@buaa.edu.cn
% Version: 20250130 by Egge

% 该函数根据刚体转动角速度和角加速度，将C1处的平动加速度转化为C2处的平动加速度（平动加速度的单位为g）
% This function transfers the linear acceleration from C1 to C2 based on angular velocity and angular acceleration of the rigid body.
% lin_acc_C1应该以g为单位，结果会转换为C2处的平动加速度，单位为g。
% lin_acc_C1 should be in units of gravity (g); the result will be the linear acceleration at C2 in units of gravity.

function [lin_acc_C2] = Transfer_Location_lin_acc(lin_acc_C1, ang_vel, ang_acc, C1, C2)

    % 重力加速度常数（m/s²），用于将加速度从g转换为m/s²
    g = 9.81;
    
    % 将输入的线性加速度从g转换为m/s²
    lin_acc_C1 = lin_acc_C1 * g;
    
    % 获取数据的时间步数
    num_t = size(lin_acc_C1, 1);
    
    % 初始化C2处的线性加速度为C1处的加速度（初始值）
    lin_acc_C2 = lin_acc_C1;
    
    % 计算从C1到C2的相对位置向量
    r = C2 - C1;
    
    % 循环遍历每个时间步，计算C2处的线性加速度
    for i_t = 1:num_t
        % 获取当前时间步C1处的加速度、角速度和角加速度
        lin_acc_C1_i = lin_acc_C1(i_t, :);
        ang_vel_i = ang_vel(i_t, :);
        ang_acc_i = ang_acc(i_t, :);
        
        % 计算C2处的线性加速度
        % 使用刚体的转动方程：lin_acc_C2 = lin_acc_C1 + ω × r + α × (r × ω)
        lin_acc_C2_i = lin_acc_C1_i + cross(ang_acc_i, r) + cross(ang_vel_i, cross(ang_vel_i, r));
        
        % 将计算出的线性加速度存储到C2的位置
        lin_acc_C2(i_t, :) = lin_acc_C2_i;
    end
    
    % 将结果转换回g单位
    lin_acc_C2 = lin_acc_C2 / g;
    
end
