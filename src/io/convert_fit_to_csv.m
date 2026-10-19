function nConverted = convert_fit_to_csv(cfg, overwrite)
%CONVERT_FIT_TO_CSV Batch-convert every .fit in cfg.paths.fit to CSV
% using Garmin's FitCSVTool. Already-converted files are skipped.
%
%   n = convert_fit_to_csv(cfg)          skip existing CSVs
%   n = convert_fit_to_csv(cfg, true)    reconvert everything

    if nargin < 2, overwrite = false; end
    assert(isfile(cfg.paths.fitcsvtool), ...
        'FitCSVTool.jar not found in tools/. Download it from github.com/garmin/fit-sdk-tools/releases');

    javaExe = find_java();
    files = dir(fullfile(cfg.paths.fit, '*.fit'));
    if isempty(files)
        warning('No .fit files in %s', cfg.paths.fit);
    end
    nConverted = 0;

    for i = 1:numel(files)
        in  = fullfile(files(i).folder, files(i).name);
        [~, name] = fileparts(files(i).name);
        out = fullfile(cfg.paths.csv, [name '.csv']);

        if isfile(out) && ~overwrite, continue; end

        cmd = sprintf('"%s" -jar "%s" -b "%s" "%s"', ...
                      javaExe, cfg.paths.fitcsvtool, in, out);
        [status, msg] = system(cmd);
        if status ~= 0 || ~isfile(out)
            warning('Conversion failed for %s:\n%s', files(i).name, msg);
        else
            nConverted = nConverted + 1;
        end
    end
    fprintf('%d FIT files converted (%d total in folder).\n', nConverted, numel(files));
end

function javaExe = find_java()
%FIND_JAVA Use the system Java if available, otherwise the one bundled with MATLAB.
    [status, ~] = system('java -version');
    if status == 0
        javaExe = 'java';
        return
    end
    root = fullfile(matlabroot, 'sys', 'java', 'jre');
    c = dir(fullfile(root, '**', 'bin', 'java.exe'));   % Windows
    if isempty(c)
        c = dir(fullfile(root, '**', 'bin', 'java'));   % macOS / Linux
    end
    assert(~isempty(c), ['Java not found. Install a Java runtime ', ...
        '(e.g. adoptium.net) and restart MATLAB.']);
    javaExe = fullfile(c(1).folder, c(1).name);
    fprintf('Using MATLAB''s bundled Java: %s\n', javaExe);
end
