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
    freqR = 44100; % 20000 doesn't work?
    [playbackdevID,capturedevID] = getDevices;
    baseCircleDiam=75;
    StartCue = 0;
    WaitForDeviceStart = 1;
    rec = 1;
    soundDir = "Stimuli" + filesep + "sounds" + filesep;
    imgDir = "Stimuli" + filesep + "pictures" + filesep;
    conditions = {imgDir + "circle_green.png", imgDir + "circle_red.png"};
    rng('shuffle');
    
    if practice==1
        items = ["apple" "duck"]; % 2 items
        nBlocks = 2;
        fileSuff = '_Pract';
    else
        items = ["apple" "duck" "spoon" "star" "umbrella"];
        nBlocks = 4; 
        fileSuff = '';
    end
    
    stims = cellstr([ ...
        items, ... % text
        imgDir+items+".PNG", ... % picture
        soundDir+items+".wav" ... % sound
        ]);

    events = struct( ...
        'Cue', struct('duration',2,'jitter',0.25,'shows',conditions), ...
        'Stimuli', struct('duration',1,'shows',stims), ...
        'Delay', struct('duration',2,'jitter',0.25), ...
        'Go', struct('duration',1,'jitter',0.25,'shows','Speak', ...
            'skip',"Cue.shows == '" + conditions{2} + "'"), ...
        'Response', struct('duration',3,'jitter',0.25, ...
            'skip',"Cue.shows == '" + conditions{2} + "'"));

    if ispc
        Screen('Preference', 'SkipSyncTests', 1);
    end

    sca;
    
    if ~exist('startblock','var')
        startblock = 1;
    end

    % Set main data output
    global trialInfo %#ok<GVMIS> 
    trialInfo = {};

    % Create output folder
    c = clock;
    subjectDir = fullfile('data', [subject '_' num2str(c(1)) ...
        num2str(c(2)) num2str(c(3)) num2str(c(4)) num2str(c(5))]);
    filename = fullfile(subjectDir, [subject fileSuff]);
    
    if exist(subjectDir,'dir')
        dateTime=strcat('_',datestr(now,30));
        subjectDir=strcat(subjectDir,dateTime);
        mkdir(subjectDir)
    elseif ~exist(subjectDir,'dir')
        mkdir(subjectDir)
    end
    
    % ready psychtoolbox
    [win, centeredCircle] = init_psychtoolbox(baseCircleDiam);

    % Ready Loop
    while ~KbCheck
        DrawFormattedText(win, 'If you see the cue Yes/No, please say Yes for a word and No for a nonword. \nIf you see the cue Repeat, please repeat the word/nonword. \nPress any key to start. ', 'center', 'center', [1 1 1],58);
        
        % Sleep one millisecond after each check, so we don't
        % overload the system in Rush or Priority > 0
        % Flip to the screen
        Screen('Flip', win);
        WaitSecs(0.001);
    end

    % Block loop
    for iB=startblock:nBlocks
        
        % Generate, Multiply, shuffle, and jitter trials
        trials = gen_trials(events, nTrials);

        try
            % Initialize audio devices
            rechandle = NaN;
            [pahandle, rechandle] = audio_init(win, ...
                playbackdevID, freqS, nrchannels, StartCue, ...
                WaitForDeviceStart, rec, capturedevID, freqR);
               
            % run task block
            [~, to_exit] = task_block(iB, trials, pahandle, win, ...
                filename, centeredCircle);
        catch e % close and save PsychPortAudio if error occurs
            audio_conclude(rechandle, iB, filename)
            rethrow(e)
        end
        audio_conclude(rechandle, iB, filename)

        % close if chose to exit
        if to_exit
            return
        end

        % Break Screen
        Screen('TextSize', win, 50);
        
        if iB~=nBlocks
            snText = 'Take a short break and press any key to continue';
        else
            snText = 'You are finished, great job!';
        end
        while ~KbCheck
            % Sleep one millisecond after each check, so we don't
            % overload the system in Rush or Priority > 0
            % Set the text size
     
            DrawFormattedText(win, snText, 'center', 'center', [1 1 1]);
            % Flip to the screen
            Screen('Flip', win);
            WaitSecs(0.001);
        end
        if iB == nBlocks
            sca
            close all
        end
    end
end
    
