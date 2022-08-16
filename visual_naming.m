%% Visual Naming Task

function visual_naming(subject, practice, startblock)
% A function that runs a visual naming task in pyschtoolbox.
%
% The task is to name the objects in the image, word, or sound
%
% The task is divided into blocks. 
% Each block is divided into trials.
% Each trial is divided into four events:
%   1. Cue
%   2. Stimuli
%   (2.5 Delay?)
%   3. Go
%   4. Response
    
    rng('shuffle');
    if ispc
        Screen('Preference', 'SkipSyncTests', 1);
    end
    if ~exist('startblock','var')
        startblock = 1;
    end
    
    %% Initialize values
    nTrials = 1; % real number is nTrials X items X 6
    nrchannels = 1; % number of channels in the recording and playback devices
    freqS = 44100; % sampling frequency of the playback device
    freqR = 44100; % sampling frequency of the recording device
    [playbackdevID,capturedevID] = getDevices; % grabs device IDs
    baseCircleDiam=75; % diameter of the trigger circle
    StartCue = 0; % startcue setting for psychtoolbox
    WaitForDeviceStart = 1; % whether to halt playback until device starts
    rec = 1; % whether or not to record
    toneVol = 0.003; % volume of the starting tone
    soundDir = "Stimuli" + filesep + "sounds" + filesep; % sound file directory
    imgDir = "Stimuli" + filesep + "pictures" + filesep; % image file directory
    
    % setting up trials structure
    if practice==1
        items = ["apple" "duck"]; % 2 items
        nBlocks = 1;
        fileSuff = '_Pract';
    else
        items = ["apple" "duck" "spoon" "star" "umbrella"];
        nBlocks = 4; 
        fileSuff = '';
    end
    
    conditions = {imgDir + "circle_green.png", ... % 'repeat' cue
        imgDir + "circle_red.png"}; % 'just listen' cue
    stims = cellstr([items, ...  % text
        imgDir+items+".PNG", ... % picture
        soundDir+items+".wav"]); % sound

    events = struct( ...
        'Cue', struct('duration',0.75,'jitter',0.25,'shows',conditions), ...
        'Stimuli', struct('duration',1,'shows',stims), ...
        'Delay', struct('duration',2,'jitter',0.25), ...
        'Go', struct('duration',0.75,'jitter',0.25,'shows','Speak', ...
            'skip',"Cue.shows == '" + conditions{2} + "'"), ...
        'Response', struct('duration',3,'jitter',0.25, ...
            'skip',"Cue.shows == '" + conditions{2} + "'"),...
        'iti', struct('duration',0.25,'jitter',0.25));

    %% Set main data output
    global trialInfo 
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
    
    %% ready psychtoolbox
    sca;
    [win, centeredCircle] = init_psychtoolbox(baseCircleDiam, 'black');

    % Ready Loop
    while ~KbCheck
        DrawFormattedText(win, 'If you see the cue Yes/No, please say Yes for a word and No for a nonword. \nIf you see the cue Repeat, please repeat the word/nonword. \nPress any key to start. ', 'center', 'center', [1 1 1],58);
        
        % Sleep one millisecond after each check, so we don't
        % overload the system in Rush or Priority > 0
        % Flip to the screen
        Screen('Flip', win);
        WaitSecs(0.001);
     end

    %% Block loop
    for iB=startblock:nBlocks
        
        % Generate, Multiply, shuffle, and jitter trials
        trials = gen_trials(events, nTrials);

        try
            % Initialize audio devices
            rechandle = NaN;
            [pahandle, rechandle] = audio_init(win, ...
                playbackdevID, freqS, toneVol, nrchannels, StartCue, ...
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
            sca;
            close all;
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
            sca;
            close all;
            return
        end
    end
end

function [data, to_exit] = task_block(blockNum, block, pahandle, win, ...
    filename, centeredCircle)
% function that runs a trials block through psychtoolbox and generates data
% from the experiment. Output can be either a global 'trialInfo' variable
% or the first output of this function 'data'.

    % initialize data
    global trialInfo 
    data = [];

    % loop through trials
    for iT = 1:length(block)
        to_exit = pause_script(win);
        if to_exit
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
    ifi = Screen('GetFlipInterval', win);
    events = fieldnames(trial_struct);

    % image presentation rectangles
    postLatencySecs = PsychPortAudio('LatencyBias', pahandle);
    waitframes = ceil((2 * postLatencySecs) / ifi) + 1;
    for i = events'
        event = lower(i{:});
        data.([event 'Start']) = GetSecs;
        stage = trial_struct.(i{:});
        frames = round(stage.duration/ifi);
        stim = stage.shows;
        if ischar(stim)
            func = @() DrawFormattedText(win, stim, 'center', 'center',...
                [1 1 1]);
            stimmy = stim;
        elseif any(strcmp(stage.type, {'sound', 'audio'}))
            DrawFormattedText(win, '', 'center', 'center', [1 1 1]);
            PsychPortAudio('FillBuffer', pahandle, stim(:,1)');
            tWhen = GetSecs + (waitframes - 0.5)*ifi;
            tPredictedVisualOnset = PredictVisualOnsetForTime(win, tWhen);
            PsychPortAudio('Start', pahandle, 1, tPredictedVisualOnset, 0);
            [~,trigFlipOn] = Screen('Flip', win, tWhen);
            offset = 0;
            while offset == 0
                status = PsychPortAudio('GetStatus', pahandle);
                offset = status.PositionSecs;
                WaitSecs('YieldSecs', 0.001);
            end

            data.([event 'Start']) = status.StartTime;
            data.([event 'AlignedTrigger']) = trigFlipOn;
            func = @() DrawFormattedText(win, '', 'center', 'center',...
                [1 1 1]);
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
                Screen('FillOval', win, [1,1,1], centeredCircle);
                data.stim = stimmy;
            end
            func();
            Screen('Flip', win);
        end
        data.([event 'End']) = GetSecs;
    end
end

%% PsychToolBox settings functions

function [win, centeredCircle] = init_psychtoolbox(baseCircleDiam, clr)
% Initialize and start Psychtoolbox. This function applies screen/window
% setup with most settings predetermined, but with a few inputs.

    if ~exist('clr','var')
        clr = 'black';
    end

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
    % Create option struct
    scrnClr = struct('black',black,'white',white,'grey',grey);
    % Open an on screen window and color it grey
    [win, ~] = PsychImaging('OpenWindow', screenNumber, scrnClr.(clr));

    % Set the blend funnction for the screen
    Screen('BlendFunction', win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    % Get the size of the on screen window in pixels
    [screenXpixels, ~] = Screen('WindowSize', win);
    % Set the text size
    Screen('TextSize', win, 50);

    % Circle stuff for photodiode
    baseCircle = [0 0 baseCircleDiam baseCircleDiam];
    %centeredCircle = CenterRectOnPointd(baseCircle, screenXpixels-0.5*baseCircleDiam, screenYpixels-0.5*baseCircleDiam); %
    centeredCircle = CenterRectOnPointd(baseCircle, screenXpixels-0.5*baseCircleDiam, 1+0.5*baseCircleDiam); %
end

function [pahandle, rechandle] = audio_init(win, playbackID, freqS, ...
    toneVol, nrchannels, StartCue, WaitForDeviceStart, rec, recID, freqR)
% Initializes the audio device startup and presets which device will record
% and which will provide playback

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
    PsychPortAudio('FillBuffer', pahandle, toneVol*tone500');
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