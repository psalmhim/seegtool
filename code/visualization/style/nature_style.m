function s = nature_style()
% NATURE_STYLE Return publication-quality style configuration for Nature journals.
%
%   s = nature_style()
%
%   Nature figure specifications:
%       Single column: 89 mm (3.50 in)
%       Double column: 183 mm (7.20 in)
%       Max height: 247 mm (9.72 in)
%       Font: Helvetica/Arial, 5-7 pt
%       Resolution: 300 DPI minimum, 600 DPI recommended

    %% Figure dimensions (inches)
    s.figure.single_col = 3.50;
    s.figure.one_half_col = 5.35;
    s.figure.double_col = 7.20;
    s.figure.max_height = 9.72;
    s.figure.background = [1 1 1];
    s.figure.renderer = 'painters';

    %% Typography
    s.font.family = 'Helvetica';
    s.font.axis_label = 7;
    s.font.tick_label = 6;
    s.font.title = 8;
    s.font.panel_label = 10;
    s.font.legend = 6;
    s.font.colorbar = 6;
    s.font.sgtitle = 9;
    s.font.annotation = 6;

    %% Lines
    s.line.data = 0.75;
    s.line.mean = 1.25;
    s.line.reference = 0.5;
    s.line.axis = 0.5;
    s.line.tick_dir = 'out';
    s.line.tick_length = [0.015 0.015];

    %% Markers
    s.marker.size = 4;
    s.marker.onset = 5;
    s.marker.endpoint = 4;
    s.marker.significance = 2;

    %% Colors — Wong (2011) colorblind-safe palette
    s.colors.palette = [
        0.000, 0.447, 0.741;   % blue
        0.843, 0.373, 0.000;   % vermillion
        0.000, 0.620, 0.451;   % bluish green
        0.800, 0.475, 0.655;   % reddish purple
        0.902, 0.624, 0.000;   % orange
        0.337, 0.706, 0.914;   % sky blue
        0.941, 0.894, 0.259;   % yellow
        0.350, 0.350, 0.350;   % dark gray
    ];

    s.colors.black = [0.15 0.15 0.15];
    s.colors.gray = [0.50 0.50 0.50];
    s.colors.light_gray = [0.80 0.80 0.80];
    s.colors.white = [1 1 1];

    s.colors.significance = [0.84 0.15 0.15];
    s.colors.nonsig = [0.65 0.65 0.65];
    s.colors.baseline_bg = [0.95 0.95 0.95];
    s.colors.sig_shading = [1.00 0.85 0.85];

    s.colors.sem_alpha = 0.18;
    s.colors.ci_alpha = 0.15;
    s.colors.tube_alpha = 0.12;

    %% Significance thresholds
    s.sig.alpha = 0.05;
    s.sig.thresholds = [0.05 0.01 0.001];
    s.sig.labels = {'*', '**', '***'};
    s.sig.bar_offset = 0.03;

    %% Export
    s.export.formats = {'pdf', 'png'};
    s.export.dpi = 600;
    s.export.pdf_dpi = 300;
end
