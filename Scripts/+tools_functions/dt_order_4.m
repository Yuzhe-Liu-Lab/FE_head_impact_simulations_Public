% Author: Yuzhe Liu from TBI Biomechanics Lab, Beihang Univerisy
% Contacts: yuzheliu@buaa.edu.cn
% Version: 20250130 by Egge
% 该脚本实现了四阶微分算法，输入t_interval为时间间隔，x为原函数数据。

function dxdt = dt_order_4(t, x)
    
    if length(t)==1     %输入为t_interval
        t_interval=t;
    else                %输入为时间序列
        if ~sum(diff(diff(t)))==0
            error('input t is not a even distribution sequence')
        else
            t_interval=mean(diff(t));
        end
    end
    
    % 初始化结果向量，大小与x一致
    dxdt = zeros(size(x)); 
    
    % 循环计算每个数据点的微分
    for i = 1:length(x)
        
        if i == 1 % 前向差分法，4阶
            dxdt(i) = (-25/12 * x(i) + 4 * x(i+1) - 3 * x(i+2) + 4/3 * x(i+3) - 1/4 * x(i+4)) / t_interval;
            % Forward difference, 4th order
            
        elseif i == 2 % 前向差分法，3阶
            dxdt(i) = (-11/6 * x(i) + 3 * x(i+1) - 3/2 * x(i+2) + 1/3 * x(i+3)) / t_interval;
            % Forward difference, 3rd order
            
        elseif i == length(x)-1 % 后向差分法
            dxdt(i) = (11/6 * x(i) - 3 * x(i-1) + 3/2 * x(i-2) - 1/3 * x(i-3)) / t_interval;
            % Backward difference
            
        elseif i == length(x) % 后向差分法，4阶
            dxdt(i) = (25/12 * x(i) - 4 * x(i-1) + 3 * x(i-2) - 4/3 * x(i-3) + 1/4 * x(i-4)) / t_interval;
            % Backward difference, 4th order
            
        else % 中心差分法
            dxdt(i) = (1/12 * x(i-2) - 2/3 * x(i-1) + 2/3 * x(i+1) - 1/12 * x(i+2)) / t_interval;
            % Central difference
            
        end
    end
end
