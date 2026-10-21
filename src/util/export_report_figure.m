function export_report_figure(fig, name, cfg)
%EXPORT_REPORT_FIGURE Save a figure as vector PDF in report/figures for LaTeX.
%
%   export_report_figure(fig, name, cfg)
%
% Figures in the report always come from the scripts, never from screenshots:
% re-running the scripts updates the report. A light theme is forced so that
% the PDF is readable on paper whatever MATLAB theme is in use.

    outDir = fullfile(cfg.paths.root, 'report', 'figures');
    if ~isfolder(outDir), mkdir(outDir); end
    try
        theme(fig, 'light');            % R2025a+: dark desktop theme -> light figure
    catch
    end
    exportgraphics(fig, fullfile(outDir, [name '.pdf']), 'ContentType', 'vector');
end
