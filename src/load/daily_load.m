function D = daily_load(A, dayStart, dayEnd)
%DAILY_LOAD Aggregate per-activity load on a continuous daily grid.
%
%   D = daily_load(A, dayStart, dayEnd)
%
% A is the activity table built by main_01_pipeline (columns day, trimp,
% dist_km). Days without training get w = 0: for the dynamic model a rest
% day is an input of zero, not missing data.
%
% D is a timetable with: w (daily TRIMP), nRuns, km

    day = (dateshift(dayStart, 'start', 'day') : caldays(1) : ...
           dateshift(dayEnd,   'start', 'day'))';
    n = numel(day);
    w = zeros(n, 1);  nRuns = zeros(n, 1);  km = zeros(n, 1);

    for i = 1:height(A)
        k = days(A.day(i) - day(1)) + 1;
        if k < 1 || k > n, continue; end
        w(k)     = w(k) + A.trimp(i);
        nRuns(k) = nRuns(k) + 1;
        km(k)    = km(k) + A.dist_km(i);
    end

    D = timetable(day, w, nRuns, km);
end
