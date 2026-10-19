function nConverted = convert_fit_to_csv(cfg, overwrite)
%CONVERT_FIT_TO_CSV Batch-convert every .fit in cfg.paths.fit to CSV
% using Garmin's FitCSVTool. Already-converted files are skipped.
%
%   n = convert_fit_to_csv(cfg)          skip existing CSVs
%   n = convert_fit_to_csv(cfg, true)    reconvert everything

    if nargin < 2, overwrite = false; end
    assert(isfile(cfg.paths.fitcsvtool), ...
        'FitCSVTool.jar not found in tools/. Download the Garmin FIT SDK.');

    files = dir(fullfile(cfg.paths.fit, '*.fit'));
    nConverted = 0;

    for i = 1:numel(files)
        in  = fullfile(files(i).folder, files(i).name);
        [~, name] = fileparts(files(i).name);
        out = fullfile(cfg.paths.csv, [name '.csv']);

        if isfile(out) && ~overwrite, continue; end

        cmd = sprintf('java -jar "%s" -b "%s" "%s"', cfg.paths.fitcsvtool, in, out);
        [status, msg] = system(cmd);
        if status ~= 0
            warning('Conversion failed for %s:\n%s', files(i).name, msg);
        else
            nConverted = nConverted + 1;
        end
    end
    fprintf('%d FIT files converted (%d total in folder).\n', nConverted, numel(files));
end
