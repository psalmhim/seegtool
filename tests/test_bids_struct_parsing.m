classdef test_bids_struct_parsing < matlab.unittest.TestCase
% TEST_BIDS_STRUCT_PARSING Unit tests for BIDS loading and parsing functions.

    properties
        tmp_dir
        ieeg_dir
    end

    methods (TestMethodSetup)
        function setup_temp_bids(testCase)
            testCase.tmp_dir = fullfile(tempdir, ['bids_test_' char(datetime('now','Format','yyyyMMddHHmmss'))]);
            testCase.ieeg_dir = fullfile(testCase.tmp_dir, 'sub-01', 'ses-01', 'ieeg');
            mkdir(testCase.ieeg_dir);

            % Create electrodes.tsv
            fid = fopen(fullfile(testCase.ieeg_dir, 'sub-01_ses-01_electrodes.tsv'), 'w');
            fprintf(fid, 'name\tx\ty\tz\n');
            fprintf(fid, 'LA1\t-25.0\t-5.0\t-20.0\n');
            fprintf(fid, 'LA2\t-24.0\t-4.0\t-18.0\n');
            fprintf(fid, 'RH1\t28.0\t-15.0\t-12.0\n');
            fprintf(fid, 'RH2\t27.0\t-14.0\t-10.0\n');
            fclose(fid);

            % Create channels.tsv
            fid = fopen(fullfile(testCase.ieeg_dir, 'sub-01_ses-01_channels.tsv'), 'w');
            fprintf(fid, 'name\ttype\tstatus\n');
            fprintf(fid, 'LA1\tSEEG\tgood\n');
            fprintf(fid, 'LA2\tSEEG\tbad\n');
            fprintf(fid, 'RH1\tSEEG\tgood\n');
            fprintf(fid, 'RH2\tSEEG\tgood\n');
            fclose(fid);

            % Create events.tsv
            fid = fopen(fullfile(testCase.ieeg_dir, 'sub-01_ses-01_events.tsv'), 'w');
            fprintf(fid, 'onset\tduration\ttrial_type\n');
            fprintf(fid, '1.500\t0.500\tstim_A\n');
            fprintf(fid, '4.200\t0.500\tstim_B\n');
            fprintf(fid, '7.800\t0.500\tstim_A\n');
            fclose(fid);
        end
    end

    methods (TestMethodTeardown)
        function cleanup(testCase)
            if isfolder(testCase.tmp_dir)
                rmdir(testCase.tmp_dir, 's');
            end
        end
    end

    methods (Test)

        function test_load_electrodes(testCase)
            file = fullfile(testCase.ieeg_dir, 'sub-01_ses-01_electrodes.tsv');
            elec = load_bids_electrodes(file);

            testCase.verifyEqual(numel(elec.label), 4);
            testCase.verifyEqual(elec.label{1}, 'LA1');
            testCase.verifyEqual(elec.x(1), -25.0, 'AbsTol', 0.01);
            testCase.verifyEqual(elec.z(3), -12.0, 'AbsTol', 0.01);
        end

        function test_load_channels(testCase)
            file = fullfile(testCase.ieeg_dir, 'sub-01_ses-01_channels.tsv');
            ch = load_bids_channels(file);

            testCase.verifyEqual(numel(ch.name), 4);
            testCase.verifyEqual(ch.status{2}, 'bad');
            testCase.verifyEqual(ch.type{1}, 'SEEG');
        end

        function test_load_events(testCase)
            file = fullfile(testCase.ieeg_dir, 'sub-01_ses-01_events.tsv');
            ev = load_bids_events(file, 1000);

            testCase.verifyEqual(numel(ev), 3);
            testCase.verifyEqual(ev(1).onset, 1.5, 'AbsTol', 0.001);
            testCase.verifyEqual(ev(1).condition, 'stim_A');
            testCase.verifyEqual(ev(1).sample, 1501);  % round(1.5*1000) + 1
            testCase.verifyEqual(ev(2).condition, 'stim_B');
        end

        function test_infer_electrode_roi(testCase)
            elec.label = {'LA1'; 'LA2'; 'RH1'; 'RH2'; 'LPF3'};
            roi = infer_electrode_roi_fields(elec);

            testCase.verifyEqual(roi.shaft_name{1}, 'LA');
            testCase.verifyEqual(roi.shaft_name{3}, 'RH');
            testCase.verifyEqual(roi.shaft_name{5}, 'LPF');
            testCase.verifyEqual(roi.contact_num(1), 1);
            testCase.verifyEqual(roi.contact_num(5), 3);
            testCase.verifyEqual(roi.hemisphere{1}, 'L');
            testCase.verifyEqual(roi.hemisphere{3}, 'R');
            testCase.verifyEqual(numel(roi.unique_shafts), 3);
        end

        function test_apply_channel_status(testCase)
            raw.data = randn(4, 100);
            raw.label = {'LA1', 'LA2', 'RH1', 'RH2'};
            raw.channels.name = {'LA1', 'LA2', 'RH1', 'RH2'};
            raw.channels.status = {'good', 'bad', 'good', 'good'};

            [clean, good_idx, bad] = apply_bids_channel_status(raw);

            testCase.verifyEqual(size(clean, 1), 3);
            testCase.verifyEqual(sum(good_idx), 3);
            testCase.verifyEqual(bad, {'LA2'});
        end

        function test_build_roi_groups_shaft(testCase)
            elec.label = {'LA1'; 'LA2'; 'LA3'; 'RH1'; 'RH2'};
            groups = build_roi_groups(elec, 'shaft');

            testCase.verifyEqual(numel(groups), 2);
            testCase.verifyEqual(groups(1).name, 'LA');
            testCase.verifyEqual(groups(1).n_channels, 3);
            testCase.verifyEqual(groups(2).name, 'RH');
            testCase.verifyEqual(groups(2).n_channels, 2);
        end

        function test_build_seeg_raw_struct(testCase)
            data.data = randn(4, 100);
            data.fs = 1000;
            data.label = {'A1','A2','B1','B2'};
            elec.label = data.label;
            elec.x = [1;2;3;4];
            elec.y = [5;6;7;8];
            elec.z = [9;10;11;12];
            ch.name = data.label;
            ch.type = {'SEEG','SEEG','SEEG','SEEG'};
            ch.status = {'good','good','good','good'};

            raw = build_seeg_raw_struct(data, elec, ch);

            testCase.verifyEqual(raw.fs, 1000);
            testCase.verifyEqual(size(raw.data), [4, 100]);
            testCase.verifyTrue(isfield(raw, 'electrodes'));
            testCase.verifyTrue(isfield(raw, 'channels'));
        end

        function test_map_electrodes_to_atlas(testCase)
            elec.label = {'LA1'; 'RH1'};
            elec.x = [-25; 28];
            elec.y = [-5; -15];
            elec.z = [-20; -12];

            atlas.coords = [-24, -4, -19; 27, -14, -11; 0, 0, 0];
            atlas.labels = {'Amygdala'; 'Hippocampus'; 'Unknown'};
            atlas.name = 'test_atlas';

            mapping = map_electrodes_to_atlas(elec, atlas);

            testCase.verifyEqual(mapping.region_label{1}, 'Amygdala');
            testCase.verifyEqual(mapping.region_label{2}, 'Hippocampus');
            testCase.verifyTrue(mapping.distance_mm(1) < 5);
            testCase.verifyEqual(mapping.atlas_name, 'test_atlas');
        end

    end
end
