function export_figures(fig_handles, output_dir, format, dpi)
% EXPORT_FIGURES Export figure handles to image files.
%
%   export_figures(fig_handles, output_dir, format, dpi)
%
%   Inputs:
%       fig_handles - cell array of figure handles (or single handle)
%       output_dir  - directory to save figures
%       format      - file format: 'pdf', 'png', 'svg' (default: 'pdf')
%       dpi         - resolution in dots per inch (default: 300)

    if nargin < 3 || isempty(format)
        format = 'pdf';
    end
    if nargin < 4 || isempty(dpi)
        dpi = 300;
    end

    if ~iscell(fig_handles)
        fig_handles = {fig_handles};
    end

    if ~isfolder(output_dir)
        mkdir(output_dir);
    end

    for i = 1:numel(fig_handles)
        fig = fig_handles{i};
        if ~isvalid(fig)
            warning('export_figures:invalidHandle', 'Figure handle %d is not valid, skipping.', i);
            continue;
        end

        fig_name = get(fig, 'Name');
        if isempty(fig_name)
            fig_name = sprintf('figure_%03d', i);
        end
        fig_name = regexprep(fig_name, '[^a-zA-Z0-9_\-]', '_');

        filepath = fullfile(output_dir, [fig_name, '.', format]);

        switch lower(format)
            case 'pdf'
                exportgraphics(fig, filepath, 'ContentType', 'image');
            case 'png'
                exportgraphics(fig, filepath, 'Resolution', dpi);
            case 'svg'
                saveas(fig, filepath, 'svg');
            otherwise
                error('export_figures:unsupportedFormat', 'Unsupported format: %s', format);
        end
        fprintf('Exported: %s\n', filepath);
    end
end
