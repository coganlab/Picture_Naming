function visual_naming(subject, practice, startblock)
% A function that runs a visual naming task in pyschtoolbox.
%
% The task is to name the objects in the image.
%
% The task is divided into blocks. 
% Each block is divided into trials.
% Each trial is divided into four events:
%   1. Cue
%   2. Stimuli
%   3. Go
%   4. Response
    
    % Initialize values
    nTrials = 1; % real number is nTrials X items X 6
    nrchannels = 1;
    freqS = 44100;
    freqR = 20000;
    [playbackdevID,capturedevID] = getDevices %#ok<NOPRT> 
    baseCircleDiam=75;
    event = struct( ...
        'Cue', struct('duration',2,'jitter',0.25), ...
        'Stimuli', struct('duration','sound'), ...
        'Go', struct('duration',1,'jitter',0.25), ...
        'Response', struct('duration',3,'jitter',0.25));
    if ispc
        Screen('Preference', 'SkipSyncTests', 1);
    end
    conditions = {'Repeat',':=:'};
    modality = {'text','image','sound'};
    soundDir = 'Stimuli/sounds/';
    imgDir = 'Stimuli/pictures/';
    sca;
    
    if ~exist('startblock','var')
        startblock = 1;
    end
    
    % Load the stimuli
    imgfiles = dir(imgDir);
    imgfiles = {imgfiles.name};
    imgfiles = imgfiles(3:end);
    if practice==1
        items = {'apple.PNG','spoon.PNG'}; % 2 items
        nBlocks = 1;
        fileSuff = '_Pract';
    else
        items = imgfiles;
        nBlocks = 4; 
        fileSuff = '';
    end

    stimuli = struct();
    for i = 1:length(items) % items (5)
        text = items{i}(1:end-4);
        stimuli(i).text = text;
        stimuli(i).image = imread([imgDir items{i}],'png');
        [stimuli(i).sound, Fs] = audioread([soundDir stimuli(i).text '.wav']);
        stimuli(i).duration = length(stimuli(i).sound)/Fs;
    end

    trials = genTrials(stimuli, conditions, event);

    numTrialsTot = length(items)*nTrials*length(conditions)...
        *length(modality)*nBlocks;

    % Set main data output
    global trialInfo
    trialInfo = struct();
    for i=fieldnames(event)'
        ev = lower(i{:});
        trialInfo.([ev 'Start']) = zeros(1,numTrialsTot);
        trialInfo.([ev 'End']) = zeros(1,numTrialsTot);
    end
    trialInfo.block = zeros(1,numTrialsTot);
    trialInfo.stim = cell(1,numTrialsTot);

    % Create output folder
    c = clock;
    subjectDir = fullfile('data', [subject '_' num2str(c(1)) num2str(c(2)) num2str(c(3)) num2str(c(4)) num2str(c(5))]);
    
    if exist(subjectDir,'dir')
        dateTime=strcat('_',datestr(now,30));
        subjectDir=strcat(subjectDir,dateTime);
        mkdir(subjectDir)
    elseif ~exist(subjectDir,'dir')
        mkdir(subjectDir)
    end
    
    % ready psychtoolbox
    window = init_psychtoolbox(baseCircleDiam);

    % Ready Loop
    while ~KbCheck
        DrawFormattedText(window, 'If you see the cue Yes/No, please say Yes for a word and No for a nonword. \nIf you see the cue Repeat, please repeat the word/nonword. \nPress any key to start. ', 'center', 'center', [1 1 1],58);
        
        % Sleep one millisecond after each check, so we don't
        % overload the system in Rush or Priority > 0
        % Flip to the screen
        Screen('Flip', window);
        WaitSecs(0.001);
    end

    % Block loop
    for iB=startblock:nBlocks
        % Run block and collect data
        filename = fullfile(subjectDir, [subject fileSuff]);
        try
            task_block(iB, trials, nTrials, capturedevID, freqR, ...
                nrchannels, playbackdevID, freqS, window, filename);
        catch e %close PsychPortAudio if error occurs
            PsychPortAudio('close')
            rethrow(e)
        end

        % Write data to file
        Screen('TextSize', window, 50);
        if iB~=nBlocks
            snText = 'Take a short break and press any key to continue';
        else
            snText = 'You are finished, great job!';
        end
        % Break Screen
        while ~KbCheck
            % Sleep one millisecond after each check, so we don't
            % overload the system in Rush or Priority > 0
            % Set the text size
     
            DrawFormattedText(window, snText, 'center', 'center', [1 1 1]);
            % Flip to the screen
            Screen('Flip', window);
            WaitSecs(0.001);
        end
        if iB == nBlocks
            sca
            close all
        end
    end

