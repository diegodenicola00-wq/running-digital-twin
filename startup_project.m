% STARTUP_PROJECT  Run once per MATLAB session from the repo root.
root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root, 'src')));
addpath(root);

cfg = config();
dirs = {cfg.paths.fit, cfg.paths.csv, cfg.paths.processed, cfg.paths.results};
for i = 1:numel(dirs)
    if ~isfolder(dirs{i}), mkdir(dirs{i}); end
end
fprintf('Project ready: %s\n', root);
