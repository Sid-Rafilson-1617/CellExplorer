function burst_results = detect_ripple_bursts(ripples, params)
% Classify ripple events into clustered (bursts) and isolated (solo) events
%
% INPUTS:
%   ripples - buzcode-style structure with fields:
%       .peaks      - Nx1 vector of peak timestamps (seconds)
%       .timestamps - Nx2 matrix of [start end] timestamps (seconds)
%
%   params - structure with fields:
%       .max_inter_ripple_interval_ms - max IEI to be considered part of a burst (default: 180)
%       .min_ripples_in_burst         - minimum ripples to constitute a burst (default: 2)
%       .isolation_window_s           - time window for defining isolated events (default: 0.5)
%
% OUTPUT:
%   burst_results - structure with fields:
%       .solo_events  - structure with solo ripple data
%           .peaks      - peak times of solo ripples
%           .timestamps - [start end] for each solo ripple
%           .indices    - indices into original ripples.peaks
%
%       .burst_events - 1xN structure array (N = number of bursts) with:
%           .peaks       - peak times of all ripples in this burst
%           .timestamps  - [burst_onset burst_offset] (start of first ripple to end of last)
%           .indices     - indices into original ripples.peaks for this burst
%           .rippleCount - number of ripples in this burst

%% Input validation
if ~isfield(ripples, 'peaks') || ~isfield(ripples, 'timestamps')
    error('Input must be a buzcode-style structure with ''peaks'' and ''timestamps'' fields.');
end

peaks = ripples.peaks(:);  % ensure column vector
timestamps = ripples.timestamps;
n_ripples = length(peaks);

% Handle empty input
if n_ripples == 0
    burst_results.solo_events = struct('peaks', [], 'timestamps', [], 'indices', []);
    burst_results.burst_events = struct('peaks', {}, 'timestamps', {}, 'indices', {}, 'rippleCount', {});
    return;
end

% Validate dimensions
if size(timestamps, 1) ~= n_ripples || size(timestamps, 2) ~= 2
    error('ripples.timestamps must be Nx2 where N = length(ripples.peaks)');
end

%% Set default parameters
if ~isfield(params, 'max_inter_ripple_interval_ms')
    params.max_inter_ripple_interval_ms = 180;
end
if ~isfield(params, 'min_ripples_in_burst')
    params.min_ripples_in_burst = 2;
end
if ~isfield(params, 'isolation_window_s')
    params.isolation_window_s = 0.5;
end

%% Sort ripples by peak time (keep track of original indices)
[sorted_peaks, sort_order] = sort(peaks);
sorted_timestamps = timestamps(sort_order, :);

% Create reverse mapping: original_idx = sort_order(sorted_idx)
% To find sorted position of original index i: sorted_position(i) gives sorted index
[~, sorted_position] = sort(sort_order);

%% Detect bursts using inter-event intervals of peak times
ieis_ms = diff(sorted_peaks) * 1000;

% is_in_burst_sequence(i) = true if ripple i has short IEI to ripple i+1
is_in_burst_sequence = [ieis_ms < params.max_inter_ripple_interval_ms; false];

% Find burst boundaries using state transitions
burst_starts_sorted = find(diff([false; is_in_burst_sequence]) == 1);
burst_ends_sorted = find(diff([is_in_burst_sequence; false]) == -1);

%% Process each burst
is_burst_ripple_sorted = false(n_ripples, 1);
burst_events = struct('peaks', {}, 'timestamps', {}, 'indices', {}, 'rippleCount', {});

for b = 1:length(burst_starts_sorted)
    start_idx = burst_starts_sorted(b);
    end_idx = burst_ends_sorted(b) + 1;  % +1 to include last ripple in burst
    
    % Bounds check
    if end_idx > n_ripples
        end_idx = n_ripples;
    end
    
    num_ripples_in_burst = end_idx - start_idx + 1;
    
    if num_ripples_in_burst >= params.min_ripples_in_burst
        burst_indices_sorted = (start_idx:end_idx)';
        
        % Extract burst data
        burst_peaks = sorted_peaks(burst_indices_sorted);
        burst_ts = sorted_timestamps(burst_indices_sorted, :);
        original_indices = sort_order(burst_indices_sorted);
        
        % Burst spans from start of first ripple to end of last ripple
        burst_onset = burst_ts(1, 1);
        burst_offset = burst_ts(end, 2);
        
        % Validate
        is_invalid = isempty(burst_onset) || isempty(burst_offset) || ...
                     any(isnan(burst_peaks)) || any(isinf(burst_peaks)) || ...
                     any(isnan(burst_ts(:))) || any(isinf(burst_ts(:))) || ...
                     burst_onset >= burst_offset;
        
        if is_invalid
            continue;
        end
        
        % Mark as burst ripples
        is_burst_ripple_sorted(burst_indices_sorted) = true;
        
        % Store burst
        new_idx = length(burst_events) + 1;
        burst_events(new_idx).peaks = burst_peaks;
        burst_events(new_idx).timestamps = [burst_onset, burst_offset];
        burst_events(new_idx).indices = original_indices;
        burst_events(new_idx).rippleCount = num_ripples_in_burst;
    end
end

%% Identify isolated (solo) events
% A ripple is isolated if no other ripple occurs within isolation_window_s
iso_win_s = params.isolation_window_s;
is_isolated_sorted = true(n_ripples, 1);

for r = 1:n_ripples
    % Check previous ripple
    if r > 1 && (sorted_peaks(r) - sorted_peaks(r-1)) < iso_win_s
        is_isolated_sorted(r) = false;
    end
    % Check next ripple
    if r < n_ripples && (sorted_peaks(r+1) - sorted_peaks(r)) < iso_win_s
        is_isolated_sorted(r) = false;
    end
end

% Solo = isolated AND not part of a burst
is_solo_sorted = is_isolated_sorted & ~is_burst_ripple_sorted;

%% Extract solo events
solo_indices_sorted = find(is_solo_sorted);
solo_peaks = sorted_peaks(solo_indices_sorted);
solo_timestamps = sorted_timestamps(solo_indices_sorted, :);
solo_original_indices = sort_order(solo_indices_sorted);

% Validate solo events
if ~isempty(solo_peaks)
    valid_solo = ~any(isnan([solo_peaks, solo_timestamps]), 2) & ...
                 ~any(isinf([solo_peaks, solo_timestamps]), 2) & ...
                 (solo_timestamps(:, 1) < solo_timestamps(:, 2));
    
    solo_peaks = solo_peaks(valid_solo);
    solo_timestamps = solo_timestamps(valid_solo, :);
    solo_original_indices = solo_original_indices(valid_solo);
end

%% Build output structure
solo_events = struct();
solo_events.peaks = solo_peaks;
solo_events.timestamps = solo_timestamps;
solo_events.indices = solo_original_indices;

burst_results = struct();
burst_results.solo_events = solo_events;
burst_results.burst_events = burst_events;

end