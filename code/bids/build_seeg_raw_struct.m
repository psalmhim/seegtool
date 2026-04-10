function raw = build_seeg_raw_struct(data, electrodes, channels)
% BUILD_SEEG_RAW_STRUCT Convert BIDS-loaded data to internal pipeline struct.
%
%   raw = build_seeg_raw_struct(data, electrodes, channels)
%
%   Inputs:
%       data       - struct with .data (channels x samples), .fs, .label
%       electrodes - struct from load_bids_electrodes
%       channels   - struct from load_bids_channels
%
%   Output:
%       raw - struct compatible with run_seeg_pipeline

    raw.data = data.data;
    raw.fs = data.fs;
    raw.label = data.label;
    raw.electrodes = electrodes;
    raw.channels = channels;
end
