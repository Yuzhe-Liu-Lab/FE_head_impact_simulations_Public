% Author: Chiara Giordano, Yuzhe Liu from Camlab Stanford 
% Website: http://camlab.stanford.edu/
% October 2018; Last revision: 20240130
% 
% 函数说明：
% 该函数用于读取Stanford MiG头部运动传感器数据文件，并将数据保存为mg_data结构体。
% 其中，平动加速度的单位为重力加速度（g），函数还将使用Scale参数对口腔护具上的线性加速度进行标定。
% 
% This function reads the head motion files from Stanford MiG and saves the data as an mg_data structure.
% The translational acceleration is expressed in units of gravity (g), and the Scale parameter is used to scale the linear acceleration at the mouthguard.


function [mg_data] = process_RawCSV_MiG(filename, fc_mg, fc_ang_mg, Scale)
%% Read csv file
fid = fopen(filename); % 打开CSV文件
header = fgetl(fid); % 读取文件的第一行（header）
frewind(fid); % 重置文件指针

% check first line
if header(1:12) == 'EventCounter'  % 判断是否为新格式
    % new format - get rid of header
    header = fgetl(fid); % 读取下一行
    data_mg = cell(1,19); % 创建一个存储数据的单元格数组
    while header > 0
        % 读取每一行数据
        data_event = textscan(fid, '%f %s %f %f %f %f %f %f %f %s %s %s %f %f %f %f %f %f %f', 'Delimiter', ',');
        for e = 1:19
            data_mg{e} = [data_mg{e}; data_event{e}]; % 将数据按列拼接到单元格中
        end
        header = fgetl(fid); % 读取下一行
    end
else
    % 如果是老格式，直接读取数据
    data_mg = textscan(fid, '%f %s %f %f %f %f %f %f %f %s %s %s %f %f %f %f %f %f %f', 'Delimiter', ',');
end

fclose(fid); % 关闭文件

% 设置时间窗口的前后时长
if isnan(data_mg{13}(1))
    TimeWindowBeforeTrigger = 50; % 默认前时间窗口 50 ms
    TimeWindowAfterTrigger = 150; % 默认后时间窗口 150 ms
else     
    TimeWindowBeforeTrigger = data_mg{13}(1); % 从数据中读取前时间窗口
    TimeWindowAfterTrigger = data_mg{14}(1); % 从数据中读取后时间窗口
end
TotalWindow = TimeWindowBeforeTrigger + TimeWindowAfterTrigger; % 计算总时间窗口

% 找到每个事件的开始和结束索引
ind = find(data_mg{1} == 0); 
ind_end = [ind(2:end,1)-2; size(data_mg{1},1)]; % 事件结束位置索引
ind_date_time = [ind - 1]; % 时间戳的索引

% 重组数据为数值形式
Data_mg = [data_mg{1} data_mg{3} data_mg{4} data_mg{5} data_mg{6} data_mg{7} data_mg{8}];
Labels = data_mg{2}; % 标签数据 ('A' 为加速度计，'G' 为陀螺仪)

%% 设置参数
% 准备滤波器的参数（Butterworth 4阶滤波器）
fs_mg = 1000; % 加速度计采样频率
fs_ang_mg = 8000; % 陀螺仪采样频率
[b_mg, a_mg] = butter(2, fc_mg / (fs_mg / 2)); % 加速度计滤波器设计
[b_ang_mg, a_ang_mg] = butter(2, fc_ang_mg / (fs_ang_mg / 2)); % 陀螺仪滤波器设计
N = size(ind,1); % 事件总数

mg_data = struct([]); % 初始化结构体数组

