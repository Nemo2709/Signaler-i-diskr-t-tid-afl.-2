function processedAudio = applyFilters(audio, poles, zeros, gains)
    numBands = length(poles);
    filteredSignals = cell(1, numBands);

    for i = 1:numBands
        [b, a] = zp2tf(zeros{i}, poles{i}, 1);
        filteredSignals{i} = filter(b, a, audio) * gains(i);
    end

    processedAudio = sum(cat(2, filteredSignals{:}), 2);
end
