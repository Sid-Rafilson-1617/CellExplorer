function session = bz_getSession(varargin)

p = inputParser;
addParameter(p,'basepath',pwd,@isstr)
addParameter(p,'datFile', '', @isstr) % added 3/8/25 by NP

parse(p,varargin{:});
basepath = p.Results.basepath;
datFile = p.Results.datFile;

if isempty(datFile)
    sesfile = checkFile('basepath',basepath,'fileType','.session.mat');
    load([sesfile.folder,filesep,sesfile.name],'session');
else
    [~, basename] = fileparts(datFile);
    sesfile = checkFile('basepath',basepath,'filename', ...
        [basename, '.session.mat']);
    load([sesfile.folder,filesep,sesfile.name],'session');
end