function channelGroups = imro2xml_FINAL(varargin)
% TO USE: imro2xml_FINAL('imroFile','/path/to/file.imro','xmlFile','/path/to/file.xml')
%
% If 'imroFile' or 'xmlFile' are not specified, the function searches the 
% directory 'basepath' (default = pwd). Exactly one .imro file
% and one .xml file are required, otherwise it will throw an error.
%
% This function:
%  1) Copies .imro file from specified folder to currenty directory.
%  2) Reads & parses a SpikeGLX .imro file to group channels by shank
%     (using the original imro2xml2 logic, which flips order in the .txt 
%     file to reflect the channel order from top-to-bottom of the shank).
%  3) Writes one .txt file per channel group ("shank") in the same folder.
%  4) Constructs a new <channelGroups> section for the .xml file with a channel 
%     order consistent with the same flipped order used for the .txt file
%  5) Adds an extra group that contains only channel 384 (sync channel).
%  6) Replaces the old <channelGroups>...</channelGroups> section in the
%     specified .xml file with the newly constructed version, preserving
%     everything else in the .xml file.
%  7) Constructs a parallel section for <spikeDetection>, similarly listing
%     each group's channels, but with a different tag, based on how manually 
%     assembled .xml files are formatted.
%
% TO DO: generate a template .xml file formatted similarly to a manually
% assembled .xml file instead of rewriting sections of the generic file.

p = inputParser;
addParameter(p, 'basepath', pwd, @isfolder);
addParameter(p, 'samplingRate', 30000, @isnumeric);
addParameter(p, 'nChannels', 385, @isnumeric);
addParameter(p, 'imroFile','', @(x) ischar(x) || isstring(x)); 
addParameter(p, 'xmlFile','', @(x) ischar(x) || isstring(x)); 
addParameter(p, 'genXML_path', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'imroDir_path', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'refChan', 127, @isnumeric);
addParameter(p, 'maxGap', 10, @isnumeric);

parse(p,varargin{:});
basepath = p.Results.basepath;
samplingRate = p.Results.samplingRate;
nChannels = p.Results.nChannels;
imroFile = char(p.Results.imroFile);
xmlFile  = char(p.Results.xmlFile);
genXML_path = char(p.Results.genXML_path);
imroDir_path = char(p.Results.imroDir_path);
refChan = p.Results.refChan;
maxGap   = p.Results.maxGap;

% Paths to template xml and imro files
if isempty(genXML_path)
    genXML_path = 'Z:\buzsakilab\Homes\voerom01\Use_dependent_sleep';
    %genXML_path = '/gpfs/data/buzsakilab/np2555/Glucose-SPW-Rs/rats'; % path for HPCC
end

if isempty(imroDir_path)
    imroDir_path = 'Z:\buzsakilab\Homes\voerom01\Use_dependent_sleep\Imro_files';
    %imroDir_path = '/gpfs/data/buzsakilab/np2555/Glucose-SPW-Rs/rats/UDS_R01/Imro_files';
end

%% Copy .imro specified in .meta file to target directory
imroBaseName = copyImroFromMeta('basepath',basepath,'targetDir',basepath,...
    'imroDir_path',imroDir_path);
tokens = split(imroBaseName,'_');
%imroNum = strtrim(tokens{1});
imroNum = cell2mat(tokens(contains(tokens, 'imec')));

%% Create .xml filename for new file
basename = bz_BasenameFromBasepath(basepath);
basename = basename(1:end-5); % removes imec# suffix (assumes <10 probes)

% .xml filename based on SpikeGLX file convention
xml_fileName = [basename 't0.' imroNum '.ap.xml'];
xml_fileName = fullfile(basepath, xml_fileName); % session folder

%% Locate .imro file if not specified 
if isempty(imroFile)
    imroFiles = dir(fullfile(basepath,'*.imro'));
    if numel(imroFiles) == 0
        sprintf('No .imro file found in directory: %s', basepath);
    elseif numel(imroFiles) > 1
        sprintf('Multiple .imro files found in directory: %s.\nSpecify which one via ''imroFile''.', basepath);
    else
        imroFile = fullfile(basepath, imroFiles(1).name);
    end
end

%% Locate .xml file if not specified 
if isempty(xmlFile)
    xmlFiles = dir(fullfile(basepath,'*.xml'));
    if numel(xmlFiles) == 0
        sprintf('No .xml file found in directory: %s', basepath);
        xmlFiles = dir(fullfile(genXML_path,'*.xml'));
        xmlFile = fullfile(genXML_path, xmlFiles(1).name);
    elseif numel(xmlFiles) > 1
        sprintf('Multiple .xml files found in directory: %s.\nSpecify which one via ''xmlFile''.', basepath);
    else
        xmlFile = fullfile(basepath, xmlFiles(1).name);
    end
end

%% Call imro2xml2
% Parse the .imro file, write the .txt files, and store the flipped array 
% in channelGroups, which will be used to rewrite the .xml file later.

channelGroups = imro2xml2('basepath', basepath, 'imroFile', imroFile, 'maxGap', maxGap);

%% Build new <channelGroups> string for <anatomicalDescription> section
newChannelGroupsStr = sprintf('  <channelGroups>\n');

