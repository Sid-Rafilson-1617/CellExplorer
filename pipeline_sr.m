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
basePath = "C:\Users\srafi\OneDrive\Buzsaki Lab\data\testing-multi-NPX-SGLX - Copy";
%addpath(genpath(basePath));

% 1.2 Define the supercat output folder. If there is no supercat (from a
% session with only one recording) then set this path to the CatGT folder
% with the kilosort outputs
supercat_path = "C:\Users\srafi\OneDrive\Buzsaki Lab\data\testing-multi-NPX-SGLX - Copy\preprocessing_output\supercat_pre_homecage_g0";
baseName = bz_BasenameFromBasepath(basePath);
cd(basePath)

% 1.3 Define the path to template XML file which will be propogated with
% data from the SGLX meta files
genXML_path = 'Z:\Buzsakilabspace\LabShare\MisiVoroslakos\genXML'; 

% 1.4 Define the the directory containing imro (channel map) files for this
% recording.
imroDir_path = 'C:\Users\srafi\OneDrive\Buzsaki Lab\data\testing-multi-NPX-SGLX - Copy\imro';
%imroDir_path = 'D:\Sid\data\Use_dependent_sleep\UDS_R01\Imro_files'; %'Z:\buzsakilab\Homes\voerom01\Use_dependent_sleep\Imro_files';'Z:\Homes\ser9475\testing\imro';

%1.3 Define the number of probes and the number of shanks per probe
numOfProbes = 2;
numShanks = 4; % per probe

% 1.4 Define the expected number of channels per probe (including the reference)
nCh_expected = 385;

    
%% 2. Building XML from meta file

fileInfo = dataPathsNP2_SpikeGLX_multi_NP2(supercat_path, numOfProbes);
disp(fileInfo)

fileName = baseName + ".fileInfo.mat";
save(fullfile(basePath, fileName), 'fileInfo', '-v7.3');


