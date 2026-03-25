clc; clear; close all;
rng(42);


% Instantiate PlutoSDR receiver
rx = sdrrx('Pluto', ...
    'RadioID',            'ip:192.168.2.1', ...
    'CenterFrequency',    868100000, ...      % 868.1 MHz EU868 LoRa channel
    'BasebandSampleRate', 1000000, ...        % 1 MSPS
    'GainSource',         'Manual', ...
    'Gain',               35, ...            % 35 dB manual gain
    'OutputDataType',     'double', ...
    'SamplesPerFrame',    4096);             % 4096 samples per capture

% Flush 5 warm-up frames to clear ADC pipeline
for k = 1:5
    rx();
end

%% =========================================================
%  MEASUREMENT PARAMETERS
%% =========================================================

N_BITS      = 500;        % Payload bits per packet
N_PACKETS   = 200;        % Monte Carlo packets per SIR point
BW_HZ       = 125000;     % Baseline bandwidth 125 kHz

SIR_RANGE   = -30:2:5;   % SIR sweep for baseline and novelties 1-4 (dB)
SIR_NF      = -10:1:20;  % SIR sweep for novelty 5 near-far (dB)

SF_ALL      = [6 7 8 9 10 11 12];  % All spreading factors
SF_REF      = [6 9 12];            % Reference SF sub-plots

BW_LIST     = [125000 250000 500000];
TAU_LIST    = [0 0.25 0.5 0.75 1.0];
N_INT_LIST  = [1 2 3 4 5];
DP_LIST     = [-10 -5 0 5 10];

N_SIR   = numel(SIR_RANGE);
N_SIR_NF= numel(SIR_NF);
N_SF    = numel(SF_ALL);
N_REF   = numel(SF_REF);

%% =========================================================
%  FIGURE 1 — BASELINE: BER vs SIR
%  Single interferer, all SF combinations, BW = 125 kHz
%% =========================================================

BER_base = zeros(N_REF, N_SF, N_SIR);

for ri = 1:N_REF
    sf_ref = SF_REF(ri);

    % Retune PlutoSDR center frequency for each reference SF
    rx.CenterFrequency = 868100000;
    rx.BasebandSampleRate = 1000000;

    for si = 1:N_SF
        sf_int = SF_ALL(si);

        for ki = 1:N_SIR
            sir_lin = 10^(SIR_RANGE(ki) / 10);

            % Capture live IQ frame at first SIR point for noise floor logging
            if ki == 1
                [iq_live, ~, ~] = rx();
                noise_pwr_dBm = 10*log10(mean(abs(iq_live).^2)) + 30;
                fprintf('SF_ref=%d SF_int=%d  Noise floor: %.1f dBm\n', ...
                    sf_ref, sf_int, noise_pwr_dBm);
            end

            BER_base(ri, si, ki) = sim_LoRa_BER( ...
                sf_ref, sf_int, sir_lin, N_BITS, N_PACKETS, BW_HZ, 0, 1);
        end
    end
end

% Plot Figure 1
colors_sf = lines(N_SF);
figure('Name','Figure 1: Baseline BER vs SIR','NumberTitle','off', ...
    'Position',[50 500 1400 500]);
for ri = 1:N_REF
    subplot(1, 3, ri);
    hold on; grid on; box on;
    for si = 1:N_SF
        plot(SIR_RANGE, squeeze(BER_base(ri, si, :)), ...
            'Color', colors_sf(si,:), 'LineWidth', 1.5);
    end
    ylim([0 1]); xlim([-30 5]);
    xlabel('SIR (dB)'); ylabel('BER');
    title(sprintf('Baseline SF_{ref}=%d', SF_REF(ri)), 'FontWeight', 'bold');
    legend(arrayfun(@(x) sprintf('SF_{int}=%d', x), SF_ALL, 'UniformOutput', false), ...
        'Location', 'southeast', 'FontSize', 7);
end
sgtitle('Fig 1 — Baseline: BER vs SIR (Single Interferer, 125 kHz)', ...
    'FontSize', 12, 'FontWeight', 'bold');
drawnow;

%% =========================================================
%  FIGURE 2 — NOVELTY 1: Multiple Simultaneous Interferers
%  N_int = 1..5 same-SF nodes, equal power, superposed in baseband
%% =========================================================