for g = 1:numel(channelGroups)
    thisGroup = channelGroups{g};
    newChannelGroupsStr = [newChannelGroupsStr, sprintf('   <group>\n')];
    for ch = 1:numel(thisGroup)
        newChannelGroupsStr = [newChannelGroupsStr, ...
            sprintf('    <channel skip="0">%d</channel>\n', thisGroup(ch))];
    end
    newChannelGroupsStr = [newChannelGroupsStr, sprintf('   </group>\n')];
end

%% Add extra group for sync channel 384
newChannelGroupsStr = [newChannelGroupsStr, sprintf('   <group>\n')];
newChannelGroupsStr = [newChannelGroupsStr, ...
    sprintf('    <channel skip="0">%d</channel>\n', 384)];
newChannelGroupsStr = [newChannelGroupsStr, sprintf('   </group>\n')];

newChannelGroupsStr = [newChannelGroupsStr, sprintf('  </channelGroups>')];

%% Replace previous <channelGroups> section in the .xml file
oldXmlText = fileread(xmlFile); % reads generic .xml file
pattern = '(?s)<channelGroups>.*?</channelGroups>';
newXmlText = regexprep(oldXmlText, pattern, newChannelGroupsStr, 'dotall');

fid = fopen(xml_fileName, 'w');
if fid == -1
    error('Could not open XML file for writing: %s', xml_fileName);
end
fwrite(fid, newXmlText);
fclose(fid);

fprintf('Updated XML file written to: %s\n', xml_fileName);

%% Update <spikeDetection> section
newSpikeGroupsStr = sprintf('  <channelGroups>\n');

for g = 1:numel(channelGroups)
    thisGroup = channelGroups{g};
    newSpikeGroupsStr = [newSpikeGroupsStr, sprintf('   <group>\n')];
    newSpikeGroupsStr = [newSpikeGroupsStr, sprintf('   <channels>\n')];
    for ch = 1:numel(thisGroup)
        if thisGroup(ch) ~= refChan
            newSpikeGroupsStr = [newSpikeGroupsStr, ...
            sprintf('    <channel>%d</channel>\n', thisGroup(ch))];
        end
    end
    newSpikeGroupsStr = [newSpikeGroupsStr, sprintf('   </channels>\n')];
    newSpikeGroupsStr = [newSpikeGroupsStr, sprintf('   </group>\n')];
end

newSpikeGroupsStr = [newSpikeGroupsStr, sprintf('  </channelGroups>')];

% Wrap in <spikeDetection> tags
newSpikeDetectionStr = sprintf('<spikeDetection>\n%s\n</spikeDetection>', newSpikeGroupsStr);

% Replace <spikeDetection> block in the .xml
updatedXmlText = fileread(xml_fileName);
patternSpike = '(?s)<spikeDetection>.*?</spikeDetection>';
if ~contains(updatedXmlText, '<spikeDetection>')
    warning('No <spikeDetection> block found in %s. Inserting at end.', xmlFile);
     updatedXmlText = [updatedXmlText, sprintf('\n%s\n', newSpikeDetectionStr)];
    else
        % Replace the entire <spikeDetection>...</spikeDetection> block
     updatedXmlText = regexprep(updatedXmlText, patternSpike, newSpikeDetectionStr, 'dotall');
end

fid = fopen(xml_fileName, 'w');
if fid == -1
    error('Could not open .xml file for writing: %s', xmlFile);
end

fwrite(fid, updatedXmlText);
fclose(fid);

fprintf('Updated <spikeDetection> in .xml file: %s\n', xmlFile);

%% Replace .xml fields with user-specified parameters
updatedXmlText = fileread(xml_fileName);
pattern_params = '(?s)<samplingRate>.*?</samplingRate>';
updatedXmlText = regexprep(updatedXmlText, pattern_params, ...
    ['<samplingRate>', num2str(samplingRate), '</samplingRate>'], 'dotall');

fid = fopen(xml_fileName, 'w');
fwrite(fid, updatedXmlText);
fclose(fid);

updatedXmlText = fileread(xml_fileName);
pattern_params = '(?s)<nChannels>.*?</nChannels>';
updatedXmlText = regexprep(updatedXmlText, pattern_params, ...
    ['<nChannels>', num2str(nChannels), '</nChannels>'], 'dotall');

fid = fopen(xml_fileName, 'w');
fwrite(fid, updatedXmlText);
fclose(fid);

end


%%%%%%%%%%%%%%%%%%%%%%%%% SUBFUNCTIONS BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function imroBaseName = copyImroFromMeta(varargin)
% User must specify the source directory containing the .imro files.
% Ideally a single folder containing all .imro files is used.

