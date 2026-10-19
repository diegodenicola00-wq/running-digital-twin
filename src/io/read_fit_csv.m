function act = read_fit_csv(csvFile)
%READ_FIT_CSV Parse a CSV produced by Garmin FitCSVTool into a MATLAB struct.
%
%   act = read_fit_csv(csvFile)
%
% FitCSVTool writes one row per FIT message in "long" format:
%   Type, Local Number, Message, Field 1, Value 1, Units 1, Field 2, ...
% Only the "Data" rows of the 'record' (1 Hz samples) and 'session'
% (activity summary) messages are needed here.
%
% Output
%   act.file      source file name
%   act.sport     sport as written in the session message ("running" or 1)
%   act.subSport  sub-sport (e.g. treadmill)
%   act.rec       table, one row per record sample:
%                 t (datetime, UTC), hr [bpm], speed [m/s], dist [m],
%                 alt [m], cad [rpm], power [W]

    FIT_EPOCH = 631065600;   % 1989-12-31 00:00 UTC, in Unix seconds

    recFields = {'timestamp','heart_rate','enhanced_speed','speed', ...
                 'distance','enhanced_altitude','altitude','cadence','power'};

    lines = splitlines(fileread(csvFile));
    lines = lines(startsWith(lines, 'Data,'));

    R  = nan(numel(lines), numel(recFields));
    nr = 0;
    act.sport    = "";
    act.subSport = "";

    for i = 1:numel(lines)
        % array values are quoted ("12|13") but never contain commas.
        % CollapseDelimiters must be false: empty units produce ",," and
        % collapsing them would shift every field/value/unit triplet.
        c   = strsplit(strrep(lines{i}, '"', ''), ',', 'CollapseDelimiters', false);
        msg = c{3};

        if strcmp(msg, 'record')
            nr = nr + 1;
            for j = 4:3:numel(c)-1
                k = find(strcmp(recFields, c{j}), 1);
                if ~isempty(k)
                    R(nr, k) = str2double(c{j+1});
                end
            end

        elseif strcmp(msg, 'session')
            for j = 4:3:numel(c)-1
                switch c{j}
                    case 'sport',     act.sport    = string(c{j+1});
                    case 'sub_sport', act.subSport = string(c{j+1});
                end
            end
        end
    end

    R = R(1:nr, :);
    R = R(~isnan(R(:,1)), :);                 % drop samples without timestamp
    col = @(name) R(:, strcmp(recFields, name));

    % prefer the "enhanced" fields (higher resolution), fall back otherwise
    speed = col('enhanced_speed');
    alt   = col('enhanced_altitude');
    s2 = col('speed');     speed(isnan(speed)) = s2(isnan(speed));
    a2 = col('altitude');  alt(isnan(alt))     = a2(isnan(alt));

    t = datetime(col('timestamp') + FIT_EPOCH, ...
                 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');

    act.rec = table(t, col('heart_rate'), speed, col('distance'), alt, ...
                    col('cadence'), col('power'), ...
        'VariableNames', {'t','hr','speed','dist','alt','cad','power'});

    [~, name, ext] = fileparts(csvFile);
    act.file = string([name ext]);
end
