function fileInfo = dataPathsNP2_SpikeGLX_multi_NP2(basepath, numOfProbes)

% basepath is buzcode convention
% numOfProbes in integer of number of probes recorded with spikeGLX

cd(basepath)
for tt = 1:numOfProbes
    
    probe_ID = tt-1;
    d = dir(['**/*imec' num2str(probe_ID) '.ap.bin']);
    d2 = dir(['**/*imec' num2str(probe_ID) '.ap.meta']);
    
    
    nFolders = length(d);
    
    fileInfo.nFolders{tt} = nFolders;
    fileInfo.basepath{tt} = basepath;
    [~,basename] = fileparts(basepath);
    fileInfo.basename{tt} = [basename '_imec' num2str(probe_ID)];
    
    folder0 = cell(1,nFolders);
    folder = cell(1,nFolders);
    folderTTL = cell(1,nFolders);
    for fIdx = 1:nFolders
        folder0{fIdx} = [d(fIdx).folder];
        folder{fIdx} = [d(fIdx).folder,filesep,d(fIdx).name];
        folderTTL{fIdx} = [d2(fIdx).folder,filesep,d2(fIdx).name];
        recordingTime(fIdx) = str2num(d(fIdx).date([13 14 16 17 19 20]));
        
    end
    
    %just make sure files are in correct temporal order
    [~,i] = sort(recordingTime);
    fileInfo.folder{tt} = folder0(i);
    fileInfo.datPath_file{tt} = folder(i);
    fileInfo.folderTTL{tt} = folderTTL(i);
    fileInfo.recordingTime{tt} = recordingTime(i);
    
    fileInfo.datPath{tt} = d;
    fileInfo.ttlPath{tt} = d2;
end
clear tt
end