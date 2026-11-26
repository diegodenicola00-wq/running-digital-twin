function N = read_hrv_notes(file)
%READ_HRV_NOTES  Read the context notes of the morning HRV (data/raw/hrv/notes.csv).
%
%   N = read_hrv_notes(file)
%
%   File format (one row only on particular days; several rows per day allowed):
%       date,tag,note
%       2026-11-26,sleep_bad,slept 5 hours
%   Tags: sleep_bad, alcohol, sick, stress, travel, legs (free text is allowed).
%   The note may contain spaces but no commas.
%
%   N  table with one row per day: day (datetime), tag (string, tags joined by
%      ";"), note (string, notes joined by "; "). Empty table if the file is
%      missing or has no rows.

N = table(datetime.empty(0,1), strings(0,1), strings(0,1), 'VariableNames', {'day','tag','note'});
if ~isfile(file), return; end

fid = fopen(file, 'r');
c = onCleanup(@() fclose(fid));
fgetl(fid);                                            % header
C = textscan(fid, '%s %s %s', 'Delimiter', ',', 'Whitespace', '', 'EndOfLine', '\r\n');
d = strtrim(C{1});  tg = lower(strtrim(C{2}));  nt = strtrim(C{3});
ok = ~cellfun(@isempty, d);
d = d(ok);  tg = tg(ok);  nt = nt(ok);
if isempty(d), return; end

day = datetime(d, 'InputFormat', 'yyyy-MM-dd');
[u, ~, g] = unique(day);
N = table(u, strings(numel(u),1), strings(numel(u),1), 'VariableNames', {'day','tag','note'});
for i = 1:numel(u)
    N.tag(i)  = strjoin(string(tg(g == i)), ';');
    N.note(i) = strjoin(string(nt(g == i)), '; ');
end
end