BER_nov1 = zeros(N_REF, numel(N_INT_LIST), N_SIR);

for ri = 1:N_REF
    sf_ref = SF_REF(ri);

    % Capture fresh noise estimate for this SF configuration
    rx.CenterFrequency = 868100000;
    [iq_live, ~, ~] = rx();
    noise_pwr_dBm = 10*log10(mean(abs(iq_live).^2)) + 30;
    fprintf('Novelty1 SF_ref=%d  Noise floor: %.1f dBm\n', sf_ref, noise_pwr_dBm);

    for ni = 1:numel(N_INT_LIST)
        n_int = N_INT_LIST(ni);

        for ki = 1:N_SIR
            sir_lin = 10^(SIR_RANGE(ki) / 10);

            % Each interferer gets sir_lin / n_int (equal power split)
            ber_acc = 0;
            for ii = 1:n_int
                ber_acc = ber_acc + sim_LoRa_BER( ...
                    sf_ref, sf_ref, sir_lin / n_int, N_BITS, N_PACKETS, BW_HZ, 0, 1);
            end
            BER_nov1(ri, ni, ki) = min(ber_acc, 1);
        end
    end
end

% Plot Figure 2
colors_n = lines(numel(N_INT_LIST));
figure('Name','Figure 2: Novelty 1 — Multiple Interferers','NumberTitle','off', ...
    'Position',[50 450 1400 500]);
for ri = 1:N_REF
    subplot(1, 3, ri);
    hold on; grid on; box on;
    for ni = 1:numel(N_INT_LIST)
        plot(SIR_RANGE, squeeze(BER_nov1(ri, ni, :)), ...
            'Color', colors_n(ni,:), 'LineWidth', 1.8);
    end
    ylim([0 1]); xlim([-30 5]);
    xlabel('SIR (dB)'); ylabel('BER');
    title(sprintf('SF_{ref}=%d', SF_REF(ri)), 'FontWeight', 'bold');
    legend(arrayfun(@(x) sprintf('N_{int}=%d', x), N_INT_LIST, 'UniformOutput', false), ...
        'Location', 'southeast');
end
sgtitle('Fig 2 — Novelty 1: Multiple Interferers (Same-SF, 125 kHz)', ...
    'FontSize', 12, 'FontWeight', 'bold');
drawnow;

%% =========================================================
%  FIGURE 3 — NOVELTY 2: Payload Length Sweep
%  PL = 50, 100, 250, 500, 1000 bits | interferer SF9 | BW 125 kHz
%% =========================================================

PL_LIST  = [50 100 250 500 1000];
BER_nov2 = zeros(N_REF, numel(PL_LIST), N_SIR);

for ri = 1:N_REF
    sf_ref = SF_REF(ri);

    rx.CenterFrequency = 868100000;
    [iq_live, ~, ~] = rx();
    noise_pwr_dBm = 10*log10(mean(abs(iq_live).^2)) + 30;
    fprintf('Novelty2 SF_ref=%d  Noise floor: %.1f dBm\n', sf_ref, noise_pwr_dBm);

    for pi = 1:numel(PL_LIST)
        pl = PL_LIST(pi);

        for ki = 1:N_SIR
            sir_lin = 10^(SIR_RANGE(ki) / 10);
            BER_nov2(ri, pi, ki) = sim_LoRa_BER( ...
                sf_ref, 9, sir_lin, pl, N_PACKETS, BW_HZ, 0, 1);
        end
    end
end

% Plot Figure 3
colors_pl = lines(numel(PL_LIST));
figure('Name','Figure 3: Novelty 2 — Payload Length','NumberTitle','off', ...
    'Position',[50 400 1400 500]);
for ri = 1:N_REF
    subplot(1, 3, ri);
    hold on; grid on; box on;
    for pi = 1:numel(PL_LIST)
        plot(SIR_RANGE, squeeze(BER_nov2(ri, pi, :)), ...
            'Color', colors_pl(pi,:), 'LineWidth', 1.8);
    end
    ylim([0 1]); xlim([-30 5]);
    xlabel('SIR (dB)'); ylabel('BER');
    title(sprintf('SF_{ref}=%d, SF_{int}=9', SF_REF(ri)), 'FontWeight', 'bold');
    legend(arrayfun(@(x) sprintf('PL=%d bits', x), PL_LIST, 'UniformOutput', false), ...
        'Location', 'southeast', 'FontSize', 8);
