% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Running CellExplorer on the outputs from the ece_ks4 neuropixels python
% preprocessing. This is part 2 of the preprocessing pipeline for
% neuropixels recordings in the Buzsaki lab.
% 
% For part 1 see https://github.com/Sid-Rafilson-1617/ecephys_spike_sorting/tree/main/ecephys_spike_sorting/scripts/buzsaki_preprocessing_pipeline
%
%
% Written by: 
%   Sidney Rafilson
%   Nick Paleologos 
%
% Contact: 
%   Sid.Rafilson@nyu.edu
%   Nicholas.Paleologos@nyulangone.org
%
% Last updated: 8-26-2026
%
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %

%% 1. USER CONFIGURATION


%  1.1 Define the main directory of the preprocessed dataset. The main dir
%  should contain the supercat output files
basePath = "C:\Users\srafi\OneDrive\Buzsaki Lab\data\testing-multi-NPX-SGLX";
%addpath(genpath(basePath));

% 1.2 Define the supercat output folder. If there is no supercat (from a
% session with only one recording) then set this path to the CatGT folder
% with the kilosort outputs
supercat_path = "C:\Users\srafi\OneDrive\Buzsaki Lab\data\testing-multi-NPX-SGLX\preprocessing_output\supercat_pre_homecage_g0";
baseName = bz_BasenameFromBasepath(basePath);
cd(basePath)

% 1.3 Define the path to template XML file which will be propogated with
% data from the SGLX meta files
genXML_path = 'Z:\Buzsakilabspace\LabShare\MisiVoroslakos\genXML'; 

% 1.4 Define the the directory containing imro (channel map) files for this
% recording.
imroDir_path = 'C:\Users\srafi\OneDrive\Buzsaki Lab\data\testing-multi-NPX-SGLX\imro';
%imroDir_path = 'D:\Sid\data\Use_dependent_sleep\UDS_R01\Imro_files'; %'Z:\buzsakilab\Homes\voerom01\Use_dependent_sleep\Imro_files';'Z:\Homes\ser9475\testing\imro';

%1.3 Define the number of probes and the number of shanks per probe
numOfProbes = 2;
numShanks = 4; % per probe

% 1.4 Define the expected number of channels per probe (including the reference)
nCh_expected = 385;

%% 2. Building XML from meta file
fileInfo = dataPathsNP2_SpikeGLX_multi_NP2(supercat_path, numOfProbes);

fileName = baseName + ".fileInfo.mat";
save(fullfile(basePath, fileName), 'fileInfo', '-v7.3')



% Looping over the probes to build the session files
for probe_num = 1:numOfProbes
    for file_num = 1:fileInfo.nFolders{probe_num}
        ses_path = fileInfo.folder{1, probe_num}{file_num}; % session path
        imro2xml_FINAL('basepath', ses_path, 'genXML_path', genXML_path, ...
            'imroDir_path', imroDir_path); % creates xml from imro file and synchronizes spikeGroups +removes refChan (default 127) and sync channel (default 384)
        session = sessionTemplate_NPX(ses_path,'showGUI',false,'saveFile',true); % sessionTemplate will use xml or sessionInfo if present
    end
    
    % Copy session file for each probe to basepath for merged files later
    ses_file = dir(fullfile(ses_path, '*.session.mat'));
    disp(fileInfo.basename{probe_num})
    tokens = split(fileInfo.basename{probe_num}, 'supercat_'); % split filename into two parts
    baseFile = strtrim(tokens{2});
    tokens = split(baseFile, ['_imec' num2str(probe_num - 1)]);
    fileName_pt1 = strtrim(tokens{1}); % take only strings after 'supercat_' prefix
    fileName = [fileName_pt1 '_tcat.imec' num2str(probe_num - 1)]; 
    subDirName = [fileName_pt1 '_imec' num2str(probe_num - 1)]; 

    movefile(fullfile(ses_path, ses_file.name), [basePath, filesep, baseName '.imec' num2str(probe_num-1), '.session.mat']); % needed for state scoring
    
    % finding the xml file and moving it
    file1 = fullfile(ses_path, [fileName_pt1, '_t0', '_imec' num2str(probe_num-1), '.ap.xml']);
    file2 = fullfile(ses_path, [fileName_pt1, '_t0', '.imec' num2str(probe_num-1), '.ap.xml']);
    dest = fullfile(basePath, [baseName '_imec' num2str(probe_num-1), '.xml']);
    if exist(file1, 'file')
        movefile(file1, dest);
    elseif exist(file2, 'file')
        movefile(file2, dest);
    else
        error('Neither XML file found for probe %d', probe_num-1);
    end
    
    
    % Create channel maps for Kilosort 
    SGLXMetaToCoords; % make sure outType = 1
    coords_file = fullfile(ses_path, [ses_file.name(1:end-12), '_kilosortChanMap.mat']);
    
    % Change session file metadata
    load(coords_file, 'xcoords', 'ycoords', 'kcoords');
    session.general.name = [baseName '_imec' num2str(probe_num-1)];
    session.general.basePath = basePath;
    

    xcoords = xcoords(:);
    ycoords = ycoords(:);

    if numel(xcoords) == nCh_expected-1
        xcoords(end+1) = xcoords(end);   % or NaN
        ycoords(end+1) = ycoords(end);   % or NaN
    elseif numel(xcoords) ~= nCh_expected
        error('Unexpected coord length: %d (expected %d or %d)', numel(xcoords), nCh_expected-1, nCh_expected);
    end

    session.extracellular.nChannels = nCh_expected;
    session.extracellular.chanCoords.x = xcoords;
    session.extracellular.chanCoords.y = ycoords;
    session.extracellular.chanCoords.verticalSpacing = [];
    session.extracellular.chanCoords.source = 'Kilosort';
    session.extracellular.chanCoords.layout = '';
    save([basePath, filesep, baseName '_imec' num2str(probe_num-1) '.session.mat'], 'session');
    
    % Move channel map file
    movefile(coords_file,[basePath, filesep, baseName '_imec' num2str(probe_num-1), '.kilosortChanMap.mat']);

    % Move the .ap.bin file to the main directory and rename to baseName.dat
    oldFileName = [supercat_path, filesep, subDirName, filesep, fileName, '.ap.bin'];
    newFilePath = [basePath, filesep, baseName '_imec' num2str(probe_num-1) '.dat'];        
    movefile(oldFileName, newFilePath);

    oldFileName = [supercat_path, filesep, subDirName, filesep, fileName, '.lf.bin'];
    newFilePath = [basePath, filesep, baseName '_imec' num2str(probe_num-1) '.lfp'];        
    movefile(oldFileName, newFilePath);
    
    % move the .ap.meta file to the main directory and rename
    oldFileName = [supercat_path, filesep, subDirName, filesep, fileName, '.ap.meta'];
    newFilePath = [basePath, filesep, baseName '_imec' num2str(probe_num-1) '.meta'];        
    movefile(oldFileName, newFilePath);
    
    % Move kilsort directories
    oldFileName = [supercat_path, filesep, subDirName, filesep, ['Kilosort_imec' num2str(probe_num - 1) '_ks4']];
    newFilePath = [basePath, filesep, ['Kilosort_imec' num2str(probe_num - 1) '_ks4']];        
    movefile(oldFileName, newFilePath);
 
