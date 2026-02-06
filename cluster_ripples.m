% Detect ripple bursts and append ripple structs
baseName = bz_BasenameFromBasepath(pwd);

% Probe information
nImec = 4;
nShanks = 4;

% Parameters for ripple burst detection
params.max_inter_ripple_interval_ms = 180;
params.min_ripples_in_burst = 2;
params.isolation_window_s = 0.5;

for imec = 0:nImec-1 % loop over probes
    for shank = 0:nShanks-1
        load([baseName, '_imec', num2str(imec), '.shank', num2str(shank), '_ripples.events.mat']);
        
        % Detect ripple bursts
        burst_results = detect_ripple_bursts(ripples, params);
        
        % Extract 1st ripple peak timestamp from bursts
        nBursts = length(burst_results.burst_events);
        burst_peaks = zeros(nBursts,1);
        for n = 1:nBursts
            burst_peaks(n) = burst_results.burst_events(n).peaks(1);
        end
        burst_results.R1_peaks = burst_peaks;
        
        % Apppend/replace burst_results in ripples.events.mat file
        save([baseName, '_imec', num2str(imec), '.shank', num2str(shank), '_ripples.events.mat'], 'burst_results', '-append')
        
    end
end