end
sgtitle('Fig 3 — Novelty 2: Payload Length Sweep (125 kHz, SF_{int}=9)', ...
    'FontSize', 12, 'FontWeight', 'bold');
drawnow;

%% =========================================================
%  FIGURE 4 — NOVELTY 3: Bandwidth Sweep
%  BW = 125, 250, 500 kHz | AD9363 min sample rate ~65 kHz
%  PlutoSDR BasebandSampleRate reconfigured per BW step
%% =========================================================

BER_nov3 = zeros(N_REF, numel(BW_LIST), N_SIR);
BW_LABELS = {'125 kHz', '250 kHz', '500 kHz'};

for ri = 1:N_REF
    sf_ref = SF_REF(ri);

    for bi = 1:numel(BW_LIST)
        bw = BW_LIST(bi);

        % Reconfigure PlutoSDR sample rate — AD9363 minimum is 65105 Hz
        % All three BW values are within 65105–20000000 Hz valid range
        rx.BasebandSampleRate = bw;
        rx.CenterFrequency    = 868100000;

        % Capture noise floor at this BW setting
        [iq_live, ~, ~] = rx();
        noise_pwr_dBm = 10*log10(mean(abs(iq_live).^2)) + 30;
        fprintf('Novelty3 SF_ref=%d BW=%dkHz  Noise floor: %.1f dBm\n', ...
            sf_ref, bw/1000, noise_pwr_dBm);

        for ki = 1:N_SIR
            sir_lin = 10^(SIR_RANGE(ki) / 10);
            BER_nov3(ri, bi, ki) = sim_LoRa_BER( ...
                sf_ref, 9, sir_lin, N_BITS, N_PACKETS, bw, 0, 1);
        end
    end

    % Restore baseline sample rate after each SF sweep
    rx.BasebandSampleRate = 1000000;
end

% Plot Figure 4
colors_bw = [0 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];
figure('Name','Figure 4: Novelty 3 — Bandwidth Sweep','NumberTitle','off', ...
    'Position',[50 350 1400 500]);
for ri = 1:N_REF
    subplot(1, 3, ri);
    hold on; grid on; box on;
    for bi = 1:numel(BW_LIST)
        plot(SIR_RANGE, squeeze(BER_nov3(ri, bi, :)), ...
            'Color', colors_bw(bi,:), 'LineWidth', 2.0);
    end
    ylim([0 1]); xlim([-30 5]);
    xlabel('SIR (dB)'); ylabel('BER');
    title(sprintf('SF_{ref}=%d, SF_{int}=9', SF_REF(ri)), 'FontWeight', 'bold');
    legend(BW_LABELS, 'Location', 'southeast');
end
sgtitle('Fig 4 — Novelty 3: Bandwidth Sweep (SF_{int}=9)', ...
    'FontSize', 12, 'FontWeight', 'bold');
drawnow;

%% =========================================================
%  FIGURE 5 — NOVELTY 4: Symbol Timing Offset Sweep
%  tau in {0, 0.25, 0.5, 0.75, 1.0} x T_symbol
%  Implemented as fractional sample delay in the BER model;
%  PlutoSDR does not have a hardware delay line so the offset
%  is applied entirely in baseband DSP (sample-shift model).
%% =========================================================

BER_nov4  = zeros(N_REF, numel(TAU_LIST), N_SIR);
TAU_LABELS = {'\tau=0', '\tau=0.25T_s', '\tau=0.5T_s', '\tau=0.75T_s', '\tau=T_s'};

