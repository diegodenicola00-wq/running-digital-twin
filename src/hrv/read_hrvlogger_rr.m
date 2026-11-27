function S = read_hrvlogger_rr(file)
%READ_HRVLOGGER_RR  Read an HRV Logger RR export and remove the repeated beats.
%
%   S = read_hrvlogger_rr(file)
%
%   The HRV Logger file has the columns: date, rr, since start.
%   With the Garmin HRM 600 every beat is written 2-3 times: the strap sends
%   about one Bluetooth packet per second and, at a resting HR of ~45 bpm, a
%   packet often repeats the last RR interval. Check of 23 Nov 2026: 583 rows sum
%   to 776 s of beats in a 301 s recording; after removing repeats, 228 beats
%   sum to 297 s. The "since start" column counts the repeats, so it is not used.
%   Rule: an RR value equal to the previous one is a repeat. (A true beat equal
%   to the previous one to the millisecond is rare and its loss does not change
%   rMSSD: the difference would be 0 anyway, only the count of pairs changes.)
%
%   Use it for RESTING recordings only: during running (~2.5 beats/s) the app
%   keeps at most 2 RR per packet, so beats are missing, and two true
%   consecutive beats with the same RR are common (see main_09_validation).
%
%   The time stamps say "+0000" but are local time: the zone is ignored.
%   Latitude/longitude are in the Features file, not here, and are never read.
%
%   S.start   datetime of the first beat (local)
%   S.rr      [ms] RR intervals without repeats (column)
%   S.t       [s]  time of each beat from the start (cumulative sum of rr)
%   S.nRaw    number of rows in the file
%   S.wall    [s]  wall-clock span of the file (last minus first time stamp)

% Line endings: the morning exports use LF, the workout exports use CR only
% (old Mac style), so the file is read whole and split on any line break.
txt = fileread(file);
L = regexp(txt, '\r\n|\r|\n', 'split');
L = L(2:end);                                           % drop the header
L = L(~cellfun(@(x) isempty(strtrim(x)), L));
C = textscan(strjoin(L, newline), '%s %f %f', 'Delimiter', ',', 'Whitespace', '');
stamp = strtrim(C{1});  rr = C{2};
ok = ~isnan(rr) & ~cellfun(@isempty, stamp);
stamp = stamp(ok);  rr = rr(ok);
if isempty(rr), error('No RR data in %s', file); end

stamp = regexprep(stamp, '\s*[+-]\d{4}$', '');          % drop the (wrong) zone
tt = datetime(stamp, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');

keep = [true; diff(rr) ~= 0];                           % repeated value = repeat
S.start = tt(1);
S.rr    = rr(keep);
S.t     = cumsum(S.rr) / 1000;
S.nRaw  = numel(rr);
S.wall  = seconds(tt(end) - tt(1));
end
