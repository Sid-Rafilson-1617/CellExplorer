%% Correct session file metadata for channel map configuration errors

%  Define the main directory of the preprocessed dataset - should contain the supercat output files
basePath = 'R:\Bilat_HPC\Bilat_R02\Bilat_R02_20251106';
baseName = bz_BasenameFromBasepath(basePath);

cd(basePath)
numOfProbes = 4; %%%% CHANGE THIS IF NEEDED %%%  

for probe_num = 1:numOfProbes
    % Load channel map data
    coords_file = [basePath, filesep, baseName '_imec' num2str(probe_num-1), '.kilosortChanMap.mat'];
    load(coords_file, 'xcoords', 'ycoords', 'kcoords');

    % Change session file metadata
    session.general.name = [baseName '_imec' num2str(probe_num-1)];
    session.general.basePath = basePath;
    session.extracellular.chanCoords.x = xcoords;
    session.extracellular.chanCoords.y = ycoords;
    session.extracellular.chanCoords.verticalSpacing = [];
    session.extracellular.chanCoords.source = 'Kilosort';
    session.extracellular.chanCoords.layout = '';
    save([basePath, filesep, baseName '_imec' num2str(probe_num-1) '.session.mat'], 'session');
end

%% Run CellExplorer
for imec_use = 0:numOfProbes - 1
    % Load session file with probe-specific basename
    session = sessionTemplate(basePath, 'basename', [baseName '_imec' num2str(imec_use)], 'showGUI',false);

    % Run the cell metrics pipeline 'ProcessCellMetrics' using the session struct as input
    cell_metrics = ProcessCellMetrics('session', session, 'showGUI', false, 'manualAdjustMonoSyn', false);
end

