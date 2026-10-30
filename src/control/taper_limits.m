function lim = taper_limits(dHist, wHist, kmHist, P)
%TAPER_LIMITS Session and weekly limits of the taper plan from recent training.
%
%   lim = taper_limits(dHist, wHist, kmHist, P)
%
% The plan must not ask for more than the athlete has recently done:
%   cap(j)   max load of session type j (weekday P.runDays(j)) in the last
%            P.capWeeks weeks
%   ref(j)   usual (median) load of the same session
%   rate(j)  median TRIMP per km of the same session (to convert TRIMP to km)
%   weekCap  max weekly load (Mon-Sun) of the last P.weekCapWeeks weeks
%
% dHist, wHist, kmHist: days, daily TRIMP and km of the history (column vectors).

    tEnd = dHist(end);
    recent = dHist > tEnd - caldays(7*P.capWeeks) & wHist > 0;
    nj = numel(P.runDays);
    lim.cap = nan(1, nj);  lim.ref = lim.cap;  lim.rate = lim.cap;  lim.n = zeros(1, nj);
    for j = 1:nj
        m = recent & weekday(dHist) == P.runDays(j);
        if ~any(m)
            error('taper_limits: no %s session (weekday %d) in the last %d weeks.', ...
                P.sessionName(j), P.runDays(j), P.capWeeks);
        end
        lim.cap(j)  = max(wHist(m));
        lim.ref(j)  = median(wHist(m));
        lim.rate(j) = median(wHist(m) ./ max(kmHist(m), 0.1));
        lim.n(j)    = nnz(m);
    end

    % weekly cap: complete Mon-Sun weeks only
    wk  = week_id(dHist);
    win = dHist > tEnd - caldays(7*P.weekCapWeeks);
    ids = unique(wk(win));
    ids = ids(arrayfun(@(i) nnz(wk == i) == 7, ids));    % complete weeks
    tot = arrayfun(@(i) sum(wHist(wk == i)), ids);
    lim.weekCap = max(tot);
end

function id = week_id(d)
% Monday-based week number (3 Jan 2000 was a Monday); weekday() is locale-free.
    id = floor(days(d - datetime(2000, 1, 3)) / 7);
end