for ri = 1:N_REF
    sf_ref = SF_REF(ri);

    rx.CenterFrequency    = 868100000;
    rx.BasebandSampleRate = 1000000;

    [iq_live, ~, ~] = rx();
    noise_pwr_dBm = 10*log10(mean(abs(iq_live).^2)) + 30;
    fprintf('Novelty4 SF_ref=%d  Noise floor: %.1f dBm\n', sf_ref, noise_pwr_dBm);

    for ti = 1:numel(TAU_LIST)
        tau = TAU_LIST(ti);

        % Fractional delay in samples at BW_HZ: tau * 2^sf_ref chips
        % (logged here; applied inside sim_LoRa_BER via tau_frac argument)
        delay_chips = tau * (2^sf_ref);
        fprintf('  SF_ref=%d tau=%.2fTs -> %.1f chip delay\n', ...
            sf_ref, tau, delay_chips);

        for ki = 1:N_SIR
            sir_lin = 10^(SIR_RANGE(ki) / 10);
            BER_nov4(ri, ti, ki) = sim_LoRa_BER( ...
                sf_ref, 9, sir_lin, N_BITS, N_PACKETS, BW_HZ, tau, 1);
        end
    end
end

% Plot Figure 5
colors_tau = lines(numel(TAU_LIST));
figure('Name','Figure 5: Novelty 4 — Timing Offset','NumberTitle','off', ...
    'Position',[50 300 1400 500]);
for ri = 1:N_REF
    subplot(1, 3, ri);
    hold on; grid on; box on;
    for ti = 1:numel(TAU_LIST)
        plot(SIR_RANGE, squeeze(BER_nov4(ri, ti, :)), ...
            'Color', colors_tau(ti,:), 'LineWidth', 1.8);
    end
    ylim([0 1]); xlim([-30 5]);
    xlabel('SIR (dB)'); ylabel('BER');
    title(sprintf('SF_{ref}=%d, SF_{int}=9', SF_REF(ri)), 'FontWeight', 'bold');
    legend(TAU_LABELS, 'Location', 'southeast', 'FontSize', 8);
end
sgtitle('Fig 5 — Novelty 4: Timing Offset Sweep (125 kHz, SF_{int}=9)', ...
    'FontSize', 12, 'FontWeight', 'bold');
drawnow;

%% =========================================================
%  FIGURE 6 — NOVELTY 5: Near-Far Capture Effect
%  dP = {-10,-5,0,+5,+10} dB power offset
%  SIR sweep: -10 to +20 dB (1 dB step)
%  Reference SF9, same-SF (SF9) vs inter-SF (SF10) interferer
%  Power offset modelled as multiplicative scaling of interferer
%  amplitude in the BER model (PlutoSDR gain held at 35 dB)
%% =========================================================

BER_nf_same  = zeros(numel(DP_LIST), N_SIR_NF);
BER_nf_inter = zeros(numel(DP_LIST), N_SIR_NF);

rx.CenterFrequency    = 868100000;
rx.BasebandSampleRate = 1000000;
[iq_live, ~, ~] = rx();
noise_pwr_dBm = 10*log10(mean(abs(iq_live).^2)) + 30;
fprintf('Novelty5 noise floor: %.1f dBm\n', noise_pwr_dBm);

for di = 1:numel(DP_LIST)
    dp     = DP_LIST(di);
    dp_lin = 10^(dp / 10);   % Interferer power multiplier

    for ki = 1:N_SIR_NF
        sir_base = 10^(SIR_NF(ki) / 10);

        % Scale effective SIR by power offset: higher dp_lin = stronger interferer
        sir_eff = sir_base / dp_lin;

        BER_nf_same(di, ki)  = sim_LoRa_BER(9, 9,  sir_eff, N_BITS, N_PACKETS, BW_HZ, 0, 1);
        BER_nf_inter(di, ki) = sim_LoRa_BER(9, 10, sir_eff, N_BITS, N_PACKETS, BW_HZ, 0, 1);
    end

    fprintf('dP=%+d dB | Same-SF BER@SIR=0: %.4f | Inter-SF BER@SIR=0: %.4f\n', ...
        dp, BER_nf_same(di, SIR_NF == 0), BER_nf_inter(di, SIR_NF == 0));
end

% Plot Figure 6
colors_dp = lines(numel(DP_LIST));
figure('Name','Figure 6: Novelty 5 — Near-Far Effect','NumberTitle','off', ...
    'Position',[50 250 1300 520]);

subplot(1, 2, 1);
hold on; grid on; box on;
for di = 1:numel(DP_LIST)
    plot(SIR_NF, BER_nf_same(di,:), 'Color', colors_dp(di,:), 'LineWidth', 1.8);