function [pahandle, rechandle] = audio_init(win, playbackID,...
    freqS, nrchannels, StartCue, WaitForDeviceStart, rec, recID, freqR)

    repetitions = 1;
    if ~exist('rec','var') || rec == 0
        rechandle = NaN;
    else
        % Setup recording!
        %pahandle = PsychPortAudio('Open', [], 1, 1, freq, nrchannels,64);
        rechandle = PsychPortAudio('Open', recID, 2, 0, freqR, nrchannels,0, 0.015);
        % Preallocate an internal audio recording  buffer with a capacity of 10 seconds:
        PsychPortAudio('GetAudioData', rechandle, 9000); %nTrials
        
        %PsychPortAudio('Start', pahandle, repetitions, StartCue, WaitForDeviceStart);
        PsychPortAudio('Start', rechandle, 0, StartCue, WaitForDeviceStart);
    end

    ifi = Screen('GetFlipInterval', win);
    % play tone!
    tone500=audioread(fullfile('Stimuli', 'tone500_3.wav'));
    % tone500=.5*tone500;
    pahandle = PsychPortAudio('Open', playbackID, 1, 2, freqS, nrchannels, 0, 0.015);
    % PsychPortAudio('Volume', pahandle, 1); % volume
    PsychPortAudio('FillBuffer', pahandle, 0.005*tone500');
    PsychPortAudio('Start', pahandle, repetitions, StartCue, WaitForDeviceStart);
    PsychPortAudio('Volume', pahandle, 3);
    toneTimeSecs = (freqS+length(tone500))./freqS; 
    toneTimeFrames = ceil(toneTimeSecs / ifi);
    for i=1:toneTimeFrames
        
        DrawFormattedText(win, '', 'center', 'center', [1 1 1]);
        % Flip to the screen
        Screen('Flip', win);
    end
    %
    %while ~kbCheck
    prelat = PsychPortAudio('LatencyBias', pahandle, 0);
    disp("Prelatency is " + num2str(prelat))
    Priority(2);
end

function audio_conclude(rechandle, iB, filename)
% write audio data if neccessary and then close the audio devices
    if ~isnan(rechandle)
        [audiodata,~,~,~] = PsychPortAudio('GetAudioData', rechandle);
        status = PsychPortAudio('GetStatus', rechandle);
        audioname = filename+"_Block_"+num2str(iB)+".wav";
        audiowrite(audioname,audiodata,status.SampleRate);
    end
    PsychPortAudio('close')
end

function [data, to_exit] = task_block(blockNum, block, pahandle, win, ...
    filename, centeredCircle)
% function that generates the data for a block of trials
% trials is the structure of stimuli organized by items
% recID is the device ID number of the recording device detected by
% psychtoolbox with a recording sampling frequency freqR recorded through
% the number of channels indicated by nrchannels
% playbackID is the device ID number of the sound playing device detected
% by psychtoolbox played at a sampling rate of freqS
% window is the psychtoolbox window created earlier
% items is the stimuli subjects you are using (optional)

    % initialize data
    global trialInfo %#ok<GVMIS> 
    data = [];

    % loop through trials
    for iT = 1:length(block)
        to_exit = pause_script(win);
        if to_exit
            PsychPortAudio('close');
            sca;
            return
        end
        trial = block{iT};
        % generate trial data
        data = task_trial(trial, win, pahandle, centeredCircle);
        data.block = blockNum;
        trialInfo{iT+(length(block)*(blockNum-1))} = data;
        save([filename '.mat'],"trialInfo",'-mat')
    end
    
    Priority(0);

end

function data = task_trial(trial_struct, win, pahandle, centeredCircle)
% function that presents a Psychtoolbox trial and collects the data
% trial_struct is the trial structure
% Fs is the sampling rate of the sound (optional)
    ifi = Screen('GetFlipInterval', win);
    events = fieldnames(trial_struct);

    % image presentation rectangles
    postLatencySecs = PsychPortAudio('LatencyBias', pahandle);
    waitframes = ceil((2 * postLatencySecs) / ifi) + 1;
    for i = events'
        event = lower(i{:});
        data.([event 'Start']) = GetSecs;
        stage = trial_struct.(i{:});
        frames = ceil(stage.duration/ifi);
        stim = stage.shows;
        if ischar(stim)
            func = @() DrawFormattedText(win, stim, 'center', ...
                'center', [1 1 1]);
            stimmy = stim;
        elseif any(strcmp(stage.type, {'sound', 'audio'}))
            DrawFormattedText(win, '', 'center', 'center', [1 1 1]);
            PsychPortAudio('FillBuffer', pahandle, stim(:,1)');
            tWhen = GetSecs + (waitframes - 0.5)*ifi;
            tPredictedVisualOnset = PredictVisualOnsetForTime(win, tWhen);
            data.([event 'Start']) = PsychPortAudio('Start', pahandle, ...
                1, tPredictedVisualOnset, 1);
            func = @() DrawFormattedText(win, '', 'center', ...
                'center', [1 1 1]);
            stimmy = [stage.item '.wav'];
        elseif any(strcmp(stage.type, {'image', 'picture'}))
            texture = Screen('MakeTexture',win,stim);
            func = @() Screen('DrawTexture', win, texture, []);
            stimmy = [stage.item '.PNG'];
        else
            error("Trial struct %s not formatted correctly",event)
        end

        % Run Trial
        Screen('TextSize', win, 100);
        for j = 1:frames
            if strcmp(event, "stimuli") && j <= 3
                Screen('FillOval', win, [1,1,1], centeredCircle, 75);
                data.stim = stimmy;
            end
            func();
            Screen('Flip', win);
        end
        data.([event 'End']) = GetSecs;
    end
end


function [win, centeredCircle] = init_psychtoolbox(baseCircleDiam)

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
    [win, windowRect] = PsychImaging('OpenWindow', screenNumber, black);

    % Set the blend funnction for the screen
    Screen('BlendFunction', win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    % Get the size of the on screen window in pixels
    [screenXpixels, screenYpixels] = Screen('WindowSize', win);
    % Get the centre coordinate of the window in pixels
    [xCenter, yCenter] = RectCenter(windowRect);
    % Set the text size
    Screen('TextSize', win, 50);

    % Circle stuff for photodiode
    baseCircle = [0 0 baseCircleDiam baseCircleDiam];
    %centeredCircle = CenterRectOnPointd(baseCircle, screenXpixels-0.5*baseCircleDiam, screenYpixels-0.5*baseCircleDiam); %
    centeredCircle = CenterRectOnPointd(baseCircle, screenXpixels-0.5*baseCircleDiam, 1+0.5*baseCircleDiam); %
    circleColor1 = [1 1 1]; % white
    circleColor2 = [0 0 0]; % black
    % Query the frame duration
end