end
    
function trials = genTrials(stimuli, conditions, events)
% Takes a set of stimuli with varying modalities and conditions and 
% assembles them into a full set of all possible trials 
% 
% Stimuli is a structure where the fieldnames correspond to modalities
%   Accepted modalities include
%   ('text','letters','image','picture','sound','audio')
%   Audio modalities require an additional 'duration' field name
% Conditions is a cell array of possible instruction conditions
% Events is a structure with field names corresponding to event names, and
% a substructure with the required 'duration' field name filled with either
% an integer (for how many seconds) or the corresponding audio modality
% name to make the duration be the length of the audio file. A 'jitter'
% field may also be included for random jittering of timing.
    trials = struct();
    pot_modality = {'text','letters','image','picture','sound','audio'};
    modality = fieldnames(stimuli);
    modality = modality(ismember(fieldnames(stimuli),pot_modality));

    for i = 1:length(stimuli) % items (5)
        text = stimuli(i).text;
        for j=1:length(conditions) % conditions (2)
            for k = 1:length(modality) % modality (3)
                trial = events;
                trial.Cue.stimuli = conditions{j};
                trial.Stimuli.stimuli = stimuli(i).(modality{k});
                if ismember(trial.Stimuli.duration, {'sound','audio'})
                    trial.Stimuli.duration = stimuli(i).duration;
                end
                trial.Stimuli.modality = modality{k};
                trial.Stimuli.item = text;
                trial.Go.stimuli = 'Go';
                trial.Response.stimuli = '';
                trials(k+3*(j-1)).(text) = trial;
            end
        end
    end    
end

function data = task_block(blockNum, trials, reps, recID, freqR, ...
    nrchannels, playbackID, freqS, window, filename)
