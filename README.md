# SDR Term Assignment - PlutoSDR LoRa Analysis

## Project Overview

This project performs LoRa (Long Range) communication analysis using the ADALM-Pluto Software Defined Radio (SDR). The simulation evaluates Bit Error Rate (BER) performance against Signal-to-Interference Ratio (SIR) for various LoRa spreading factors and interference scenarios.

## Required MATLAB Add-ons

To run this code, you must install the following MATLAB add-ons:

### Essential Add-ons:
1. **Communications Toolbox** - Core communication signal processing functions
2. **Signal Processing Toolbox** - Signal analysis and filtering utilities
3. **DSP System Toolbox** - Digital signal processing implementations
4. **Wireless Communications Toolbox** - LoRa and wireless-specific functions

### Hardware Support:
5. **Software Defined Radio (SDR) Support Package** - Core SDR functionality
   - Download from: MATLAB Add-On Explorer
   - Required for `sdrrx` object

6. **Communications Toolbox Support Package for Analog Devices ADALM-Pluto Radio** - PlutoSDR-specific drivers
   - Required to communicate with the Pluto SDR hardware

### Installation Steps:

1. Open MATLAB
2. Go to **Home** → **Add-Ons** → **Get Add-ons**
3. Search for and install each add-on listed above
4. Restart MATLAB after installation
5. Verify installation by running:
   ```matlab
   sdrinfo  % Should display SDR hardware info
   ```

## Hardware Requirements

- **ADALM-Pluto SDR** connected via USB or Ethernet
- Default IP address: `192.168.2.1` (configure as needed in Code.m)
- Sufficient USB power or external power supply for Pluto

## How to Run the Code

### Quick Start:

1. **Configure the PlutoSDR Connection:**
   - Update the `RadioID` parameter in Code.m if using a different IP address or USB connection
   - Default: `'ip:192.168.2.1'`

2. **Run the Simulation:**
   ```matlab
   Code
   ```
   Or in the MATLAB editor, click **Run** (green play button)

3. **View Results:**
   - The code generates multiple figures showing BER vs SIR performance
   - Results are displayed for different spreading factors (SF 6, 9, 12)
   - Monitor the console for noise floor measurements

### Code Execution Details:

- **Warm-up Phase:** 5 initial frames are captured to clear the ADC pipeline
- **Main Simulation:** 
  - Sweeps through multiple SIR points (-30 to 5 dB)
  - Tests all spreading factors (SF 6-12)
  - Runs 200 Monte Carlo test packets per configuration
  - Real-time IQ data capture from PlutoSDR

## Configuration Parameters

Edit these values in `Code.m` to customize the simulation:

```matlab
N_BITS           = 500;        % Payload bits per packet
N_PACKETS        = 200;        % Monte Carlo packets per SIR point
BW_HZ            = 125000;     % Bandwidth (125, 250, or 500 kHz)
SIR_RANGE        = -30:2:5;   % SIR sweep range (dB)
SF_ALL           = [6:12];     % All spreading factors to test
```

## LoRa Parameters

- **Center Frequency:** 868.1 MHz (EU868 LoRa channel)
- **Sample Rate:** 1 MSPS (1,000,000 samples/second)
- **Gain Mode:** Manual (35 dB)
- **Frame Size:** 4096 samples per capture