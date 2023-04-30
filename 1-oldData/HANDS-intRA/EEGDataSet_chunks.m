classdef EEGDataSet_chunks

    properties

        loadedData
        EEG
        electrodeNames
        signalsStartFrom
        signalsCue
        classes

        startEEGFrom
        EEGToLoad

        EEGToLoadDim
        numChannels
        numFeatures
        numSignals

        EEGOriginalDim
        numSignalsOriginal
        lastSignalTime
        timeIntervals

        cueToLoad

        signalsCueCategoricalOUTPUT
        categories
        numClasses

        signalsCueCategoricalINPUT
        correctedPrediction
    end

    methods

        function obj = EEGDataSet_chunks(filePath, electrodesToConsider)

            obj.loadedData = load(filePath);
            obj.EEG = transpose(obj.loadedData.cnt);
            obj.electrodeNames = obj.loadedData.nfo.clab;

            if electrodesToConsider ~= "all"
                
                electrodePositions = find(ismember(obj.electrodeNames, electrodesToConsider));
                obj.EEG = obj.EEG(electrodePositions, :);

            end

            obj.signalsStartFrom = obj.loadedData.mrk.pos;
            obj.signalsCue = obj.loadedData.mrk.y;
            obj.classes = string(obj.loadedData.nfo.classes);

            obj.startEEGFrom = obj.signalsStartFrom(1);
            obj.EEGToLoad = obj.EEG(:, obj.signalsStartFrom : end);

            obj.EEGToLoadDim = size(obj.EEGToLoad);
            obj.numChannels = obj.EEGToLoadDim(1);
            obj.numFeatures = obj.numChannels; % for later Defining of the Deep Learning Model
            obj.numSignals = obj.EEGToLoadDim(2);

            obj.EEGOriginalDim = size(obj.EEG);
            obj.numSignalsOriginal = obj.EEGOriginalDim(2);
            obj.lastSignalTime = obj.numSignalsOriginal;
            obj.timeIntervals = cat(2, obj.signalsStartFrom, obj.lastSignalTime + 1);
            % + 1 in the end because below, in the for loop, in the very last iteration, we
            % will otherwise skip the very last row of EEG if not added 1



            % Old method

%             obj.cueToLoad = ones(1, obj.numSignals) * -26367; % just initialize it with non-trivial number
%             currentSignalIndex = 0;
% 
%             for i = 1 : length(obj.signalsStartFrom)
%                 currentCue = obj.signalsCue(i);
%                 for j = obj.timeIntervals(i) : obj.timeIntervals(i+1) - 1
%                     currentSignalIndex = currentSignalIndex + 1;
%                     obj.cueToLoad(currentSignalIndex) = currentCue; % I THINK THERE IS SOME METHOD TO RUN THIS WITHOUT FOR LOOP !
%                 end
%             end
% 
%             obj.signalsCueCategoricalOUTPUT = categorical(obj.cueToLoad, [-1, 1], ["left", "right"]); % maybe put CLASSES var here ? ? ?
%             obj.categories = categories(obj.signalsCueCategoricalOUTPUT);
%             obj.numClasses = length(obj.categories); % for later Defining of the Deep Learning Model





            % Chunks method
            newEEGToLoad = cell(length(obj.signalsStartFrom), 1);
            newSignalsCueCategoricalOUTPUT = cell(length(obj.signalsStartFrom), 1);

            for i = 1 : length(obj.signalsStartFrom)

                % eeg
                newEEGToLoad{i} = obj.EEG(:, obj.timeIntervals(i) : obj.timeIntervals(i+1) - 1);

                % cue
                currentCueLen = obj.timeIntervals(i+1) - obj.timeIntervals(i);
                currentCue = zeros(1, currentCueLen);
                currentCue = currentCue + obj.signalsCue(i); % set the actual value for cue
                currentCue = categorical(currentCue, [-1, 1], ["left", "right"]);
                newSignalsCueCategoricalOUTPUT{i} = currentCue;
                
            end

            obj.EEGToLoad = newEEGToLoad;
            obj.signalsCueCategoricalOUTPUT = newSignalsCueCategoricalOUTPUT;

            signalsCueCat = categorical(obj.signalsCue, [-1, 1], ["left", "right"]);
            obj.categories = categories(signalsCueCat);
            obj.numClasses = length(obj.categories); % for later Defining of the Deep Learning Model




        end

        function obj = fixPrediction(obj, YPred)

            % For now, we will not for loop YPred (predictedValues). For
            % now, we will just consider the first cell in YPred cell, and
            % that's it. Later, when we will have corresponding examples
            % with multiple entries in YPred, I will for-loop it and find
            % weighted average for all entries.

%             disp("PASSED: YES");

            predictedValues = YPred{1, 1};
            obj.correctedPrediction = ones(1, length(obj.signalsCue)) * -436453;
            currentPredictionIndex = 0;

            for i = 1 : length(obj.signalsStartFrom)

                leftCount = 0;
                rightCount = 0;

                for j = obj.timeIntervals(i) : obj.timeIntervals(i+1) - 1

                    currentPredictionIndex = currentPredictionIndex + 1;

                    if predictedValues(currentPredictionIndex) == categorical("right")
                        rightCount = rightCount + 1;
                    elseif predictedValues(currentPredictionIndex) == categorical("left")
                        leftCount = leftCount + 1;
                    end

                end

                if rightCount > leftCount
                    obj.correctedPrediction(i) = 1;
                elseif rightCount < leftCount
                    obj.correctedPrediction(i) = -1;
                else        % This should not be the case, or, at least, happen rarely
                    obj.correctedPrediction(i) = -345673;
                end

            end

            obj.signalsCueCategoricalINPUT = categorical(obj.signalsCue, [-1, 1], ["left", "right"]); % maybe put CLASSES var here ? ? ?
            obj.correctedPrediction = categorical(obj.correctedPrediction, [-1, 1], ["left", "right"]); % maybe put CLASSES var here ? ? ?


        end
    end
end