% This script:
%  1) Finds a .meta file in the current directory.
%  2) Reads the line containing 'imroFile=' to get the full .imro path.
%  3) Extracts the filename from that path.
%  4) Copies that .imro file from a specified directory to the current folder.

    p = inputParser;
    
    % Specify default directories below 
    addParameter(p, 'basepath', pwd, @(x) ischar(x) || isstring(x));
    addParameter(p, 'imroDir_path', '/gpfs/data/buzsakilab/np2555/Glucose-SPW-Rs/rats/UDS_R01/Imro_files', ...
        @(x) ischar(x) || isstring(x));
    addParameter(p, 'targetDir', pwd, @(x) ischar(x) || isstring(x));
    
    parse(p,varargin{:});
    basepath = p.Results.basepath;
    imroDir_path = p.Results.imroDir_path;
    targetDir = p.Results.targetDir;
    
    %% Locate .meta file in current directory 
    metaFiles = checkFile('basepath', basepath, 'fileType', '.meta');
    if numel(metaFiles) == 0
        error('No .meta file found in the current directory: %s', basepath);
    elseif numel(metaFiles) > 1
        error('Multiple .meta files found in the current directory. Please keep only one or specify which to use.');
    end
    metaFile = metaFiles(1).name;
    
    %% Read the .meta file and find "imroFile=" line
    fid = fopen(metaFile,'r');
    if fid < 0
        error('Could not open %s for reading.', metaFile);
    end
    
    imroLine = '';
    while ~feof(fid)
        line = fgetl(fid);
        if contains(line, 'imroFile=')
            imroLine = line;
            break;
        end
    end
    fclose(fid);
    
    if isempty(imroLine)
        error('No line containing "imroFile=" was found in %s.', metaFile);
    end
    
    % Example line:  imroFile=E:/Users/UDS_R01/Imro_files/imec0_test21.imro
    % Split at '=' and take the second part as the path:
    tokens = split(imroLine,'=');
    imroFullPath = strtrim(tokens{2});  % e.g. 'E:/Users/UDS_R01/Imro_files/imec0_test21.imro'
    
    % Parse out filename from the full path
    [~, imroBaseName, imroExt] = fileparts(imroFullPath);
    imroFilename = [imroBaseName, imroExt];  % e.g. 'imec0_test21.imro'
    
    fprintf('Found .imro filename: %s\n', imroFilename);
    
    %% Search for the .imro file in the specified source directory
    srcFile = fullfile(imroDir_path, imroFilename);
    
    % Copy the .imro file into the target directory
    destFile = fullfile(targetDir, imroFilename);
    if strcmpi(srcFile, destFile)
        fprintf('Source and destination are identical. Skipping copy.\n');
    else
        copyfile(srcFile, targetDir);
        fprintf('Copied "%s" -> "%s".\n', srcFile, targetDir);
    end
    fprintf('Copied "%s" -> "%s".\n', srcFile, targetDir);
end

function channelGroups = imro2xml2(varargin)
    p = inputParser;
    addParameter(p,'basepath',pwd,@isfolder);
    addParameter(p,'imroFile',[],@isfile);
    addParameter(p,'maxGap',10,@isnumeric);
    
    parse(p,varargin{:});
    basepath   = p.Results.basepath;
    imroFile   = p.Results.imroFile;
    maxGap     = p.Results.maxGap;
    
    if isempty(imroFile)
        fImro = checkFile('basepath',basepath,'fileType','.imro'); %#ok<NASGU>
        error('No IMRO file specified and checkFile() is not implemented here.');
    end
    
    % Read imro file
    textData = fileread(imroFile);
    
    % Use fileparts instead of checkFile function to avoid doubling the path when writing .txt
    [~, imroBaseName, ~] = fileparts(imroFile);
    saveName = imroBaseName;
    
    % Remove (24,384) from the start
    if strcmp(textData(1:8), '(24,384)') 
        textData = textData(9:end);
    else % NP2.2 (2014,384)
        textData = textData(11:end);
    end

    % Parse channelID, shankID, electrodeID
    data = textscan(textData,' %d %d %*d %*d %d', ...
    'Delimiter',{'(',')',' ',','},'MultipleDelimsAsOne',true);
    
    channelID   = data{1} + 1;  % zero-based => one-based
    shankID     = data{2} + 1;  % zero-based => one-based
    electrodeID = data{3};
    
    shankList = unique(shankID);
    nShank    = length(shankList);
    
    count = 1;
    channelGroups = {}; 
    
    for shIdx = 1:nShank
    shChans = channelID(shankID == shankList(shIdx));
    shElec  = electrodeID(shankID == shankList(shIdx));
    
    [shElecSort, sortIdx] = sort(shElec);
    shChansSort           = shChans(sortIdx);
    
    gapIdx = [0; find(diff(shElecSort)>(2*maxGap)); length(shElec)];
    
        for grIdx = 1:(length(gapIdx)-1)
            group = shChansSort((gapIdx(grIdx)+1):gapIdx(grIdx+1));
            % Switch back to 0-based indexing:
            group = group - 1;
            disp(num2str(group'))
            
            % Flip the group for writing to the .txt file:
            group_flipped = flip(group');
        
            % Write .txt in flipped order:
            txtFile = fullfile(basepath, [saveName '-sh-' num2str(count) '.txt']);
            writematrix(group_flipped, txtFile, 'Delimiter',' ');
        
            % Store the flipped group in channelGroups so the .xml matches .txt:
            channelGroups{count} = group_flipped;
        
            count = count + 1;
        end
    end
end
