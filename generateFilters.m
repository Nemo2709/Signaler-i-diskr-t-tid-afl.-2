function [poles, zeros] = generateFilters(freqBands, Fs)
    % Ensure freqBands is a row vector
    if iscolumn(freqBands)
        freqBands = freqBands.';
    end

    % Number of bandpass filters
    numBands = length(freqBands) - 1;
    poles = cell(1, numBands + 2); % Adjust size for Lowpass + Highpass
    zeros = cell(1, numBands + 2);

    % Lowpass filter
    poles{1} = [0.95 + 0.01j, 0.95 - 0.01j].';
    zeros{1} = [0.99 + 0.01j, 0.99 - 0.01j].';

    % Bandpass filters
    for i = 1:numBands
        centerFreq = sqrt(freqBands(i) * freqBands(i + 1));
        bandwidth = freqBands(i + 1) - freqBands(i);

        % Normalize frequencies
        if Fs <= 0
            error('Sampling frequency Fs must be greater than zero.');
        end
        normalizedFreq = centerFreq / (Fs / 2);
        bwNorm = bandwidth / (Fs / 2);

        % Assign poles and zeros
        poles{i + 1} = [0.95 * exp(1j * pi * normalizedFreq), ...
                        0.95 * exp(-1j * pi * normalizedFreq)].';
        zeros{i + 1} = [0.99 * exp(1j * pi * normalizedFreq), ...
                        0.99 * exp(-1j * pi * normalizedFreq)].';
    end

    % Highpass filter
    poles{numBands + 2} = [0.95 + 0.01j, 0.95 - 0.01j].';
    zeros{numBands + 2} = [0.99 + 0.01j, 0.99 - 0.01j].';
end