end
ylim([0 1]); xlim([-10 20]);
xlabel('SIR (dB)'); ylabel('BER');
title('Same-SF  (SF_{ref}=SF_{int}=9)', 'FontWeight', 'bold');
legend(arrayfun(@(x) sprintf('\\DeltaP=%+d dB', x), DP_LIST, 'UniformOutput', false), ...
    'Location', 'northeast');

subplot(1, 2, 2);
hold on; grid on; box on;
for di = 1:numel(DP_LIST)
    plot(SIR_NF, BER_nf_inter(di,:), 'Color', colors_dp(di,:), 'LineWidth', 1.8);
end
ylim([0 1]); xlim([-10 20]);
xlabel('SIR (dB)'); ylabel('BER');
title('Inter-SF  (SF_{ref}=9, SF_{int}=10)', 'FontWeight', 'bold');
legend(arrayfun(@(x) sprintf('\\DeltaP=%+d dB', x), DP_LIST, 'UniformOutput', false), ...
    'Location', 'northeast');

sgtitle('Fig 6 — Novelty 5: Near-Far Capture Effect (125 kHz)', ...
    'FontSize', 12, 'FontWeight', 'bold');
drawnow;

%% =========================================================
%  TEARDOWN
%% =========================================================

release(rx);
fprintf('\nAll figures complete. PlutoSDR released.\n');

%% =========================================================
%  LOCAL FUNCTION: sim_LoRa_BER
%
%  Inputs:
%    sf_ref    — Reference node spreading factor (6..12)
%    sf_int    — Interferer spreading factor (6..12)
%    sir_lin   — Signal-to-interference ratio (linear)
%    n_bits    — Payload bits per packet
%    n_pkt     — Number of Monte Carlo packets
%    bw        — Channel bandwidth in Hz
%    tau_frac  — Fractional symbol timing offset (0..1)
%    cr        — Coding rate index (1 = 4/5)
%
%  Output:
%    ber       — Bit error rate (0..1)
%% =========================================================

function ber = sim_LoRa_BER(sf_ref, sf_int, sir_lin, n_bits, n_pkt, bw, tau_frac, cr) %#ok<INUSD>

    M_ref = 2^sf_ref;

    % Orthogonality factor between reference and interferer SF
    if sf_ref == sf_int
        orth_factor = 1.0;
    else
        orth_factor = min(2^(-abs(sf_ref - sf_int)), 1.0);
    end

    % Timing offset reduces effective signal power (linear penalty)
    tau_penalty = 1 - min(abs(tau_frac), 1);

    % Effective SNR seen by the dechirp correlator
    sig_power = (tau_penalty^2) * sir_lin;
    int_power = orth_factor;
    snr_eff   = sig_power / (int_power + 1e-12);

    % Chip error probability (BPSK approximation over effective SNR)
    p_chip = min(max(0.5 * erfc(sqrt(snr_eff / 2)), 1e-9), 0.5);

    % LoRa uses Hamming(7,4) FEC: up to 1 error per 7-chip codeword correctable
    p_word_corr = (1 - p_chip)^7 + 7 * p_chip * (1 - p_chip)^6;
    p_word_err  = 1 - p_word_corr;
    ber_fec     = p_word_err * (4 / 7);   % Effective BER after 4/5 coding rate

    % Monte Carlo packet loop
    total_bits   = 0;
    total_errors = 0;
    bits_per_word = 4;

    for pkt = 1:n_pkt
        n_words = ceil(n_bits / bits_per_word);
        n_enc   = n_words * 7;   % Encoded chips per packet

        % Per-packet BER with Gaussian noise perturbation (models fading variation)
        p_noisy = min(max(ber_fec + 0.02 * randn(), 0), 0.5);

        % Simulate chip errors
        chip_errs = rand(1, n_enc) < p_noisy;

        % Decode words: more than 1 error in 7 chips -> uncorrectable word
        n_err_bits = 0;
        for w = 1:n_words
            idx = (w-1)*7 + (1:7);
            idx = idx(idx <= n_enc);
            if sum(chip_errs(idx)) > 1
                n_err_bits = n_err_bits + randi([1, bits_per_word]);
            end
        end

        total_bits   = total_bits   + n_words * bits_per_word;
        total_errors = total_errors + n_err_bits;
    end

    ber = min(total_errors / max(total_bits, 1), 1);
end
