classdef EqualizerApp < matlab.apps.AppBase

    % Properties for app components
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        RecordButton         matlab.ui.control.Button
        FilterButton         matlab.ui.control.Button
        PlayButton           matlab.ui.control.Button
        PauseButton          matlab.ui.control.Button
        ResumeButton         matlab.ui.control.Button
        VolumeSlider         matlab.ui.control.Slider
        VolumeLabel          matlab.ui.control.Label
        Sliders              matlab.ui.control.Slider
        SliderLabels         matlab.ui.control.Label
        SliderValues         matlab.ui.control.Label % Labels to show slider values
        OriginalAxes         matlab.ui.control.UIAxes
        FilteredAxes         matlab.ui.control.UIAxes
    end

    % Properties for data and functionality
    properties (Access = private)
        Audio                % Original recorded audio
        ProcessedAudio       % Filtered audio
        Fs = 44100;          % Sampling frequency (default)
        Player               % Audio player object
        Poles                % Poles for each filter
        Zeros                % Zeros for each filter
        Gains                % Gain for each filter
        Bands                % Frequency bands
    end

    % Callbacks for component events
    methods (Access = private)

        % Record Button callback
        function RecordButtonPushed(app, ~)
            recObj = audiorecorder(app.Fs, 16, 1); % Mono recording
            disp('Recording...');
            recordblocking(recObj, 5); % Record for 5 seconds
            disp('Recording complete.');

            % Overwrite any previous recording
            app.Audio = getaudiodata(recObj);
            app.ProcessedAudio = []; % Clear the filtered audio

            % Plot the new original signal
            plot(app.OriginalAxes, (0:length(app.Audio)-1)/app.Fs, app.Audio);
            title(app.OriginalAxes, 'Original Signal');
            xlabel(app.OriginalAxes, 'Time (s)');
            ylabel(app.OriginalAxes, 'Amplitude');

            % Clear the filtered signal plot
            cla(app.FilteredAxes);
            title(app.FilteredAxes, 'Filtered Signal');
        end

        % Filter Button callback
        function FilterButtonPushed(app, ~)
            if isempty(app.Audio)
                uialert(app.UIFigure, 'No audio recorded. Please record a signal first.', 'Error');
                return;
            end

            % Update gains from sliders
            app.Gains = arrayfun(@(s) s.Value, app.Sliders);

            % Apply filters
            app.ProcessedAudio = app.applyFilters(app.Audio, app.Poles, app.Zeros, app.Gains);

            % Plot the filtered signal
            plot(app.FilteredAxes, (0:length(app.ProcessedAudio)-1)/app.Fs, app.ProcessedAudio);
            title(app.FilteredAxes, 'Filtered Signal');
            xlabel(app.FilteredAxes, 'Time (s)');
            ylabel(app.FilteredAxes, 'Amplitude');
        end

        % Slider value update callback
        function SliderValueChanging(app, event, sliderIndex)
            app.SliderValues(sliderIndex).Text = sprintf('%.1f', event.Value);
        end

        % Play Button callback
        function PlayButtonPushed(app, ~)
            if isempty(app.Audio)
                uialert(app.UIFigure, 'No audio recorded or processed. Please record or filter a signal first.', 'Error');
                return;
            end

            % Determine which audio to play (original or processed)
            if isempty(app.ProcessedAudio)
                audioToPlay = app.Audio;
            else
                audioToPlay = app.ProcessedAudio;
            end

            % Play the audio
            if ~isempty(app.Player)
                stop(app.Player); % Stop any previous playback
            end
            app.Player = audioplayer(audioToPlay * app.VolumeSlider.Value, app.Fs);
            play(app.Player);
        end

        % Pause Button callback
        function PauseButtonPushed(app, ~)
            if ~isempty(app.Player)
                pause(app.Player);
            end
        end

        % Resume Button callback
        function ResumeButtonPushed(app, ~)
            if ~isempty(app.Player)
                resume(app.Player);
            end
        end

        % Apply filters to the audio
        function processedAudio = applyFilters(app, audio, poles, zeros, gains)
            processedAudio = audio;
            for i = 1:length(gains)
                [b, a] = zp2tf(zeros{i}, poles{i}, gains(i)); % Convert poles and zeros to transfer function
                processedAudio = filter(b, a, processedAudio); % Apply the filter
            end
        end

        % Generate filters based on bands
        function initializeFilters(app)
            % Define bands for lowpass, bandpass, and highpass
            app.Bands = [50, 200, 400, 800, 1500, 3000, 5000, 7000, 10000, 15000, 20000];
            numBands = length(app.Bands) - 1;
            app.Poles = cell(1, numBands + 2); % One lowpass, multiple bandpass, one highpass
            app.Zeros = cell(1, numBands + 2);

            % Lowpass filter
            app.Poles{1} = [0.95 + 0.01j, 0.95 - 0.01j].';
            app.Zeros{1} = [0.99 + 0.01j, 0.99 - 0.01j].';

            % Bandpass filters
            for i = 1:numBands
                centerFreq = sqrt(app.Bands(i) * app.Bands(i + 1));
                bandwidth = app.Bands(i + 1) - app.Bands(i);
                normalizedFreq = centerFreq / (app.Fs / 2);
                bwNorm = bandwidth / (app.Fs / 2);

                app.Poles{i + 1} = [normalizedFreq * (0.95 + 1j * bwNorm), ...
                                    normalizedFreq * (0.95 - 1j * bwNorm)].';
                app.Zeros{i + 1} = [normalizedFreq * (0.99 + 1j * bwNorm), ...
                                    normalizedFreq * (0.99 - 1j * bwNorm)].';
            end

            % Highpass filter
            app.Poles{end} = [0.95 + 0.01j, 0.95 - 0.01j].';
            app.Zeros{end} = [0.99 + 0.01j, 0.99 - 0.01j].';
        end
    end

    % Component initialization
    methods (Access = private)

        % Create components and layout
        function createComponents(app)
            % Create UIFigure
            app.UIFigure = uifigure('Position', [100 100 1200 700], 'Name', '10-Band Equalizer');

            % Create sliders and labels
            sliderRow1X = linspace(50, 1050, 5); % First row positions
            sliderRow2X = linspace(50, 1050, 5); % Second row positions
            sliderY1 = 250; % First row of sliders
            sliderY2 = 180; % Second row of sliders
            app.Sliders = matlab.ui.control.Slider.empty(1, 0);
            app.SliderLabels = matlab.ui.control.Label.empty(1, 0);
            app.SliderValues = matlab.ui.control.Label.empty(1, 0); % Labels to display slider values
            bandLabels = ["Lowpass", "200 Hz", "400 Hz", "800 Hz", "1.5 kHz", ...
                          "3 kHz", "5 kHz", "7 kHz", "10 kHz", "Highpass"];

            % Create first row of sliders
            for i = 1:5
                app.Sliders(i) = uislider(app.UIFigure, ...
                    'Position', [sliderRow1X(i), sliderY1, 120, 3], ...
                    'Limits', [-10 10], 'Value', 0, ...
                    'ValueChangingFcn', @(slider, event) SliderValueChanging(app, event, i));
                app.SliderLabels(i) = uilabel(app.UIFigure, ...
                    'Position', [sliderRow1X(i)-10, sliderY1 + 20, 60, 15], ...
                    'Text', bandLabels(i), 'HorizontalAlignment', 'center');
                app.SliderValues(i) = uilabel(app.UIFigure, ...
                    'Position', [sliderRow1X(i)-10, sliderY1 - 20, 60, 15], ...
                    'Text', '0.0', 'HorizontalAlignment', 'center');
            end

            % Create second row of sliders
            for i = 6:10
                app.Sliders(i) = uislider(app.UIFigure, ...
                    'Position', [sliderRow2X(i-5), sliderY2, 120, 3], ...
                    'Limits', [-10 10], 'Value', 0, ...
                    'ValueChangingFcn', @(slider, event) SliderValueChanging(app, event, i));
                app.SliderLabels(i) = uilabel(app.UIFigure, ...
                    'Position', [sliderRow2X(i-5)-10, sliderY2 + 20, 60, 15], ...
                    'Text', bandLabels(i), 'HorizontalAlignment', 'center');
                app.SliderValues(i) = uilabel(app.UIFigure, ...
                    'Position', [sliderRow2X(i-5)-10, sliderY2 - 20, 60, 15], ...
                    'Text', '0.0', 'HorizontalAlignment', 'center');
            end

            % Create Original Signal Axes
            app.OriginalAxes = uiaxes(app.UIFigure, 'Position', [50 400 550 250]);
            title(app.OriginalAxes, 'Original Signal');

            % Create Filtered Signal Axes
            app.FilteredAxes = uiaxes(app.UIFigure, 'Position', [600 400 550 250]);
            title(app.FilteredAxes, 'Filtered Signal');

            % Create Record Button
            app.RecordButton = uibutton(app.UIFigure, 'push', ...
                'Position', [50 50 100 30], 'Text', 'Record', ...
                'ButtonPushedFcn', @(btn, event) RecordButtonPushed(app));

            % Create Filter Button
            app.FilterButton = uibutton(app.UIFigure, 'push', ...
                'Position', [200 50 100 30], 'Text', 'Filter', ...
                'ButtonPushedFcn', @(btn, event) FilterButtonPushed(app));

            % Create Play Button
            app.PlayButton = uibutton(app.UIFigure, 'push', ...
                'Position', [350 50 100 30], 'Text', 'Play', ...
                'ButtonPushedFcn', @(btn, event) PlayButtonPushed(app));

            % Create Pause Button
            app.PauseButton = uibutton(app.UIFigure, 'push', ...
                'Position', [500 50 100 30], 'Text', 'Pause', ...
                'ButtonPushedFcn', @(btn, event) PauseButtonPushed(app));

            % Create Resume Button
            app.ResumeButton = uibutton(app.UIFigure, 'push', ...
                'Position', [650 50 100 30], 'Text', 'Resume', ...
                'ButtonPushedFcn', @(btn, event) ResumeButtonPushed(app));

            % Create Volume Slider
            app.VolumeSlider = uislider(app.UIFigure, ...
                'Position', [950 15 200 3], ...
                'Limits', [0 1], 'Value', 1);
            app.VolumeLabel = uilabel(app.UIFigure, ...
                'Position', [950 30 200 15], ...
                'Text', 'Volume');
        end
    end

    % App initialization and construction
    methods (Access = public)

        % Construct app
        function app = EqualizerApp()
            createComponents(app); % Create components
            initializeFilters(app); % Initialize filters
        end
    end
end
