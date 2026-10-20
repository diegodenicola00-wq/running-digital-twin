function info = fit_file_info(fname)
%FIT_FILE_INFO Read file type and creation time from the file_id message.
%
%   info = fit_file_info(fname)
%
% Reads only the first few records of a binary FIT file (fast), so that
% thousands of files can be screened before the slow FIT->CSV conversion.
%
%   info.type     FIT file type: 4 = activity, 32 = monitoring, 49 = sleep, ...
%                 NaN if the file could not be read
%   info.created  time_created (datetime, UTC), NaT if missing
%
% FIT format: header (12 or 14 bytes), then records. Each record starts with
% a 1-byte header: definition messages describe the layout of the following
% data messages. file_id (global message 0) is normally the first data message.

    info = struct('type', NaN, 'created', datetime(NaN, NaN, NaN, 'TimeZone', 'UTC'));
    FIT_EPOCH = 631065600;   % 1989-12-31 00:00 UTC in Unix seconds

    fid = fopen(fname, 'r', 'ieee-le');
    if fid < 0, return; end
    cleaner = onCleanup(@() fclose(fid));

    hsize = fread(fid, 1, 'uint8');
    if isempty(hsize) || hsize < 12, return; end
    fseek(fid, hsize, 'bof');

    defs = cell(1, 16);                       % one definition per local type
    for n = 1:20
        h = fread(fid, 1, 'uint8');
        if isempty(h), return; end

        if bitand(h, 128)                     % compressed-timestamp data header
            lt = bitand(bitshift(h, -5), 3);
            isDef = false;
        else
            lt = bitand(h, 15);
            isDef = bitand(h, 64) > 0;
        end

        if isDef
            fread(fid, 1, 'uint8');           % reserved
            arch = fread(fid, 1, 'uint8');    % 0 little endian, 1 big endian
            if arch == 1
                gnum = fread(fid, 1, 'uint16', 'ieee-be');
            else
                gnum = fread(fid, 1, 'uint16');
            end
            nf = fread(fid, 1, 'uint8');
            f  = reshape(fread(fid, 3*nf, 'uint8'), 3, [])';   % [num size baseType]
            dev = 0;
            if bitand(h, 32)                  % developer fields
                nd  = fread(fid, 1, 'uint8');
                df  = reshape(fread(fid, 3*nd, 'uint8'), 3, [])';
                dev = sum(df(:, 2));
            end
            defs{lt+1} = struct('gnum', gnum, 'arch', arch, 'f', f, 'dev', dev);

        else
            d = defs{lt+1};
            if isempty(d), return; end
            if d.gnum == 0                    % file_id
                for k = 1:size(d.f, 1)
                    num = d.f(k, 1);  sz = d.f(k, 2);
                    if num == 0 && sz == 1
                        info.type = fread(fid, 1, 'uint8');
                    elseif num == 4 && sz == 4
                        if d.arch == 1
                            t = fread(fid, 1, 'uint32', 'ieee-be');
                        else
                            t = fread(fid, 1, 'uint32');
                        end
                        info.created = datetime(t + FIT_EPOCH, ...
                            'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
                    else
                        fseek(fid, sz, 'cof');
                    end
                end
                return
            end
            fseek(fid, sum(d.f(:, 2)) + d.dev, 'cof');   % skip other messages
        end
    end
end