%% 读取信息
for i = 1:N
    % 创建信息结构体
    Info.PlayerName = 'De-identified'; % 球员信息
    Info.PlayerNumber = 'De-identified'; % 球员编号
    Info.Device = filename(1:end-4); % 设备名（文件名去掉扩展名）
    Info.File = filename; % 文件名
    Info.Path = [path '\' filename]; % 文件路径
    % 读取时间戳
    Timestamp = Labels{ind_date_time(i)};
    Info.DateText = Timestamp; % 完整的时间戳
    ind_date = find(Timestamp(:) == '-'); % 找到日期的位置
    ind_time = find(Timestamp(:) == 'T'); % 找到时间的位置
    Info.Year = Timestamp(1:ind_date(1)-1); % 年份
    Info.Month = Timestamp(ind_date(1)+1:ind_date(2)-1); % 月份
    Info.Day = Timestamp(ind_date(2)+1:ind_time-1); % 日期
    ind_time_2 = find(Timestamp(:) == ':'); % 小时位置
    ind_time_3 = find(Timestamp(:) == '.'); % 秒位置
    Info.Hour = Timestamp(ind_time(1)+1:ind_time_2(1)-1); % 小时
    Info.Minute = Timestamp(ind_time_2(1)+1:ind_time_2(2)-1); % 分钟
    Info.Second = Timestamp(ind_time_2(2)+1:ind_time_3-1); % 秒
    Info.ImpactNum = i; % 事件编号
    % 数据收集参数
    Info.RecordTimeAfterTrigger = TimeWindowAfterTrigger / 1000; % 后时间窗口（秒）
    Info.RecordTimeBeforeTrigger = TimeWindowBeforeTrigger / 1000; % 前时间窗口（秒）
    Info.RecordTimeTotal = Info.RecordTimeAfterTrigger + Info.RecordTimeBeforeTrigger; % 总时间窗口
    Info.SampleRate_Accelerometer = fs_mg; % 加速度计采样频率
    Info.SampleRate_Gyroscope = fs_ang_mg; % 陀螺仪采样频率
    Info.GyroSamplesTotal = 8 * TotalWindow; % 陀螺仪样本数
    Info.IR = Data_mg(ind_date_time(i), 2); % 加速度计的初始值
    Info.FilterOn = 1; % 默认启用滤波
    Info.FilterCutoff_Accelerometer = fc_mg; % 加速度计的滤波截止频率
    Info.FilterCutoff_Gyroscope = fc_ang_mg; % 陀螺仪的滤波截止频率
    Info.ScaleOnAccelMG = Scale; % 加速度标定比例
    
    % 如果年份错误，数据无效，跳出循环
    if strcmp(Info.Year(1), '0') == 1
        disp('File contains garbage data at end')
        break
    end
    
    mg_data(i).Info = Info; % 保存信息结构体
    
    %% 数据处理
    %% 创建数据结构体
    Data.samples = 1:TotalWindow;
    lb = TimeWindowBeforeTrigger / 1000 - 0.001;
    up = TimeWindowAfterTrigger / 1000;
    Data.t = linspace(-lb, up, length(Data.samples)); % 时间向量
    Data.samples_gyro_raw = 1:Info.GyroSamplesTotal; % 陀螺仪样本
    Data.t_gyro_raw = linspace(-lb, up, length(Data.samples_gyro_raw)); % 陀螺仪时间向量
    A_len = find(strcmp(Labels, 'G') == 1, 1, 'first') - 2; % 找到加速度计数据的长度
    
    % 重新打包加速度计数据
    Data.RawData.lin_acc = [];
    for counter = ind(i):ind(i) + A_len - 1
        curr = [Data_mg(counter, 2) Data_mg(counter, 3) Data_mg(counter, 4); Data_mg(counter, 5) Data_mg(counter, 6) Data_mg(counter, 7)];
        Data.RawData.lin_acc = [Data.RawData.lin_acc; curr];
    end
    
    % 重新打包陀螺仪数据
    Data.RawData.ang_vel = [];
    for counter = ind(i) + A_len:ind_end(i)
        curr = [Data_mg(counter, 2) Data_mg(counter, 3) Data_mg(counter, 4); Data_mg(counter, 5) Data_mg(counter, 6) Data_mg(counter, 7)];
        Data.RawData.ang_vel = [Data.RawData.ang_vel; curr];
    end
    
    %% 数据标定
    % 将加速度数据从g（重力加速度单位）转换为m/s^2
    Data.ScaledData.lin_acc = Data.RawData.lin_acc * Scale;
    Data.ScaledData.ang_vel = Data.RawData.ang_vel; % 角速度不进行标定
    
    %% 转换坐标系
    % 将数据从口腔护具（MG）坐标系转换到重心（CG）坐标系
    Data.TransformedData.lin_acc(:, 1) = Data.ScaledData.lin_acc(:, 1);
    Data.TransformedData.lin_acc(:, 2) = -1 * Data.ScaledData.lin_acc(:, 2); % 进行坐标轴反转
    Data.TransformedData.lin_acc(:, 3) = -1 * Data.ScaledData.lin_acc(:, 3);
    Data.TransformedData.ang_vel(:, 1) = Data.ScaledData.ang_vel(:, 1);
    Data.TransformedData.ang_vel(:, 2) = -1 * Data.ScaledData.ang_vel(:, 2);
    Data.TransformedData.ang_vel(:, 3) = -1 * Data.ScaledData.ang_vel(:, 3);
    
    %% 滤波
    % 使用Butterworth 4阶滤波器对数据进行滤波处理
    Data.FilteredData.lin_acc = [filtfilt(b_mg, a_mg, Data.TransformedData.lin_acc(:, 1)) filtfilt(b_mg, a_mg, Data.TransformedData.lin_acc(:, 2)) filtfilt(b_mg, a_mg, Data.TransformedData.lin_acc(:, 3))];
    Data.FilteredData.ang_vel = [filtfilt(b_ang_mg, a_ang_mg, Data.TransformedData.ang_vel(:, 1)) filtfilt(b_ang_mg, a_ang_mg, Data.TransformedData.ang_vel(:, 2)) filtfilt(b_ang_mg, a_ang_mg, Data.TransformedData.ang_vel(:, 3))];
    
    %% 计算角加速度
    time_diff = Data.t_gyro_raw;
    time_interval=mean(time_diff);
    Data.FilteredData.ang_acc = [dt_order_4(time_interval, Data.FilteredData.ang_vel(:, 1)'); dt_order_4(time_interval, Data.FilteredData.ang_vel(:, 2)'); dt_order_4(time_interval, Data.FilteredData.ang_vel(:, 3)')]; 

    %% 插值调整采样率
    Data.ang_vel(1, :) = interp1(Data.t_gyro_raw, Data.FilteredData.ang_vel(:, 1), Data.t);   
    Data.ang_vel(2, :) = interp1(Data.t_gyro_raw, Data.FilteredData.ang_vel(:, 2), Data.t);
    Data.ang_vel(3, :) = interp1(Data.t_gyro_raw, Data.FilteredData.ang_vel(:, 3), Data.t);

    Data.ang_acc(1, :) = interp1(Data.t_gyro_raw, Data.FilteredData.ang_acc(1, :), Data.t);   
    Data.ang_acc(2, :) = interp1(Data.t_gyro_raw, Data.FilteredData.ang_acc(2, :), Data.t);
    Data.ang_acc(3, :) = interp1(Data.t_gyro_raw, Data.FilteredData.ang_acc(3, :), Data.t);
    
    %% 计算重心加速度
    LinAcc_mg = (Data.FilteredData.lin_acc) * 9.81;
    AngVel_mg = Data.ang_vel';
    AngAcc_mg = Data.ang_acc';
    LinAcc_cg = zeros(size(AngVel_mg)); % 初始化重心加速度
    LinAcc_cg_byAngVel = zeros(size(AngVel_mg)); % 初始化角速度引起的加速度
    LinAcc_cg_byAngAcc = zeros(size(AngVel_mg)); % 初始化角加速度引起的加速度
    
    % 计算从口腔护具到重心的加速度
    Distance = [-0.07764 0 -0.07207]; % 偏移量
    for j = 1:size(AngVel_mg, 1)
        A_mg = LinAcc_mg(j, :)'; % 线性加速度
        A_ang_mg = AngAcc_mg(j, :)'; % 角加速度
        V_ang_mg = AngVel_mg(j, :)'; % 角速度
        R = Distance'; % 偏移量
        a_cg = A_mg + cross(A_ang_mg, R) + cross(V_ang_mg, cross(V_ang_mg, R)); % 计算重心加速度
        LinAcc_cg(j, :) = a_cg'; % 保存重心加速度
        LinAcc_cg_byAngVel(j, :) = cross(V_ang_mg, cross(V_ang_mg, R)); % 由角速度引起的加速度
        LinAcc_cg_byAngAcc(j, :) = cross(A_ang_mg, R); % 由角加速度引起的加速度
    end
    
    % 保存结果
    Data.lin_acc_CG = LinAcc_cg';
    Data.lin_vel_CG(:, 1) = Data.lin_acc_CG(:, 1); % 初始速度为0
    time_int = -lb:1e-3:up; % 时间步长
    for k = 2:length(time_int)
        Data.lin_vel_CG(:, k) = trapz(time_int(1:k)', Data.lin_acc_CG(:, 1:k)' * 9.81)'; % 计算线速度
    end
    Data.lin_pos_CG(:, 1) = Data.lin_vel_CG(:, 1); % 初始位置为0
    for k = 2:length(time_int)
        Data.lin_pos_CG(:, k) = trapz(time_int(1:k)', Data.lin_vel_CG(:, 1:k)')'; % 计算位置
    end
    
    %% 保存结果
    mg_data(i).Data = Data;
    mg_data(i).t = Data.t';
    mg_data(i).lin_acc_CG = (Data.lin_acc_CG') / 9.81; % 转换为g单位
    mg_data(i).ang_acc = Data.ang_acc';
    mg_data(i).ang_vel = Data.ang_vel';
    mg_data(i).lin_acc_MG = Data.FilteredData.lin_acc;
    mg_data(i).lin_acc_MG_mag = sqrt(Data.FilteredData.lin_acc(:,1).^2 + Data.FilteredData.lin_acc(:,2).^2 + Data.FilteredData.lin_acc(:,3).^2); % 计算加速度的大小
    mg_data(i).lin_acc_CG_mag = (sqrt(Data.lin_acc_CG(1,:).^2 + Data.lin_acc_CG(2,:).^2 + Data.lin_acc_CG(3,:).^2)') / 9.81; % 重心加速度大小
    mg_data(i).ang_acc_mag = sqrt(Data.ang_acc(1,:).^2 + Data.ang_acc(2,:).^2 + Data.ang_acc(3,:).^2)'; % 角加速度大小
    mg_data(i).ang_vel_mag = sqrt(Data.ang_vel(1,:).^2 + Data.ang_vel(2,:).^2 + Data.ang_vel(3,:).^2)'; % 角速度大小
    mg_data(i).LinAcc_cg_byAngVel = LinAcc_cg_byAngVel / 9.81;
    mg_data(i).LinAcc_cg_byAngAcc = LinAcc_cg_byAngAcc / 9.81;

end
end
