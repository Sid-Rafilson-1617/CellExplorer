% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %
% Running CellExplorer on the outputs from the ece_ks4 python preprocessing
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %

%  1.1 Define the main directory of the preprocessed dataset. The main dir
%  should contain the supercat output files
main_dir = 'D:\Sid\data\testing2';
addpath(genpath(main_dir));

% 1.2 Define the supercat output folder
supercat_path = 'D:\Sid\data\testing2\preprocessing_output\supercat_pre_homecage_g0';
baseName = bz_BasenameFromBasepath(main_dir);
cd(main_dir)

%% 2. Building XML from meta file
numOfProbes = 2;
fileInfo = dataPathsNP2_SpikeGLX_multi_NP2(supercat_path, numOfProbes);
save([baseName '.fileInfo.mat'], 'fileInfo', '-v7.3')

% Paths to template XML and directory with imro files
genXML_path = '\\research-cifs.nyumc.org\research\buzsakilab\Homes\voerom01\Use_dependent_sleep\UDS_R01'; %'Z:\buzsakilab\Homes\voerom01\Use_dependent_sleep';
%imroDir_path = 'D:\Sid\data\Use_dependent_sleep\UDS_R01\Imro_files'; %'Z:\buzsakilab\Homes\voerom01\Use_dependent_sleep\Imro_files';
imroDir_path = 'D:\Sid\data\testing\imro';

for probe_num = 1:numOfProbes
    for file_num = 1:fileInfo.nFolders{probe_num}
        ses_path = fileInfo.folder{1, probe_num}{file_num}; % session path
        imro2xml_FINAL('basepath', ses_path, 'genXML_path', genXML_path, ...
            'imroDir_path', imroDir_path); % creates xml from imro file and synchronizes spikeGroups +removes refChan (default 127) and sync channel (default 384)
        session = sessionTemplate(ses_path,'showGUI',false,'saveFile',true); % sessionTemplate will use xml or sessionInfo if present
    end
    
    % Copy session file for each probe to basepath for merged files later
    ses_file = dir(fullfile(ses_path, '*.session.mat'));
    tokens = split(fileInfo.basename{probe_num}, 'supercat_'); % split filename into two parts
    baseFile = strtrim(tokens{2});
    tokens = split(baseFile, ['_imec' num2str(probe_num - 1)]);
    fileName_pt1 = strtrim(tokens{1}); % take only strings after 'supercat_' prefix
    fileName = [fileName_pt1 '_tcat.imec' num2str(probe_num - 1)]; 
    subDirName = [fileName_pt1 '_imec' num2str(probe_num - 1)]; 

    movefile(fullfile(ses_path, ses_file.name), [main_dir, filesep, baseName '_imec' num2str(probe_num-1), '.session.mat']); % needed for state scoring
    movefile(fullfile(ses_path, [ses_file.name(1:end-12), '.xml']), [main_dir, filesep, baseName '_imec' num2str(probe_num-1),'.xml']); % needed for channelMap
    
    % Change session general name
    session.general.name = [baseName '_imec' num2str(probe_num-1)];
    session.general.basePath = main_dir;
    save([main_dir, filesep, baseName '_imec' num2str(probe_num-1) '.session.mat'], 'session');
    
    % Create channel maps for Kilosort 
    SGLXMetaToCoords; % make sure outType = 1
    movefile(fullfile(ses_path, [ses_file.name(1:end-12), '_kilosortChanMap.mat']), ...
        [main_dir, filesep, baseName '_imec' num2str(probe_num-1), '.kilosortChanMap.mat']);

    % Move the .ap.bin file to the main directory and rename to baseName.dat
    oldFileName = [supercat_path, filesep, subDirName, filesep, fileName, '.ap.bin'];
    newFilePath = [main_dir, filesep, baseName '_imec' num2str(probe_num-1) '.dat'];        
    movefile(oldFileName, newFilePath);

    oldFileName = [supercat_path, filesep, subDirName, filesep, fileName, '.lf.bin'];
    newFilePath = [main_dir, filesep, baseName '_imec' num2str(probe_num-1) '.lfp'];        
    movefile(oldFileName, newFilePath);
    
    % Move kilsort directories
    oldFileName = [supercat_path, filesep, subDirName, filesep, ['Kilosort_imec' num2str(probe_num - 1) '_ks4']];
    newFilePath = [main_dir, filesep, ['Kilosort_imec' num2str(probe_num - 1) '_ks4']];        
    movefile(oldFileName, newFilePath);
 
end

%% 3. Generate session metadata struct using the template function and display the meta data in a gui
cd(main_dir)
for imec_use = 0:numOfProbes - 1
    % Load session file with probe-specific basename
    session = sessionTemplate(pwd, 'basename', [baseName '_imec' num2str(imec_use)], 'showGUI',false);
    % session = gui_session(session); % inspect the session struct by calling GUI directly

    % And validate the required and optional fields
    %validateSessionStruct(session);

    % Run the cell metrics pipeline 'ProcessCellMetrics' using the session struct as input
    cell_metrics = ProcessCellMetrics('session', session);
end

%% 4.1.2 Visualize the cell metrics in CellExplorer
cell_metrics = CellExplorer('metrics',cell_metrics); 

%% 4.2 Open several session from basepaths
basenames = {'basename1','basename2'};
basepaths = {'/your/data/path/basename1/','/your/data/path/basename2/'};
cell_metrics = loadCellMetricsBatch('basepaths',basepaths,'basenames',basenames);
cell_metrics = CellExplorer('metrics',cell_metrics);

