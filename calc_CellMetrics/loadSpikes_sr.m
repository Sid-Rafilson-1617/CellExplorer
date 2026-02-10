function spikes = loadSpikes_sr(varargin)
% This function imports various spike sorting pipelines/formats into the CellExplorer spikes format 
% Once spikes are imported and saved to a .mat file, the script will load this spikes struct instead of importing again. 
% The forceReload parameter can overrule this.
% 
% Currently supported formats: 
%      ALF
%      AllenSDK (via NWB files and their API data files)
%      Custom (Spike timestamps as input)
%      Klustakwik/Neurosuite
%      KlustaViewa/Klustasuite
%      SGLX
%      NWB
%      Phy (default import format)
%      Sebastien Royer's lab standard
%      SpyKING Circus
%      UltraMegaSort2000
%      Wave_clus
%
% Please see the CellExplorer website: https://cellexplorer.org/datastructure/data-structure-and-format/#spikes
%
% INPUTS
% 
% See description of varargin below
%
% OUTPUT
%
% spikes:               - Matlab struct described here: https://cellexplorer.org/datastructure/data-structure-and-format/#spikes
%     .basename         - Name of recording file
%     .sr               - Sampling rate
%     .UID              - Unique identifier for each neuron in a recording
%     .times            - Cell array of timestamps (seconds) for each neuron
%     .spindices        - Sorted vector of [spiketime UID], useful as input to some functions and plotting rasters
%     .region           - Region ID for each neuron (especially important large scale, high density probes)
%     .maxWaveformCh    - Channel # with largest amplitude spike for each neuron (0-indexed)
%     .maxWaveformCh1   - Channel # with largest amplitude spike for each neuron (1-indexed)
%     .rawWaveform      - Average waveform on maxWaveformCh (from raw binary file)
%     .filtWaveform     - Average filtered waveform on maxWaveformCh (from raw binary file)
%     .rawWaveform_std  - Average waveform on maxWaveformCh (from raw binary file)
%     .filtWaveform_std - Average filtered waveform on maxWaveformCh (from raw binary file)
%     .peakVoltage      - Peak voltage (uV)
%     .cluID            - Cluster ID
%     .shankID          - shankID
%     .processingInfo   - Processing info
%
% DEPENDENCIES:
% - npy-matlab toolbox (required for reading phy, AllenSDK & ALF data: https://github.com/kwikteam/npy-matlab)
% - LoadXml.m: included with CellExplorer: https://github.com/petersenpeter/CellExplorer/tree/master/calc_CellMetrics/private
% - getWaveformsFromDat: included with CellExplorer
%
%
% EXAMPLE CALLS
% spikes = loadSpikes('session',session); % clustering format should be specified in the session struct
% spikes = loadSpikes('basepath',pwd,'clusteringpath','relativeOutputFolder'); % Run from basepath (pwd), assumes Phy format.
% spikes = loadSpikes('basepath',pwd,'format','mclust'); % Run from basepath, loads MClust format.
% spikes = loadSpikes('session',session,'UID',1:30,'shankID',1:3); % Loads spikes and filters output - only UID 1:30 and the first 3 electrodeGroups.
% spikes = loadSpikes('basepath',pwd,'format','custom','spikes_times',spikes_times); % Run from basepath, custom spike format, requires the spike times as input. 

% By Peter Petersen
% petersen.peter@gmail.com
% Last edited: 17-10-2022

% Updates for reading multiprobe recordings with SGLX acquisition
% Sid Rafilson
% Last edited: 10-2-2026


% Version history
% 3.2 waveforms for phy data extracted from the raw dat
% 3.3 waveforms extracted from raw dat using memmap function. Interval and bad channels bugs fixed as well
% 3.4 bug fix which gave misaligned waveform extraction from raw dat. Plot improvements of waveforms
% 3.5 new name and better handling of inputs
% 3.6 All waveforms across channels extracted from raw dat file
% 3.7 Switched from xml to session struct for metadata
% 3.8 Waveforn extraction separated into its own function
% 4.1 Adding filter options (e.g. UID, shankID, cluID, region)
% 4.3 Support for SpyKING Circus
% 5.0 Support for SGLX and removed unnecessary format support. Specifies the Kilosort label for loaded clusters

p = inputParser;
addParameter(p,'basepath',pwd,@ischar); % basepath with dat file, used to extract the waveforms from the dat file
addParameter(p,'clusteringpath',[],@ischar); % relativ clustering path to spike data (optional)
addParameter(p,'format',[],@ischar); % clustering format: phy, klustakwik/neurosuite, KlustaViewa, NWB, Wave_clus, MClust, UltraMegaSort2000, ALF, AllenSDK
                                                     % TODO: 'SpyKING CIRCUS', 'MountainSort', 'IronClust'
addParameter(p,'basename','',@ischar); % The basename file naming convention
addParameter(p,'electrodeGroups',nan,@isnumeric); % electrodeGroups: Loading only a subset of electrodeGroups from the spike format (only applicable to Klustakwik/neurosuite and KlustaViewa)
addParameter(p,'raw_clusters',false,@islogical); % raw_clusters: Load only a subset of clusters (might not work anymore as it has not been tested for a long time)
addParameter(p,'saveMat',true,@islogical); % Save spikes to mat file?
addParameter(p,'forceReload',false,@islogical); % Reload spikes from original format (overwrites existing mat file if saveMat==true)?
addParameter(p,'getWaveformsFromDat',true,@islogical); % Gets waveforms from dat (binary file). If false, the script will use waveforms from other sources.
addParameter(p,'getWaveformsFromSource',false,@islogical); % Use Waveform from processed sources. E.g. waveforms stored in Neurosuite format.
addParameter(p,'spikes',[],@isstruct); % Load existing spikes structure to append new spike info
addParameter(p,'LSB',0.195,@isnumeric); % Least significant bit (LSB in uV/bit) Intan = 0.195, Amplipex = 0.3815. (range/precision)
addParameter(p,'session',[],@isstruct); % A buzsaki lab session struct
addParameter(p,'labelsToRead',{'good'},@iscell); % allows you to load units with various labels, e.g. MUA or a custom label
addParameter(p,'showWaveforms',true,@islogical);
addParameter(p,'showGUI',false,@islogical);

% Custom spike input
addParameter(p,'spikes_times',{},@iscell); % allows you to load spike data from a cell array with timestamps (formatted as spikes.times)

% Filters - All good cells are saved to the struct but the function output can be filtered by below fields
addParameter(p,'UID',[],@isnumeric);        % Filter by UID
addParameter(p,'shankID',[],@isnumeric);    % Filter by shankID
addParameter(p,'cluID',[],@isnumeric);      % Filter by cluID
addParameter(p,'region',[],@isstring);      % Filter by brain regions

parse(p,varargin{:})

basepath = p.Results.basepath;
clusteringpath = p.Results.clusteringpath;
format = p.Results.format;
basename = p.Results.basename;
electrodeGroups = p.Results.electrodeGroups;
raw_clusters = p.Results.raw_clusters;
spikes = p.Results.spikes;
LSB = p.Results.LSB;
session = p.Results.session;
labelsToRead = p.Results.labelsToRead;
spikes_times = p.Results.spikes_times;
showGUI = p.Results.showGUI;

parameters = p.Results;

if ~isempty(session)
    basename = session.general.name;
    basepath = session.general.basePath;
elseif isempty(basename)
    basename = basenameFromBasepath(basepath);
end

if exist(fullfile(basepath,[basename,'.spikes.cellinfo.mat']),'file') && ~parameters.forceReload
    load(fullfile(basepath,[basename,'.spikes.cellinfo.mat']))
    if ~isfield(spikes,'processinginfo') || (isfield(spikes,'processinginfo') && spikes.processinginfo.version < 3 && strcmp(spikes.processinginfo.function,'loadSpikes') )
        parameters.forceReload = true;
        disp('spikes.mat structure not up to date. Reloading spikes.')
    end
elseif ~isempty(spikes)
    disp('loadSpikes: Using existing spikes file')
% elseif exist(fullfile(basepath,[basename,'.spikes.cellinfo.mat']),'file') 
%     load(fullfile(basepath,[basename,'.spikes.cellinfo.mat']))
else
    parameters.forceReload = true;
    spikes = [];
    showGUI = true;
end

% Loading spikes
if parameters.forceReload
    if isempty(session)
        session = loadSession(basepath,basename); % ,'showGUI',showGUI
        if isfield(session.extracellular,'leastSignificantBit') && session.extracellular.leastSignificantBit>0
            LSB = session.extracellular.leastSignificantBit;
        end
    end
    if ~ischar(format)
        try
            format = session.spikeSorting{1}.format;
        catch
            format = 'Phy';
        end
    end
    
    if ~ischar(clusteringpath)
        try
            clusteringpath = session.spikeSorting{1}.relativePath;
        catch
            clusteringpath = '';
        end
    end

    clusteringpath_full = fullfile(basepath,clusteringpath);
    
    % If the least significant bit is not defined, a default value will be used
    if ~isfield(session,'extracellular') || ~isfield(session.extracellular,'leastSignificantBit') || session.extracellular.leastSignificantBit == 0
        session.extracellular.leastSignificantBit = LSB; % getWaveformsFromDat also uses this
    end
    
    % If number of channels or electrode groups are missing in the session struct, the script will try to import this from a basename.sessionInfo.mat or a basename.xml file.
    if ~isfield(session.extracellular,'nChannels') || ~isfield(session.extracellular,'electrodeGroups') || ~isfield(session.extracellular,'sr')
        if exist(fullfile(session.general.basePath,[session.general.name,'.sessionInfo.mat']),'file')
            session = loadBuzcodeMetadata(session);
        elseif exist(fullfile(session.general.basePath,[session.general.name, '.xml']),'file')
            session = loadNeurosuiteMetadata(session);
        else
            session = sessionTemplate(session);
        end
        % TODO: A gui will be shown allowing for manual edits of extracellular parameters        
    end
    
    spikes = [];
    
    switch lower(format)
        case 'custom'
            nCells = numel(spikes_times);
            spikes.times = spikes_times;
            for i = 1:nCells
                spikes.cluID(i) = i;
                spikes.total(i) = length(spikes.times{i});
            end
            
        case 'phy' % Loading phy
            % Required files:
            % spike_clusters.npy    # Spike cluster indexes
            % spike_times.npy       # Spike timestamps
            %
            % Phy1: 
            % cluster_group.tsv
            %
            % Phy2: 
            % cluster_groups.csv or cluster_KSLabel.tsv
            % cluster_info
            %
            % Optional:
            % amplitudes.npy        # Spike amplitudes
            %
            % Optional (from Phy plugins):
            % cluster_ids.npy       # List of cluster ids
            % shanks.npy            # List of shank ids for the clusters in cluster_ids
            % peak_channel.npy      # List of peak channels for the clusters in cluster_ids
            % 
            
            if ~exist('readNPY.m','file')
                error('''readNPY.m'' is not in your path and is required to load the python data. Please download it here: https://github.com/kwikteam/npy-matlab.')
            end
            disp('loadSpikes: Loading Phy data')
            spike_cluster_index = readNPY(fullfile(clusteringpath_full, 'spike_clusters.npy'));
            spike_times = readNPY(fullfile(clusteringpath_full, 'spike_times.npy'));
            if exist(fullfile(clusteringpath_full, 'amplitudes.npy'),'file')
                spike_amplitudes = readNPY(fullfile(clusteringpath_full, 'amplitudes.npy'));
            end
            spike_clusters = unique(spike_cluster_index);
            file_cluster_group_tsv = fullfile(clusteringpath_full,'cluster_group.tsv');
            file_cluster_groups_csv = fullfile(clusteringpath_full,'cluster_groups.csv');
            file_cluster_KSLabel_tsv = fullfile(clusteringpath_full,'cluster_KSLabel.tsv');
            if exist(fullfile(clusteringpath_full, 'cluster_ids.npy'),'file') && exist(fullfile(clusteringpath_full, 'shanks.npy'),'file') && exist(fullfile(clusteringpath_full, 'peak_channel.npy'),'file')
                cluster_ids = readNPY(fullfile(clusteringpath_full, 'cluster_ids.npy'));
                unit_shanks = readNPY(fullfile(clusteringpath_full, 'shanks.npy'));
                peak_channel = readNPY(fullfile(clusteringpath_full, 'peak_channel.npy'))+1;
                if exist(fullfile(clusteringpath_full, 'rez.mat'),'file')
                    load(fullfile(clusteringpath_full, 'rez.mat'))
                    temp = find(rez.connected);
                    peak_channel = temp(peak_channel);
                    clear rez temp
                end
            end
            if exist(fullfile(clusteringpath_full,'cluster_info.tsv'),'file')
                cluster_info = tdfread(fullfile(clusteringpath_full,'cluster_info.tsv'));
            end
            delimiter = '\t';
            startRow = 2;
            formatSpec = '%f%s%[^\n\r]';
            if exist(file_cluster_group_tsv,'file')
                % Verifying the file is not empty
                fileID = fopen(file_cluster_group_tsv,'r');
                dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false);
                fclose(fileID);
                if isempty(dataArray{1})
                    disp(['Noc clusters found in ', file_cluster_group_tsv,'. Will use the labels from KiloSort'])
                    filename = file_cluster_KSLabel_tsv;
                else
                    filename = file_cluster_group_tsv;
                end                    
            elseif exist(file_cluster_groups_csv,'file')
                filename = file_cluster_groups_csv;
                delimiter = ',';
            elseif exist(file_cluster_KSLabel_tsv,'file')
                filename = file_cluster_KSLabel_tsv;
            else
                error('Phy: No cluster group file found (cluster_group.tsv, cluster_groups.csv or cluster_KSLabel.tsv)')
            end
            
            fileID = fopen(filename,'r');
            dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false);
            fclose(fileID);
            UID = 1;
            tol_samples = session.extracellular.sr*5e-4; % 0.5 ms tolerance in timestamp units
            for i = 1:length(dataArray{1})
                if raw_clusters == 0
                    if any(strcmpi(dataArray{2}{i},labelsToRead))
                        if sum(spike_cluster_index == dataArray{1}(i))>0
                            spikes.ids{UID} = find(spike_cluster_index == dataArray{1}(i));
                            [spikes.ts{UID},ind_unique] = uniquetol(double(spike_times(spikes.ids{UID})),tol_samples,'DataScale',1); % unique values within tol (<= 0.8ms)
                            spikes.ids{UID} = spikes.ids{UID}(ind_unique);
                            spikes.times{UID} = spikes.ts{UID}/session.extracellular.sr;
                            spikes.cluID(UID) = dataArray{1}(i);
                            spikes.total(UID) = length(spikes.ts{UID});
                            
                            if exist('spike_amplitudes','var')
                                spikes.amplitudes{UID} = double(spike_amplitudes(spikes.ids{UID}));
                            end
                            
                            % Phy plugins:
                            if exist('cluster_ids','var')
                                cluster_id = find(cluster_ids == spikes.cluID(UID));
                                spikes.maxWaveformCh1(UID) = double(peak_channel(cluster_id)); % index 1;
                                spikes.maxWaveformCh(UID) = double(peak_channel(cluster_id))-1; % index 0;
                                
                                % Assigning shankID to the unit
                                for jj = 1:session.extracellular.nElectrodeGroups
                                    if any(session.extracellular.electrodeGroups.channels{jj} == spikes.maxWaveformCh1(UID))
                                        spikes.shankID(UID) = jj;
                                    end
                                end
                            end
                            
                            % New file data format of phy2
                            if exist('cluster_info','var')
                                if isfield(cluster_info,'id')
                                    temp = find(cluster_info.id == spikes.cluID(UID));
                                else %in the recent(2021) version of Phy2: isfield(cluster_info,'cluster_id')
                                    temp = find(cluster_info.cluster_id == spikes.cluID(UID));
                                end
                                spikes.maxWaveformCh(UID) = cluster_info.ch(temp); % max waveform channel
                                spikes.maxWaveformCh1(UID) = cluster_info.ch(temp)+1; % index 1;
                                spikes.phy_maxWaveformCh1(UID) = cluster_info.ch(temp)+1; % index 1; saves the max waveform channel from phy as a separate variable
                                spikes.phy_amp(UID) = cluster_info.amp(temp)+1; % spike amplitude
                                % spikes.phy_purity(UID) = cluster_info.purity(temp)+1; % cluster purity                                
                            end

                            UID = UID+1;
                        end
                    end
                else
                    spikes.ids{UID} = find(spike_cluster_index == dataArray{1}(i));
                    tol = tol_ms/max(double(spike_times(spikes.ids{UID}))); % unique values within tol (=within 1 ms)
                    [spikes.ts{UID},ind_unique] = uniquetol(double(spike_times(spikes.ids{UID})),tol);
                    spikes.ids{UID} = spikes.ids{UID}(ind_unique);
                    spikes.times{UID} = spikes.ts{UID}/session.extracellular.sr;
                    spikes.cluID(UID) = dataArray{1}(i);
                    
                    if exist('spike_amplitudes','var')
                        spikes.amplitudes{UID} = double(spike_amplitudes(spikes.ids{UID}))';
                    end
                    UID = UID+1;
                end
            end

            if parameters.getWaveformsFromSource
                disp('Getting waveforms from the phy template')
                filename_templates = fullfile(clusteringpath_full,'templates.npy');
                if exist(filename_templates,'file')
                    templates = readNPY(fullfile(clusteringpath_full, 'templates.npy'));
                    spike_templates = readNPY(fullfile(clusteringpath_full, 'spike_templates.npy'));

                    for UID = 1:numel(spikes.times)
                        template_id = double(mode(spike_templates(spikes.ids{UID})));
                        spikes.filtWaveform_all{UID} = permute(double(templates(template_id,:,:)),[3 2 1]);
                        [~,idx] = max(range(spikes.filtWaveform_all{UID}'));
                        spikes.filtWaveform{UID} = double(templates(template_id,:,idx));
                    end
                end
            end

            disp(['Importing ' num2str(numel(spikes.times)),'/', num2str(length(dataArray{1})),' clusters from phy'])
            
            
        case 'sglx' % Phy output + SpikeGLX/CatGT/TPrime-aligned seconds (multi-shank common clock)
            % Loads BOTH:
            %   - spike_times.npy            (sample timestamps; raw clock; for Neuroscope/raw alignment)
            %   - spike_times_sec_adj.npy    (seconds; TPrime-aligned common clock across shanks)
            %
            % Stores:
            %   spikes.ts{UID}               = raw sample timestamps (from spike_times.npy)
            %   spikes.times{UID}            = raw seconds timestamps = spikes.ts{UID}/sr  [CellExplorer canonical]
            %   spikes.times_sec_adj{UID}    = adjusted spike times from Tprime (explicit field name)(optional convenience(from spike_times_sec_adj.npy)
    
            %
            % Uniqueness:
            %   Applied in SAMPLE units using spike_times.npy (0.5 ms tolerance in samples), and the same
            %   ind_unique mask is applied to spike_times_sec_adj to preserve 1:1 correspondence.

            if ~exist('readNPY.m','file')
                error('''readNPY.m'' is not in your path and is required to load the phy data. Please download it here: https://github.com/kwikteam/npy-matlab.')
            end

            disp('loadSpikes: Loading Phy data (SGLX/TPrime-aligned seconds)')

            % Required
            spike_cluster_index   = readNPY(fullfile(clusteringpath_full, 'spike_clusters.npy'));
            spike_times_samples   = readNPY(fullfile(clusteringpath_full, 'spike_times.npy'));          % samples (int)
            spike_times_sec_adj   = readNPY(fullfile(clusteringpath_full, 'spike_times_sec_adj.npy'));  % seconds (float)

            if numel(spike_times_samples) ~= numel(spike_times_sec_adj)
                error('SGLX: spike_times.npy and spike_times_sec_adj.npy must have the same length (aligned by index).')
            end

            % Optional amplitudes
            if exist(fullfile(clusteringpath_full, 'amplitudes.npy'),'file')
                spike_amplitudes = readNPY(fullfile(clusteringpath_full, 'amplitudes.npy'));
            end

            % Optional Phy plugins (cluster_ids/shanks/peak_channel)
            file_cluster_ids   = fullfile(clusteringpath_full, 'cluster_ids.npy');
            file_shanks        = fullfile(clusteringpath_full, 'shanks.npy');
            file_peak_channel  = fullfile(clusteringpath_full, 'peak_channel.npy');
            if exist(file_cluster_ids,'file') && exist(file_shanks,'file') && exist(file_peak_channel,'file')
                cluster_ids   = readNPY(file_cluster_ids);
                unit_shanks   = readNPY(file_shanks); %#ok<NASGU> % not used directly below but kept for reference
                peak_channel  = readNPY(file_peak_channel) + 1;   % to 1-indexed

                % Optional rez connected-channel remap
                if exist(fullfile(clusteringpath_full, 'rez.mat'),'file')
                    load(fullfile(clusteringpath_full, 'rez.mat')) %#ok<LOAD>
                    temp = find(rez.connected);
                    peak_channel = temp(peak_channel);
                    clear rez temp
                end
            end

            % Optional cluster info
            if exist(fullfile(clusteringpath_full,'cluster_info.tsv'),'file')
                cluster_info = tdfread(fullfile(clusteringpath_full,'cluster_info.tsv'));
            end

            % Determine label file (Phy1/Phy2/KiloSort label TSV/CSV)
            file_cluster_group_tsv   = fullfile(clusteringpath_full,'cluster_group.tsv');
            file_cluster_groups_csv  = fullfile(clusteringpath_full,'cluster_groups.csv');
            file_cluster_KSLabel_tsv = fullfile(clusteringpath_full,'cluster_KSLabel.tsv');

            delimiter = '\t';
            startRow = 2;
            formatSpec = '%f%s%[^\n\r]';

            if exist(file_cluster_group_tsv,'file')
                fileID = fopen(file_cluster_group_tsv,'r');
                dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines', startRow-1, 'ReturnOnError', false);
                fclose(fileID);
                if isempty(dataArray{1})
                    disp(['No clusters found in ', file_cluster_group_tsv, '. Will use labels from KiloSort'])
                    filename = file_cluster_KSLabel_tsv;
                else
                    filename = file_cluster_group_tsv;
                end
            elseif exist(file_cluster_groups_csv,'file')
                filename = file_cluster_groups_csv;
                delimiter = ',';
            elseif exist(file_cluster_KSLabel_tsv,'file')
                filename = file_cluster_KSLabel_tsv;
            else
                error('SGLX: No cluster group file found (cluster_group.tsv, cluster_groups.csv, or cluster_KSLabel.tsv).')
            end

            % Read label file -> (cluster_id, label)
            fileID = fopen(filename,'r');
            dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines', startRow-1, 'ReturnOnError', false);
            fclose(fileID);

            UID = 1;
            tol_samples = session.extracellular.sr * 5e-4; % 0.5 ms in samples

            % Looping over the clusters
            for i = 1:length(dataArray{1})
                cluster_id = dataArray{1}(i);

                % Determine whether to include this cluster
                label = dataArray{2}{i};  % default from file
                include_cluster = true;
                if ~raw_clusters
                    include_cluster = any(strcmpi(dataArray{2}{i}, labelsToRead));
                end
                if ~include_cluster
                    continue
                end

                % Find spikes for this cluster
                ids = find(spike_cluster_index == cluster_id);
                if isempty(ids)
                    continue
                end

                % --- Uniqueness on RAW SAMPLE timestamps (preserve mapping across arrays)
                ts_samp = double(spike_times_samples(ids));
                [ts_samp_u, ind_unique] = uniquetol(ts_samp, tol_samples, 'DataScale', 1);
                ids_u = ids(ind_unique);

                % --- Store indices + times + label
                spikes.ids{UID}  = ids_u;
                spikes.ts{UID}   = ts_samp_u(:);                               % samples (raw clock)
                t_adj_sec_u      = double(spike_times_sec_adj(ids_u));
                spikes.times{UID}         = spikes.ts{UID} / session.extracellular.sr;                 
                spikes.times_sec_adj{UID} = t_adj_sec_u(:);                 % seconds (aligned common clock) 
                spikes.label{UID} = label;

                spikes.cluID(UID) = cluster_id;
                spikes.total(UID) = numel(spikes.ts{UID});

                % Optional amplitudes (aligned to unique ids)
                if exist('spike_amplitudes','var')
                    spikes.amplitudes{UID} = double(spike_amplitudes(ids_u));
                end

                % Phy plugins: peak channel + shankID based on electrodeGroups
                if exist('cluster_ids','var')
                    cluster_idx = find(cluster_ids == spikes.cluID(UID));
                    if ~isempty(cluster_idx)
                        spikes.maxWaveformCh1(UID) = double(peak_channel(cluster_idx));     % 1-indexed
                        spikes.maxWaveformCh(UID)  = spikes.maxWaveformCh1(UID) - 1;      % 0-indexed

                        % Assign shankID using electrodeGroups.channels
                        for jj = 1:session.extracellular.nElectrodeGroups
                            if any(session.extracellular.electrodeGroups.channels{jj} == spikes.maxWaveformCh1(UID))
                                spikes.shankID(UID) = jj;
                                break
                            end
                        end
                    end
                end

                % Phy2 cluster_info.tsv: override/augment channel fields if present
                if exist('cluster_info','var')
                    if isfield(cluster_info,'id')
                        temp = find(cluster_info.id == spikes.cluID(UID));
                    else
                        temp = find(cluster_info.cluster_id == spikes.cluID(UID));
                    end
                    if ~isempty(temp)
                        spikes.maxWaveformCh(UID)       = cluster_info.ch(temp);      % 0-indexed
                        spikes.maxWaveformCh1(UID)      = cluster_info.ch(temp) + 1;  % 1-indexed
                        spikes.phy_maxWaveformCh1(UID)  = cluster_info.ch(temp) + 1;  % keep phy channel explicitly
                        spikes.phy_amp(UID)             = cluster_info.amp(temp) + 1; % matches upstream code pattern
                    end
                end

                UID = UID + 1;
            end

            disp(['Importing ' num2str(numel(spikes.times)),'/', num2str(length(dataArray{1})),' clusters from phy (SGLX/TPrime-aligned seconds)'])

            % Helpful provenance
            spikes.processinginfo.params.timeSourceSamples = 'spike_times.npy (samples; raw clock)';
            spikes.processinginfo.params.timeSourceSeconds = 'spike_times_sec_adj.npy (seconds; TPrime-aligned common clock)';
            spikes.processinginfo.params.uniqueTolSamples  = tol_samples;
            spikes.processinginfo.params.uniqueTolSec      = 5e-4;

                           
     
        case {'nwb'} % nwb datafile
            disp('loadSpikes: Loading NWB data')
            nwb_file = fullfile(session.general.basePath,[session.general.name,'.nwb']);
            info = h5info(nwb_file);
            fieldsToExtract = {'PT_ratio','amplitude','amplitude_cutoff','cluster_id','cumulative_drift','d_prime','firing_rate','id','isi_violations','isolation_distance','l_ratio','local_index','max_drift','nn_hit_rate','nn_miss_rate', ...
                'peak_channel_id','presence_ratio','quality','recovery_slope','repolarization_slope','silhouette_score','snr','spike_amplitudes','spike_amplitudes_index','spike_times','spike_times_index','spread','velocity_above',...
                'velocity_below','waveform_duration','waveform_halfwidth','waveform_mean','waveform_mean_index'};
            
            for i = 1:numel(fieldsToExtract)
                disp(['Loading ' fieldsToExtract{i},' (',num2str(i),'/',num2str(numel(fieldsToExtract)),')'])
                if strcmp(fieldsToExtract{i},'spike_times')
                    spike_data = h5read(nwb_file,['/units/','spike_times']);
                    spike_data_index = h5read(nwb_file,['/units/','spike_times_index']);
                    spikes.total = double([spike_data_index(1);diff(spike_data_index)]);
                    index = [0;spike_data_index];
                    for j = 1:numel(spike_data_index)
                        spikes.times{j} = spike_data(index(j)+1:index(j+1));
                    end
                elseif strcmp(fieldsToExtract{i},'spike_amplitudes')
                    spike_data = h5read(nwb_file,['/units/','spike_amplitudes']);
                    spike_data_index = h5read(nwb_file,['/units/','spike_amplitudes_index']);
                    index = [0;spike_data_index];
                    for j = 1:numel(spike_data_index)
                        spikes.amplitudes{j} = spike_data(index(j)+1:index(j+1));
                    end
                elseif strcmp(fieldsToExtract{i},'waveform_mean')
                    spike_data = h5read(nwb_file,['/units/','waveform_mean']);
                    spike_data_index = h5read(nwb_file,['/units/','waveform_mean_index']);
                    index = [0;spike_data_index];
                    for j = 1:numel(spike_data_index)
                        spikes.waveform_mean{j} = spike_data(:,index(j)+1:index(j+1));
                        spikes.waveform_mean_filt{j} = spikes.waveform_mean{j};
                    end
                elseif any(strcmp(fieldsToExtract{i},{'spike_times_index','waveform_mean_index','spike_amplitudes_index'}))
                    % disp('Not imported')
                elseif strcmp(fieldsToExtract{i},'cluster_id')
                    spikes.cluID = double(h5read(nwb_file,['/units/',fieldsToExtract{i}]))';
                elseif  strcmp(fieldsToExtract{i},'amplitude')
                    spikes.peakVoltage = h5read(nwb_file,['/units/',fieldsToExtract{i}]);
                elseif strcmp(fieldsToExtract{i},'peak_channel_id')
                    % maxWaveformCh
                    electrode_channel_id = double(h5read(nwb_file,'/general/extracellular_ephys/electrodes/id'));
                    peak_channel_id = double(h5read(nwb_file,['/units/','peak_channel_id']));
                    for j = 1:numel(peak_channel_id)
                        spikes.maxWaveformCh1(j) = find(peak_channel_id(j) == electrode_channel_id);
                    end
                    spikes.maxWaveformCh = spikes.maxWaveformCh1-1;
                    spikes.peak_channel_id = peak_channel_id';
                else
                    fieldData =  h5read(nwb_file,['/units/',fieldsToExtract{i}]);
                    if isnumeric(fieldData)
                        spikes.(fieldsToExtract{i}) = fieldData';
                    else
                        spikes.(fieldsToExtract{i}) = fieldData;
                    end
                end
            end
                        
            spikes.numcells = numel(spikes.times);
            
            spikes.processinginfo.params.WaveformsSource = 'nwb';
            
            % Flipping dimensions on fields if necessary
            spikesFields = fieldnames(spikes);
            for j = 1:numel(spikesFields)
                if size(spikes.(spikesFields{j})) == [spikes.numcells,1]
                    spikes.(spikesFields{j}) = spikes.(spikesFields{j})';
                end
            end
            
        
        
        otherwise
            error('Please provide a compatible clustering format')
    end
    spikes.basename = basename;
    spikes.numcells = numel(spikes.times);
    spikes.UID = 1:spikes.numcells;
    spikes.sr = session.extracellular.sr;
    
    % Getting waveforms from dat (raw data)
    if parameters.getWaveformsFromDat && ~strcmpi(format,'allensdk')
        spikes = getWaveformsFromDat(spikes,session,'showWaveforms',parameters.showWaveforms,'saveMat', parameters.saveMat);
    end
    
    % Attaching info about how the spikes structure was generated
    spikes.processinginfo.function = 'loadSpikes';
    spikes.processinginfo.version = 5.0;
    spikes.processinginfo.date = now;
    spikes.processinginfo.params.forceReload = parameters.forceReload;
    spikes.processinginfo.params.electrodeGroups = electrodeGroups;
    spikes.processinginfo.params.raw_clusters = raw_clusters;
    spikes.processinginfo.params.getWaveformsFromDat = parameters.getWaveformsFromDat;
    spikes.processinginfo.params.basename = basename;
    spikes.processinginfo.params.format = format;
    spikes.processinginfo.params.clusteringpath = clusteringpath;
    spikes.processinginfo.params.basepath = basepath;
    spikes.processinginfo.params.getWaveformsFromSource = parameters.getWaveformsFromSource;
    try
        spikes.processinginfo.username = char(java.lang.System.getProperty('user.name'));
        spikes.processinginfo.hostname = char(java.net.InetAddress.getLocalHost.getHostName);
    catch
        disp('Failed to retrieve system info.')
    end
    
    % Saving output to a CellExplorer compatible spikes file.
    if parameters.saveMat
        disp('loadSpikes: Saving spikes')
        try
            structSize = whos('spikes');
            if structSize.bytes/1000000000 > 2
                save(fullfile(basepath,[basename,'.spikes.cellinfo.mat']),'spikes','-v7.3')
            else
                save(fullfile(basepath,[basename,'.spikes.cellinfo.mat']),'spikes')
            end
        catch
            warning('Spikes could not be saved')
        end
    end
end

filteredFields = {'UID','shankID','cluID','region'};
for i = 1:numel(filteredFields)
    if ~isempty(parameters.(filteredFields{i}))
        if isfield(spikes, filteredFields{i})
            toRemove = ~ismember(spikes.(filteredFields{i}),parameters.(filteredFields{i}));
            
            spikes = removeCells(toRemove,spikes);
        else
            warning(['The filtered field does not exist in the spikes struct: ' filteredFields{i}])
        end
    end
end


end

function spikes = removeCells(UIDsToRemove,spikes)
    % Function to remove cells from the structure. toRemove is the INDEX of the UID in spikes.UID
    % Functionaloty taken from Buzcode but altered to include all fields.
    
    fields2clean = fieldnames(spikes);
    for i = 1:numel(fields2clean)
        if (iscell(spikes.(fields2clean{i})) || isnumeric(spikes.(fields2clean{i}))) && numel(spikes.(fields2clean{i})) == spikes.numcells
            % Cleaning only cell array- and numeric fields
            spikes.(fields2clean{i})(UIDsToRemove) = [];
        end
    end 
    if ~isfield(spikes,'numcells_orig')
        spikes.numcells_orig = spikes.numcells;
    end
    spikes.numcells = sum(~UIDsToRemove);
end
