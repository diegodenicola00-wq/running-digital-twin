function nConverted = convert_fit_to_csv(cfg, overwrite)
%CONVERT_FIT_TO_CSV Convert the relevant .fit files in cfg.paths.fit to CSV
% using Garmin's FitCSVTool. Already-converted files are skipped.
%
%   n = convert_fit_to_csv(cfg)          skip existing CSVs
%   n = convert_fit_to_csv(cfg, true)    reconvert everything
%
% A Garmin account export contains tens of thousands of FIT files (daily
% monitoring, sleep, HRV, ...). Converting all of them would take hours, so
% every file is first screened by reading only its header (fit_file_info):
% only ACTIVITY files (type 4) created on/after cfg.dates.dataStart are kept.

    if nargin < 2, overwrite = false; end
    assert(isfile(cfg.paths.fitcsvtool), ...
        'FitCSVTool.jar not found in tools/. Download it from github.com/garmin/fit-sdk-tools/releases');

    % search subfolders too: Garmin zips extract into nested folders
    files = dir(fullfile(cfg.paths.fit, '**', '*.fit'));
    if isempty(files)
        warning('No .fit files in %s', cfg.paths.fit);
        nConverted = 0;
        return
    end

    % --- 1. screen headers ------------------------------------------------
    t0 = cfg.dates.dataStart;
    t0.TimeZone = 'UTC';
    keep  = false(numel(files), 1);
    nAct  = 0;
    fprintf('Screening %d FIT files...\n', numel(files));
    for i = 1:numel(files)
        info = fit_file_info(fullfile(files(i).folder, files(i).name));
        if info.type == 4
            nAct = nAct + 1;
            keep(i) = isnat(info.created) || info.created >= t0;
        end
        if mod(i, 2000) == 0
            fprintf('  %d / %d\n', i, numel(files));
        end
    end
    files = files(keep);
    fprintf('%d activity files in total, %d from %s onwards.\n', ...
        nAct, numel(files), datestr(cfg.dates.dataStart, 'dd-mmm-yyyy'));

    % --- 2. convert ----------------------------------------------------------
    javaExe = find_java();
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
        if mod(i, 25) == 0
            fprintf('  converted %d / %d\n', i, numel(files));
        end
    end
    fprintf('%d FIT files converted (%d selected).\n', nConverted, numel(files));
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
