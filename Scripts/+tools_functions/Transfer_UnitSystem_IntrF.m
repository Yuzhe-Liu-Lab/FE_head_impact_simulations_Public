function IntrF_BCG_SIunit=Transfer_UnitSystem_IntrF(IntrF_BCG,Model_Unit_System)

    m_modelorder=Model_Unit_System(1);
    s_modelorder=Model_Unit_System(2);
    kg_modelorder=Model_Unit_System(3);   

    IntrF_BCG_SIunit=IntrF_BCG;

    FieldNames=fieldnames(IntrF_BCG);

    num_F=length(FieldNames);
    for i_F=1:num_F
        if length(FieldNames{i_F})<3    
            if strcmp(FieldNames{i_F},'t')
                IntrF_BCG_SIunit.t=IntrF_BCG.t*s_modelorder;
            end
        else
            First3=FieldNames{i_F}(1:3);
            switch First3
                case 'For'
                    if contains(FieldNames{i_F},'PerMass')
                        IntrF_BCG_SIunit.(FieldNames{i_F})=IntrF_BCG.(FieldNames{i_F})*(m_modelorder/s_modelorder^2);
                    else 
                        IntrF_BCG_SIunit.(FieldNames{i_F})=IntrF_BCG.(FieldNames{i_F})*(kg_modelorder*m_modelorder/s_modelorder^2);
                    end
                case 'Tor'
                    if contains(FieldNames{i_F},'PerMass')
                        IntrF_BCG_SIunit.(FieldNames{i_F})=IntrF_BCG.(FieldNames{i_F})*(m_modelorder^2/s_modelorder^2);
                    else
                        IntrF_BCG_SIunit.(FieldNames{i_F})=IntrF_BCG.(FieldNames{i_F})*(kg_modelorder*m_modelorder^2/s_modelorder^2);
                    end
                case "Vel"
                    if contains(FieldNames{i_F},'PerMass')
                        IntrF_BCG_SIunit.(FieldNames{i_F})=IntrF_BCG.(FieldNames{i_F})*(m_modelorder/s_modelorder/kg_modelorder);
                    else
                        IntrF_BCG_SIunit.(FieldNames{i_F})=IntrF_BCG.(FieldNames{i_F})*(m_modelorder/s_modelorder);
                    end
                otherwise
                    continue;
            end
        end
    end
end