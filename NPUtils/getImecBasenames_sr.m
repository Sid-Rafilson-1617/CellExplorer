function basenames = getImecBasenames_sr(basepath)
% Return unique basenames in basepath matching *_imecX (files only)
%
% Usage:
%   basenames = getImecBasenames_sr(basepath)

    if nargin < 1 || isempty(basepath)
        basepath = pwd;
    end

    % List all *files* in the basepath
    d = dir(basepath);
    d = d(~[d.isdir]);  % keep only files

    % Get raw filenames (with extensions)
    fnames = {d.name};

    % Strip extensions to get basenames
    names_noext = regexprep(fnames, '\.[^.]+$','');

    % Keep only basenames ending with '_imec<number>'
    expr = '_imec\d+$';
    keep = cellfun(@(x) ~isempty(regexp(x, expr, 'once')), names_noext);

    % Unique basenames
    basenames = unique(names_noext(keep));
end
