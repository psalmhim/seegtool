seeg_population_dynamics_project/
│
├── README.md
├── LICENSE
├── .gitignore
│
├── docs/
│   ├── main.tex
│   ├── preamble.tex
│   ├── bibliography.bib
│   ├── figures/
│   │   ├── pipeline_overview.pdf
│   │   ├── erp_examples.pdf
│   │   ├── tf_maps.pdf
│   │   ├── latent_trajectories_2d.pdf
│   │   ├── latent_trajectories_3d.pdf
│   │   ├── jpca_rotation.pdf
│   │   ├── tangent_space_angles.pdf
│   │   ├── manifold_occupancy.pdf
│   │   └── decoding_curves.pdf
│   │
│   ├── chapters/
│   │   ├── 01_introduction.tex
│   │   ├── 02_experimental_data_and_recording_methods.tex
│   │   ├── 03_signal_preprocessing.tex
│   │   ├── 04_event_locked_signal_extraction.tex
│   │   ├── 05_trial_level_quality_control.tex
│   │   ├── 06_event_related_potential_analysis.tex
│   │   ├── 07_time_frequency_analysis.tex
│   │   ├── 08_oscillatory_neural_dynamics.tex
│   │   ├── 09_phase_based_neural_synchronization.tex
│   │   ├── 10_statistical_inference.tex
│   │   ├── 11_multichannel_neural_population_representation.tex
│   │   ├── 12_dimensionality_reduction.tex
│   │   ├── 13_latent_neural_trajectories.tex
│   │   ├── 14_trajectory_geometry.tex
│   │   ├── 15_condition_separation_in_latent_space.tex
│   │   ├── 16_rotational_neural_dynamics.tex
│   │   ├── 17_tangent_space_dynamics.tex
│   │   ├── 18_geometry_of_neural_manifolds.tex
│   │   ├── 19_neural_decoding.tex
│   │   ├── 20_uncertainty_quantification.tex
│   │   ├── 21_visualization_of_neural_dynamics.tex
│   │   ├── 22_computational_implementation.tex
│   │   ├── 23_complete_matlab_pipeline_pseudocode.tex
│   │   ├── 24_algorithm_boxes.tex
│   │   ├── 25_discussion.tex
│   │   └── 26_conclusion.tex
│   │
│   └── appendix/
│       ├── A_matlab_code_library.tex
│       ├── B_configuration_reference.tex
│       ├── C_parameter_tables.tex
│       └── D_additional_figures.tex
│
├── code/
│   ├── run_seeg_pipeline.m
│   ├── add_paths.m
│   ├── startup.m
│   │
│   ├── config/
│   │   ├── default_config.m
│   │   ├── config_electrical_stimulation.m
│   │   ├── config_cognitive_task.m
│   │   └── config_latent_dynamics.m
│   │
│   ├── io/
│   │   ├── load_raw_seeg.m
│   │   ├── load_events.m
│   │   ├── load_metadata.m
│   │   ├── save_results.m
│   │   └── export_figures.m
│   │
│   ├── preprocessing/
│   │   ├── preprocess_signals.m
│   │   ├── apply_highpass.m
│   │   ├── apply_lowpass.m
│   │   ├── remove_line_noise.m
│   │   ├── rereference_car.m
│   │   ├── rereference_bipolar.m
│   │   ├── detect_bad_channels.m
│   │   ├── detect_artifact_segments.m
│   │   └── suppress_stimulation_artifacts.m
│   │
│   ├── epoching/
│   │   ├── extract_event_locked_trials.m
│   │   ├── build_trial_tensor.m
│   │   ├── align_to_events.m
│   │   └── apply_poststim_mask.m
│   │
│   ├── qc/
│   │   ├── compute_trial_quality.m
│   │   ├── compute_rms_metric.m
│   │   ├── compute_variance_metric.m
│   │   ├── compute_peak_to_peak_metric.m
│   │   ├── compute_kurtosis_metric.m
│   │   ├── compute_line_noise_ratio.m
│   │   ├── make_composite_quality_score.m
│   │   ├── classify_trials.m
│   │   └── assign_trial_weights.m
│   │
│   ├── erp/
│   │   ├── compute_robust_erp.m
│   │   ├── compute_weighted_erp.m
│   │   ├── extract_erp_components.m
│   │   └── subtract_erp.m
│   │
│   ├── timefreq/
│   │   ├── compute_time_frequency.m
│   │   ├── create_morlet_wavelet.m
│   │   ├── convolve_wavelet.m
│   │   ├── compute_spectral_power.m
│   │   ├── baseline_normalize_tf.m
│   │   ├── compute_induced_power.m
│   │   ├── compute_band_limited_power.m
│   │   └── compute_high_frequency_activity.m
│   │
│   ├── phase/
│   │   ├── compute_itpc.m
│   │   ├── compute_plv.m
│   │   └── compute_phase_features.m
│   │
│   ├── features/
│   │   ├── extract_neural_features.m
│   │   ├── extract_roi_features.m
│   │   ├── extract_band_features.m
│   │   ├── extract_hfa_features.m
│   │   └── build_feature_table.m
│   │
│   ├── stats/
│   │   ├── run_permutation_statistics.m
│   │   ├── permutation_test_roi.m
│   │   ├── cluster_tf_permutation.m
│   │   ├── fdr_correction.m
│   │   ├── estimate_response_onset.m
│   │   ├── max_stat_onset_test.m
│   │   └── summarize_statistics.m
│   │
│   ├── population/
│   │   ├── build_population_tensor.m
│   │   ├── normalize_population_tensor.m
│   │   ├── reshape_trial_channel_time.m
│   │   └── make_condition_labels.m
│   │
│   ├── latent/
│   │   ├── fit_latent_model.m
│   │   ├── fit_pca_model.m
│   │   ├── fit_factor_analysis_model.m
│   │   ├── fit_gpfa_model.m
│   │   ├── project_to_latent_space.m
│   │   ├── smooth_latent_trajectories.m
│   │   ├── compute_condition_averaged_trajectories.m
│   │   └── align_latent_trajectories.m
│   │
│   ├── geometry/
│   │   ├── compute_trajectory_geometry.m
│   │   ├── compute_velocity.m
│   │   ├── compute_curvature.m
│   │   ├── compute_dispersion.m
│   │   ├── compute_path_length.m
│   │   ├── compute_condition_separation.m
│   │   ├── compute_condition_centroids.m
│   │   ├── compute_intercondition_distance.m
│   │   └── compute_time_resolved_separation.m
│   │
│   ├── dynamics/
│   │   ├── run_dynamical_systems_analysis.m
│   │   ├── run_jpca_analysis.m
│   │   ├── fit_linear_dynamics.m
│   │   ├── extract_rotational_plane.m
│   │   ├── run_tangent_space_analysis.m
│   │   ├── estimate_tangent_vectors.m
│   │   ├── compute_principal_angles.m
│   │   ├── compute_state_space_occupancy.m
│   │   ├── compute_trajectory_recurrence.m
│   │   └── compute_subspace_overlap.m
│   │
│   ├── decoding/
│   │   ├── run_neural_decoding.m
│   │   ├── train_linear_decoder.m
│   │   ├── run_cross_validation.m
│   │   ├── run_time_resolved_decoding.m
│   │   ├── permutation_test_decoding.m
│   │   └── estimate_decoding_onset.m
│   │
│   ├── uncertainty/
│   │   ├── bootstrap_trajectory_uncertainty.m
│   │   ├── bootstrap_condition_trajectories.m
│   │   ├── bootstrap_geometry_metrics.m
│   │   ├── compute_confidence_tubes.m
│   │   └── summarize_uncertainty.m
│   │
│   ├── visualization/
│   │   ├── generate_figures.m
│   │   ├── plot_erp.m
│   │   ├── plot_time_frequency_map.m
│   │   ├── plot_itpc.m
│   │   ├── plot_latent_trajectory_2d.m
│   │   ├── plot_latent_trajectory_3d.m
│   │   ├── plot_condition_separation.m
│   │   ├── plot_jpca_plane.m
│   │   ├── plot_tangent_angles.m
│   │   ├── plot_manifold_occupancy.m
│   │   ├── plot_decoding_curve.m
│   │   └── plot_confidence_tubes.m
│   │
│   ├── utils/
│   │   ├── assert_inputs.m
│   │   ├── get_time_index.m
│   │   ├── zscore_safe.m
│   │   ├── smooth_gaussian.m
│   │   ├── vector_norm_rows.m
│   │   └── make_output_dirs.m
│   │
│   └── external/
│       └── fieldtrip/
│
├── data/
│   ├── raw/
│   ├── metadata/
│   ├── events/
│   ├── processed/
│   ├── intermediate/
│   └── results/
│
├── results/
│   ├── subject_level/
│   ├── group_level/
│   ├── figures/
│   ├── tables/
│   └── logs/
│
└── tests/
    ├── test_preprocessing.m
    ├── test_time_frequency.m
    ├── test_latent_projection.m
    ├── test_geometry_metrics.m
    ├── test_decoding.m
    └── test_bootstrap.m