end

%% 3. phy autoclustering
cd(basePath)
for imec_use = 0:numOfProbes - 1
    % get the kilosort path for the probe
    kilosort_path = [basePath, filesep,['Kilosort_imec' num2str(imec_use) '_ks4']];
    
    % run the Phy Auto Cluster
    PhyAutoClustering_km(kilosort_path)
end


%% 4. Generate session metadata struct using the template function and display the meta data in a gui
cd(basePath)
for imec_use = 2:numOfProbes - 1
    % Load session file with probe-specific basename
    session = sessionTemplate(basePath, 'basename', [baseName '_imec' num2str(imec_use)], 'showGUI',false);

    % Run the cell metrics pipeline 'ProcessCellMetrics' using the session struct as input
    cell_metrics = ProcessCellMetrics('session', session, 'showGUI', false, 'manualAdjustMonoSyn', false, 'spikeFormat', 'sglx'); % set which KS label to include in preferences_processCellMetrics.m
end


%% 5. Sleep state scoring


% Manually specify theta channels (LM or radiatum)
theta_channels = {
    [159, 163], ...
    [1, 35, 81, 198, 337], ...
    [8, 20, 54, 223], ...
    [50, 1]
};
save('theta_channel_config.mat', 'theta_channels');


% Manually specify slow wave channels (cortex)
SWChannels = {
    [104, 42, 2, 26, 361], ...
    [], ...
    [], ...
    []
};
save('SWChannel_config.mat', 'SWChannels')

lfpFiles = checkFile('basepath',basePath,'fileType','.lfp');

% Select lfp_num corresponding to probe with cortical channel
for lfp_num = 1:length(lfpFiles)
    filename = lfpFiles(lfp_num).name; % remove extension
    %SleepState = SleepScoreMaster_km(basePath,'filename', filename, 'ThetaChannels', theta_channels{lfp_num}, 'SWChannels', SWChannels{lfp_num}, 'Notch60Hz', 1, 'NotchHVS', 1);
	SleepState = SleepScoreMaster_km(basePath,'filename', filename, 'Notch60Hz', 1, 'NotchHVS', 1);
end

% Check sleep state scoring results with GUI
%TheStateEditor([pwd,filesep,filename])

%% 6. Ripple detection
% manually inspect the lfp files to find good channels for ripple detection


% channels(row = probe/lfp file, col = shank) Check indexing. They should
% be 1 indexed
channels = [27, 75, 227, 136;   
            111, 166, 328, 52;
            104, 161, 304, 349;
            144, 180, 291, 248];
        
 % save the channel indices used for ripple detection     
save('ripple_channel_config.mat','channels');

% ---- Build LFP file list explicitly ----
lfpFiles = cell(numOfProbes,1);

for p = 1:numOfProbes
    lfpFiles{p} = fullfile(basePath, sprintf('%s_imec%d.lfp', baseName, p-1));
    
    if ~isfile(lfpFiles{p})
        error('LFP file not found: %s', lfpFiles{p});
    end
end


% ---- Loop over probes and shanks ----
for probe = 1:numOfProbes
    
    % Extract filename without extension
    [~, filename, ext] = fileparts(lfpFiles{probe});
    disp(filename)


    for shank = 1:numShanks
        
        % get the channel index
        channel = channels(probe, shank);

        % ripple detection
        ripples = bz_FindRipples_MV_SR( ...
            basePath,  channel, ...
            'filename', filename, ...
            'saveMat', true, ...
            'plotType', 1, ...
            'probe', num2str(probe-1), ...          
            'shank', num2str(shank-1), ...
            'EMGThresh', 0.9, ...
            'restrict', SleepState.ints.NREMstate);
    end
end


%% 7. Load cell metrics across probes
basenames = getImecBasenames_sr(basePath);
cell_metrics = loadCellMetricsBatch( ...
    'basepaths', repmat({basepath}, 1, numel(basenames)), ...
    'basenames', basenames);

cell_metrics = CellExplorer('metrics', cell_metrics);