% Loop over probes
for probe_num = 1:numOfProbes

    probeID = string(probe_num - 1);

    % Build session/XML files for each folder belonging to this probe

    for file_num = 1:fileInfo.nFolders{probe_num}

        ses_path = fileInfo.folder{1, probe_num}{file_num};
        ses_path = char(ses_path);

        % Create XML from IMRO and synchronize spike groups
        imro2xml_FINAL( ...
            'basepath', ses_path, ...
            'genXML_path', genXML_path, ...
            'imroDir_path', imroDir_path);

        % Create CellExplorer session structure
        session = sessionTemplate_NPX( ...
            ses_path, ...
            'showGUI', false, ...
            'saveFile', true);

    end


    % Standardize path/name types
    ses_path = string(ses_path);
    basePath = string(basePath);
    baseName = string(baseName);
    supercat_path = string(supercat_path);


    % Determine recording basename

    % fileInfo.basename currently looks something like:
    % ["supercat_pre_homecage_g0" "_imec" "0"]
    %
    % We only want the first element:
    % "supercat_pre_homecage_g0"

    basenameThisProbe = string(fileInfo.basename{probe_num}(1));

    % Remove the "supercat_" prefix
    fileName_pt1 = extractAfter(basenameThisProbe, "supercat_");

    % Construct expected SpikeGLX/Supercat names
    fileName = fileName_pt1 + "_tcat.imec" + probeID;
    subDirName = fileName_pt1 + "_imec" + probeID;


    % Locate generated session file

    ses_file = dir(fullfile(ses_path, "*.session.mat"));

    if isempty(ses_file)
        error('No .session.mat file found in: %s', ses_path);
    elseif numel(ses_file) > 1
        error('Multiple .session.mat files found in: %s', ses_path);
    end


    % Copy session file to basePath for state scoring

    % This naming convention is intentionally:
    % basename.imec0.session.mat

    sourceSession = fullfile(ses_path, string(ses_file.name));

    destSession = fullfile( ...
        basePath, ...
        baseName + ".imec" + probeID + ".session.mat");

    movefile(sourceSession, destSession);


    % Find generated XML and move it to basePath

    % Two possible naming conventions are supported

    file1 = fullfile( ...
        ses_path, ...
        fileName_pt1 + "_t0_imec" + probeID + ".ap.xml");

    file2 = fullfile( ...
        ses_path, ...
        fileName_pt1 + "_t0.imec" + probeID + ".ap.xml");

    destXML = fullfile( ...
        basePath, ...
        baseName + "_imec" + probeID + ".xml");

    if isfile(file1)

        movefile(file1, destXML);

    elseif isfile(file2)

        movefile(file2, destXML);

    else

        error( ...
            ['Neither expected XML file was found for probe %d.\n' ...
             'Checked:\n%s\n%s'], ...
            probe_num - 1, file1, file2);

    end


    % Create channel map for Kilosort

    % Make sure SGLXMetaToCoords has outType = 1
    SGLXMetaToCoords;

    coords_file = fullfile( ...
        ses_path, ...
        string(ses_file.name(1:end-12)) + "_kilosortChanMap.mat");

    if ~isfile(coords_file)
        error('Kilosort channel map not found: %s', coords_file);
    end


    % Update session metadata

    load(coords_file, 'xcoords', 'ycoords', 'kcoords');

    session.general.name = ...
        baseName + "_imec" + probeID;

    session.general.basePath = basePath;


    % Ensure coordinate arrays are column vectors
    xcoords = xcoords(:);
    ycoords = ycoords(:);


    % Add placeholder coordinate for sync channel if necessary
    if numel(xcoords) == nCh_expected - 1

        xcoords(end + 1) = xcoords(end);
        ycoords(end + 1) = ycoords(end);

    elseif numel(xcoords) ~= nCh_expected

        error( ...
            'Unexpected coordinate length: %d (expected %d or %d)', ...
            numel(xcoords), ...
            nCh_expected - 1, ...
            nCh_expected);

    end


    session.extracellular.nChannels = nCh_expected;

    session.extracellular.chanCoords.x = xcoords;
    session.extracellular.chanCoords.y = ycoords;

    session.extracellular.chanCoords.verticalSpacing = [];
    session.extracellular.chanCoords.source = 'Kilosort';
    session.extracellular.chanCoords.layout = '';


    % Save updated probe-specific session file

    sessionFile = fullfile( ...
        basePath, ...
        baseName + "_imec" + probeID + ".session.mat");

    save(sessionFile, 'session');


    % Move Kilosort channel map to basePath

    destCoords = fullfile( ...
        basePath, ...
        baseName + "_imec" + probeID + ".kilosortChanMap.mat");

    movefile(coords_file, destCoords);


    % Move AP binary and rename as .dat

    oldFileName = fullfile( ...
        supercat_path, ...
        subDirName, ...
        fileName + ".ap.bin");

    newFilePath = fullfile( ...
        basePath, ...
        baseName + "_imec" + probeID + ".dat");

    if ~isfile(oldFileName)
        error('AP binary file not found: %s', oldFileName);
    end

    movefile(oldFileName, newFilePath);


    % Move LF binary and rename as .lfp

    oldFileName = fullfile( ...
        supercat_path, ...
        subDirName, ...
        fileName + ".lf.bin");

    newFilePath = fullfile( ...
        basePath, ...
        baseName + "_imec" + probeID + ".lfp");

    if ~isfile(oldFileName)
        error('LF binary file not found: %s', oldFileName);
    end

    movefile(oldFileName, newFilePath);


    % Move AP metadata file

    oldFileName = fullfile( ...
        supercat_path, ...
        subDirName, ...
        fileName + ".ap.meta");

    newFilePath = fullfile( ...
        basePath, ...
        baseName + "_imec" + probeID + ".meta");

    if ~isfile(oldFileName)
        error('AP meta file not found: %s', oldFileName);
    end

    movefile(oldFileName, newFilePath);


    % Move Kilosort directory

    oldFileName = fullfile( ...
        supercat_path, ...
        subDirName, ...
        "Kilosort_imec" + probeID + "_ks4");

    newFilePath = fullfile( ...
        basePath, ...
        "Kilosort_imec" + probeID + "_ks4");

    if ~isfolder(oldFileName)
        error('Kilosort directory not found: %s', oldFileName);
    end

    movefile(oldFileName, newFilePath);

end

%% 3. phy autoclustering
for imec_use = 0:numOfProbes - 1
    % get the kilosort path for the probe
    kilosort_path = [basePath, filesep,['Kilosort_imec' num2str(imec_use) '_ks4']];
    
    % run the Phy Auto Cluster
    PhyAutoClustering_km(kilosort_path)
end


%% 4. Generate session metadata struct using the template function
cd(basePath)

for imec_use = 0:numOfProbes - 1

    probeBaseName = baseName + "_imec" + string(imec_use);

    session = sessionTemplate( ...
        char(basePath), ...
        'basename', char(probeBaseName), ...
        'showGUI', false);

    cell_metrics = ProcessCellMetrics( ...
        'session', session, ...
        'showGUI', false, ...
        'manualAdjustMonoSyn', false, ...
        'spikeFormat', 'sglx');

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



