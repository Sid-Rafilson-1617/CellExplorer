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
    addParameter(p, 'imroDir_path', '\\research-cifs.nyumc.org\research\buzsakilab\Homes\voerom01\Bilat_HPC\Bilat_R02\IMRO_files', ...
        @(x) ischar(x) || isstring(x));
    addParameter(p, 'targetDir', pwd, @(x) ischar(x) || isstring(x));
    
    parse(p,varargin{:});
    basepath = p.Results.basepath;
    imroDir_path = p.Results.imroDir_path;
    targetDir = p.Results.targetDir;
    
    
    %% Locate .meta file in current directory 
    metaFiles = dir(fullfile(basepath, '*ap.meta'));
    metaFiles = fullfile({metaFiles.folder}, {metaFiles.name});
    disp(metaFiles)
    if numel(metaFiles) == 0
        error('No .meta file found in the current directory: %s', basepath);
    elseif numel(metaFiles) > 1
        error('Multiple .meta files found in the current directory. Please keep only one or specify which to use.');
    end
    metaFile = metaFiles{1};
    
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