% function that generates the data for a block of trials
% trials is the structure of stimuli organized by items
% reps is the number of times the stim set is repeated in the block
% recID is the device ID number of the recording device detected by
% psychtoolbox with a recording sampling frequency freqR recorded through
% the number of channels indicated by nrchannels
% playbackID is the device ID number of the sound playing device detected
% by psychtoolbox played at a sampling rate of freqS
% window is the psychtoolbox window created earlier
% items is the stimuli subjects you are using (optional)

    % initialize data
    global trialInfo
    repetitions = 1;
    StartCue = 0;
    WaitForDeviceStart = 1;
    rec = 0;

    % Multiply, shuffle, and jitter trials
    temp = struct2cell(trials);
    block = repmat([temp{:}],[1,reps]); % multiply and stack
    block = block(randperm(length(block))); % shuffle
    for iT = 1:length(block) % jitter
        events = fieldnames(block(iT))';
        for i = events
            event = i{:};
            info = block(iT).(event);
            if any(ismember(fieldnames(info)','jitter'))
                info.duration = info.duration + info.jitter*rand(1,1);
                block(iT).(event) = rmfield(info,'jitter');
            end
        end
    end

    if rec == 1
        % Setup recording!
        %pahandle = PsychPortAudio('Open', [], 1, 1, freq, nrchannels,64);
        pahandle2 = PsychPortAudio('Open', recID, 2, 0, freqR, nrchannels,0, 0.015);
        
        % Preallocate an internal audio recording  buffer with a capacity of 10 seconds:
        PsychPortAudio('GetAudioData', pahandle2, 9000); %nTrials
        
        %PsychPortAudio('Start', pahandle, repetitions, StartCue, WaitForDeviceStart);
        PsychPortAudio('Start', pahandle2, 0, StartCue, WaitForDeviceStart);
    end

    ifi = Screen('GetFlipInterval', window);
    % play tone!
    tone500=audioread(fullfile('Stimuli', 'tone500_3.wav'));
    % tone500=.5*tone500;
    pahandle = PsychPortAudio('Open', playbackID, 1, 2, freqS, nrchannels, 0, 0.015);
    % PsychPortAudio('Volume', pahandle, 1); % volume
    PsychPortAudio('FillBuffer', pahandle, 0.005*tone500');
    PsychPortAudio('Start', pahandle, repetitions, StartCue, WaitForDeviceStart);
    PsychPortAudio('Volume', pahandle, 3);
    toneTimeSecs = (freqS+length(tone500))./freqS; %max(cat(1,length(kig),length(pob)))./freqS;
    toneTimeFrames = ceil(toneTimeSecs / ifi);
    for i=1:toneTimeFrames
        
        DrawFormattedText(window, '', 'center', 'center', [1 1 1]);
        % Flip to the screen
        Screen('Flip', window);
    end
    %
    %while ~kbCheck
    prelat = PsychPortAudio('LatencyBias', pahandle, 0);
    postlat = PsychPortAudio('LatencyBias', pahandle);
    Priority(2);

    % loop through trials
    for iT = 1:length(block)
        if pause_script(window)
            PsychPortAudio('close');
            sca;
            return;
        end
        trial = block(iT);
        % generate trial data
        data = task_trial(trial, window, pahandle, postlat);
        data.block = blockNum;
        trialInfo(iT+(length(block)*(blockNum-1))) = data;
        save([filename '.mat'],"trialInfo",'-mat')
    end
    
    Priority(0);
    if rec == 1
        [audiodata offset overflow tCaptureStart] = PsychPortAudio('GetAudioData', pahandle2);
        audiowrite([filename '_AllTrials.wav'],audiodata,freqR);
        PsychPortAudio('Stop', pahandle2);
        PsychPortAudio('Close', pahandle2);
    end
    
    PsychPortAudio('Stop', pahandle);
    PsychPortAudio('Close', pahandle);
end

function data = task_trial(trial_struct, window, pahandle, postLatencySecs)
% function that presents a Psychtoolbox trial and collects the data
% trial_struct is the trial structure
% Fs is the sampling rate of the sound (optional)
    ifi = Screen('GetFlipInterval', window);
    events = fieldnames(trial_struct);
    %data = struct();
    %data.block = 0; % placeholder for assignment outside of function
    % image presentation rectangles
    smImSq = [0 0 500 400];
    rect = Screen('rect',window);
    [smallIm, ~, ~] = CenterRect(smImSq, rect);
    waitframes = ceil((2 * postLatencySecs) / ifi) + 1;
    for i = events'
        event = lower(i{:});
        data.([event 'Start']) = GetSecs;
        stage = trial_struct.(i{:});
        frames = ceil(stage.duration/ifi);
        stim = stage.stimuli;
        if ischar(stim)
            func = @DrawFormattedText;
            inp = {window, stim, 'center', 'center', [1 1 1]};
            data.stim = stim;
        elseif any(strcmp(stage.modality, {'sound', 'audio'}))
            DrawFormattedText(window, '', 'center', 'center', [1 1 1]);
            PsychPortAudio('FillBuffer', pahandle, stim(:,1)');
            tWhen = GetSecs + (waitframes - 0.5)*ifi;
            tPredictedVisualOnset = PredictVisualOnsetForTime(window, tWhen);
            data.([event 'Start']) = PsychPortAudio('Start', pahandle, ...
                1, tPredictedVisualOnset, 1);
            func = @DrawFormattedText;
            inp = {window, '', 'center', 'center', [1 1 1]};
            data.stim = [stage.item '.wav'];
        elseif any(strcmp(stage.modality, {'image', 'picture'}))
            texture = Screen('MakeTexture',window,stim);
            func = @Screen;
            inp = {'DrawTexture', window, texture, [], smallIm};
            data.stim = [stage.item '.PNG'];
        else
            error("Trial struct %s not formatted correctly",event)
        end

        % Run Trial
        for j = 1:frames
            func(inp{:});
            Screen('Flip', window);
        end
        data.([event 'End']) = GetSecs;
    end
end

function window = init_psychtoolbox(baseCircleDiam)

    % Initialize Sounddriver
    InitializePsychSound(1);

    % Screen Setup
    PsychDefaultSetup(2);
    % Get the screen numbers
    screens = Screen('Screens');
    % Select the external screen if it is present, else revert to the 
    % native screen
    screenNumber = max(screens);
    % Define black, white and grey
    black = BlackIndex(screenNumber);
    white = WhiteIndex(screenNumber);
    grey = white / 2;
    % Open an on screen window and color it grey
    [window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);

    % Set the blend funnction for the screen
    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    % Get the size of the on screen window in pixels
    [screenXpixels, screenYpixels] = Screen('WindowSize', window);
    % Get the centre coordinate of the window in pixels
    [xCenter, yCenter] = RectCenter(windowRect);
    % Set the text size
    Screen('TextSize', window, 50);

    % Circle stuff for photodiode
    baseCircle = [0 0 baseCircleDiam baseCircleDiam];
    %centeredCircle = CenterRectOnPointd(baseCircle, screenXpixels-0.5*baseCircleDiam, screenYpixels-0.5*baseCircleDiam); %
    centeredCircle = CenterRectOnPointd(baseCircle, screenXpixels-0.5*baseCircleDiam, 1+0.5*baseCircleDiam); %
    circleColor1 = [1 1 1]; % white
    circleColor2 = [0 0 0]; % black
    % Query the frame duration
end