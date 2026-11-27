function H = read_hrvlogger_hr(file, tz)
%READ_HRVLOGGER_HR  Heart rate computed by the chest strap, from an HRV Logger HR export.
%
%   H = read_hrvlogger_hr(file, tz)
%
%   Columns of the file: date, timestamp, heart rate. The strap sends about one
%   value per second; the app writes ~2 rows per second (repeats). Rows with the
%   same clock second are averaged, giving a 1 Hz series.
%   The time stamps say "+0000" but are local time: they are read in time zone tz
%   (e.g. 'Europe/Rome') so that they can be compared with the FIT files (UTC).
%
%   H  timetable with variable hr [bpm], row times in zone tz, one row per second.

txt = fileread(file);
L = regexp(txt, '\r\n|\r|\n', 'split');
L = L(2:end);
L = L(~cellfun(@(x) isempty(strtrim(x)), L));
C = textscan(strjoin(L, newline), '%s %s %f', 'Delimiter', ',', 'Whitespace', '');
stamp = regexprep(strtrim(C{1}), '\s*[+-]\d{4}$', '');
hr = C{3};
ok = ~isnan(hr) & hr > 0;
t = datetime(stamp(ok), 'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'TimeZone', tz);
H = timetable(t, hr(ok), 'VariableNames', {'hr'});
H = retime(H, 'secondly', 'mean');                      % 1 Hz, repeats averaged
end
