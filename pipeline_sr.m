% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Running CellExplorer on the outputs from the ece_ks4 python preprocessing
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %

%  1.1 Define the main directory of the preprocessed dataset. The main dir
%  should contain the supercat output files
basePath = 'R:\Bilat_HPC\Bilat_R02\Bilat_R02_20251107';
addpath(genpath(basePath));

% 1.2 Define the supercat output folder
supercat_path = 'R:\Bilat_HPC\Bilat_R02\Bilat_R02_20251107\preprocessing_output\supercat_pre_sleep_g0';
baseName = bz_BasenameFromBasepath(basePath);
cd(basePath)

%1.3 Define the number of probes
numOfProbes = 4;

%% 2. Building XML from meta file
fileInfo = dataPathsNP2_SpikeGLX_multi_NP2(supercat_path, numOfProbes);
save(fullfile(basePath, [baseName '.fileInfo.mat']), 'fileInfo', '-v7.3')

% Paths to template XML and directory with imro files
genXML_path = '\\research-cifs.nyumc.org\research\buzsakilab\Homes\voerom01\Use_dependent_sleep\UDS_R01'; %'Z:\buzsakilab\Homes\voerom01\Use_dependent_sleep';
%imroDir_path = 'D:\Sid\data\Use_dependent_sleep\UDS_R01\Imro_files'; %'Z:\buzsakilab\Homes\voerom01\Use_dependent_sleep\Imro_files';
%imroDir_path = '\\research-cifs.nyumc.org\research\buzsakilab\Homes\voerom01\Bilat_HPC\Bilat_R02\IMRO_files';
imroDir_path = 'D:\Sid\data\testing\imro'

for probe_num = 1:numOfProbes
    for file_num = 1:fileInfo.nFolders{probe_num}
        ses_path = fileInfo.folder{1, probe_num}{file_num}; % session path
        imro2xml_FINAL('basepath', ses_path, 'genXML_path', genXML_path, ...
            'imroDir_path', imroDir_path); % creates xml from imro file and synchronizes spikeGroups +removes refChan (default 127) and sync channel (default 384)
        session = sessionTemplate_NPX(ses_path,'showGUI',false,'saveFile',true); % sessionTemplate will use xml or sessionInfo if present
    end
    
    % Copy session file for each probe to basepath for merged files later
    ses_file = dir(fullfile(ses_path, '*.session.mat'));
    tokens = split(fileInfo.basename{probe_num}, 'supercat_'); % split filename into two parts
    baseFile = strtrim(tokens{2});
    tokens = split(baseFile, ['_imec' num2str(probe_num - 1)]);
    fileName_pt1 = strtrim(tokens{1}); % take only strings after 'supercat_' prefix
    fileName = [fileName_pt1 '_tcat.imec' num2str(probe_num - 1)]; 
    subDirName = [fileName_pt1 '_imec' num2str(probe_num - 1)]; 

    movefile(fullfile(ses_path, ses_file.name), [basePath, filesep, baseName '_imec' num2str(probe_num-1), '.session.mat']); % needed for state scoring
    movefile(fullfile(ses_path, [fileName_pt1, '_t0', '.imec' num2str(probe_num-1), '.ap.xml']), [basePath, filesep, baseName '_imec' num2str(probe_num-1),'.xml']); % needed for channelMap
    
    % Change session general name
    session.general.name = [baseName '_imec' num2str(probe_num-1)];
    session.general.basePath = basePath;
    save([basePath, filesep, baseName '_imec' num2str(probe_num-1) '.session.mat'], 'session');
    
    % Create channel maps for Kilosort 
    SGLXMetaToCoords; % make sure outType = 1
    movefile(fullfile(ses_path, [ses_file.name(1:end-12), '_kilosortChanMap.mat']), ...
        [basePath, filesep, baseName '_imec' num2str(probe_num-1), '.kilosortChanMap.mat']);

    % Move the .ap.bin file to the main directory and rename to baseName.dat
    oldFileName = [supercat_path, filesep, subDirName, filesep, fileName, '.ap.bin'];
    newFilePath = [basePath, filesep, baseName '_imec' num2str(probe_num-1) '.dat'];        
    movefile(oldFileName, newFilePath);

    oldFileName = [supercat_path, filesep, subDirName, filesep, fileName, '.lf.bin'];
    newFilePath = [basePath, filesep, baseName '_imec' num2str(probe_num-1) '.lfp'];        
    movefile(oldFileName, newFilePath);
    
    % Move kilsort directories
    oldFileName = [supercat_path, filesep, subDirName, filesep, ['Kilosort_imec' num2str(probe_num - 1) '_ks4']];
    newFilePath = [basePath, filesep, ['Kilosort_imec' num2str(probe_num - 1) '_ks4']];        
    movefile(oldFileName, newFilePath);
 
end

%% 3. Generate session metadata struct using the template function and display the meta data in a gui
cd(basePath)
for imec_use = 0:numOfProbes - 1
    % Load session file with probe-specific basename
    session = sessionTemplate(pwd, 'basename', [baseName '_imec' num2str(imec_use)], 'showGUI',false);

    % Run the cell metrics pipeline 'ProcessCellMetrics' using the session struct as input
    cell_metrics = ProcessCellMetrics('session', session, 'showGUI', false);
end

%% 5. Sleep state scoring
lfpFiles = checkFile('basepath',basePath,'fileType','.lfp');
% Select lfp_num corresponding to probe with cortical channel
for lfp_num = 1:length(lfpFiles)
    filename = lfpFiles(lfp_num).name; % remove extension
    SleepState = SleepScoreMaster_km(basePath,'filename',filename); % requires session or sessionInfo file
end

% Check sleep state scoring results with GUI
TheStateEditor([pwd,filesep,filename])

%% 6. Ripple detection
% manually inspect the lfp files to find good channels for ripple detection
channels = [0, 0, 0, 0];

for lfp_num = 1:length(lfpFiles)
    channel  = channels(lfp_num) + 1;

    % Extract filename without extension
    [~, filename, ~] = fileparts(lfpFiles(lfp_num).name);

    % Pass the cleaned name to bz_FindRipples_MV
    ripples = bz_FindRipples_MV(basePath, channel, 'filename', filename, 'saveMat', true, 'plotType', 1);
end


