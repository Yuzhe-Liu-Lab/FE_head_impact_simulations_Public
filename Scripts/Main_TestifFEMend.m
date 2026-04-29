% by Yunng Money, 20231212
% this script is to check every cases in FEM, to see if the file is
% completely correctly.

clear;
%% Load Info
p=load('info.mat');
Info=p.Info;
num_Case=length(Info);

%% Directory
Dir_Project=Info(1).Dir_Project;

Dir_Scripts=strcat(Dir_Project,'\Scripts');
Dir_Data=strcat(Dir_Project,'\Data');
Dir_Data_FEM=strcat(Dir_Project,'\Data\FEM');

%% Test

Dir_Sim=cell(num_Case,1);
for i_Case=1:num_Case
    Dir_Sim{i_Case}=sprintf('%s\\%s',Dir_Data_FEM,Info(i_Case).CaseName);
end

[IsCompleted,UnexpectedEnd,LicenseIssue,NotStarted]=CheckIfFEMComplete(Dir_Sim);

NeedRerun=([UnexpectedEnd;LicenseIssue;NotStarted])';

save('Rerun_Needed_20250414.mat','NeedRerun','IsCompleted','UnexpectedEnd','LicenseIssue','NotStarted');

%% function

function [IsCompleted,UnexpectedEnd,LicenseIssue,NotStarted]=CheckIfFEMComplete(Dir_Sim)

    num_Case=length(Dir_Sim);
    
    Ind_IC=false(num_Case,1);
    Ind_UE=false(num_Case,1);
    Ind_LI=false(num_Case,1);
    Ind_NS=false(num_Case,1);
    
    for i_Case=1:num_Case
        Ifmessag=exist(strcat(Dir_Sim{i_Case},'\messag'),'file');
        if Ifmessag==false
            Ind_IC(i_Case)=false;
            Ind_UE(i_Case)=false;
            Ind_LI(i_Case)=false;
            Ind_NS(i_Case)=true;
        else
            fid=fopen(strcat(Dir_Sim{i_Case},'\messag'));
            FileEnd=false;
    
            while ~FileEnd
                ReadInLine=fgetl(fid);

                if ~isempty(ReadInLine)
%                     ReadInLine

                    if length(ReadInLine)>=37&&strcmp(ReadInLine(1:37),' N o r m a l    t e r m i n a t i o n')
                        Ind_IC(i_Case)=true;
                        Ind_UE(i_Case)=false;
                        Ind_LI(i_Case)=false;
                        Ind_NS(i_Case)=false;
                        break;
        
                    else
                        if length(ReadInLine)>=15&&strcmp(ReadInLine(1:15),'[license/error]')
                            Ind_IC(i_Case)=false;
                            Ind_UE(i_Case)=false;
                            Ind_LI(i_Case)=true;
                            Ind_NS(i_Case)=false;
                            break;
                        end
                    end
    
                    % test if go to the end
                    if isnumeric(ReadInLine)
                        if ReadInLine==-1
                            FileEnd=true;
        
                            Ind_IC(i_Case)=false;
                            Ind_UE(i_Case)=true;
                            Ind_LI(i_Case)=false;
                            Ind_NS(i_Case)=false;
                        end
                    end
                end
            end
        end
    end
    
    IsCompleted=find(Ind_IC);
    UnexpectedEnd=find(Ind_UE);
    LicenseIssue=find(Ind_LI);
    NotStarted=find(Ind_NS);

end








