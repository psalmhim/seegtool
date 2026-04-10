function export_figure(fig, filepath, s, varargin)
% EXPORT_FIGURE Export figure to publication-quality PDF and PNG.
%
%   export_figure(fig, filepath)
%   export_figure(fig, filepath, style, 'width', 'single')
%
%   Options:
%       'width'   - 'single' (89mm), 'onehalf' (134mm), 'double' (183mm)
%       'height'  - height in inches (auto if omitted)
%       'formats' - cell array of formats (default: {'pdf', 'png'})

    if nargin < 3 || isempty(s)
        s = nature_style();
    end

    p = inputParser;
    addParameter(p, 'width', 'single');
    addParameter(p, 'height', []);
    addParameter(p, 'formats', s.export.formats);
    parse(p, varargin{:});

    % Set width
    switch lower(p.Results.width)
        case 'single'
            w = s.figure.single_col;
        case 'onehalf'
            w = s.figure.one_half_col;
        case 'double'
            w = s.figure.double_col;
        otherwise
            w = s.figure.single_col;
    end

    % Set height
    if isempty(p.Results.height)
        % Maintain current aspect ratio
        fig_pos = get(fig, 'Position');
        aspect = fig_pos(4) / fig_pos(3);
        h = min(w * aspect, s.figure.max_height);
    else
        h = p.Results.height;
    end

    % Configure figure for export
    set(fig, 'PaperUnits', 'inches');
    set(fig, 'PaperSize', [w, h]);
    set(fig, 'PaperPosition', [0, 0, w, h]);
    set(fig, 'Renderer', s.figure.renderer);
    set(fig, 'InvertHardcopy', 'off');

    % Ensure output directory exists
    [out_dir, ~, ~] = fileparts(filepath);
    if ~isempty(out_dir) && ~isfolder(out_dir)
        mkdir(out_dir);
    end

    % Export
    formats = p.Results.formats;
    for i = 1:numel(formats)
        fmt = lower(formats{i});
        switch fmt
            case 'pdf'
                out = [filepath '.pdf'];
                if exist('exportgraphics', 'file')
                    exportgraphics(fig, out, 'ContentType', 'image', ...
                        'Resolution', s.export.pdf_dpi);
                else
                    print(fig, out, '-dpdf', '-painters', ...
                        sprintf('-r%d', s.export.pdf_dpi));
                end
            case 'png'
                out = [filepath '.png'];
                if exist('exportgraphics', 'file')
                    exportgraphics(fig, out, 'Resolution', s.export.dpi);
                else
                    print(fig, out, '-dpng', sprintf('-r%d', s.export.dpi));
                end
            case 'eps'
                out = [filepath '.eps'];
                print(fig, out, '-depsc2', '-painters');
        end
    end
end
