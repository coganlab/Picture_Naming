%% Visual Naming Task

function visual_naming(subject, practice, startblock)
arguments
    subject string
    practice double = 0
    startblock double = 1
end
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
    
    %% Initialize values
    nrchannels = 1; % number of channels in the recording and playback devices
    freqS = 44100; % sampling frequency of the playback device
    freqR = 44100; % sampling frequency of the recording device
    [playbackdevID,capturedevID] = getDevices; % grabs device IDs
    baseCircleDiam=75; % diameter of the trigger circle
    StartCue = 0; % startcue setting for psychtoolbox
    WaitForDeviceStart = 1; % whether to halt playback until device starts
    rec = 0; % whether or not to record
    toneVol = 0.003; % volume of the starting tone
    soundDir = "Stimuli" + filesep + "sounds" + filesep; % sound file directory
    imgDir = "Stimuli" + filesep + "pictures" + filesep; % image file directory
    backgroundColor = 'white';
    
    % setting up trials structure
    if practice==1
        items = ["apple" "duck"]; % 2 items
        nBlocks = 1;
        fileSuff = '_Pract';
        nTrials1 = 1; % real number is nTrials X items X 6
        nTrials2 = 1; % real number is nTrials X items X 6
        trim = 4;
    else
        items = ["apple" "duck" "star" "umbrella"];
        nBlocks = 5; 
        fileSuff = '';
        nTrials1 = 4; % real number is nTrials X items X 6
        nTrials2 = 2; % real number is nTrials X items X 6
        trim = 0;
    end
    
    conditions = {imgDir + "circle_green.png", ... % 'repeat' cue
        imgDir + "circle_red.png"}; % 'just listen' cue
    stims = cellstr([items, ...  % text
        imgDir+items+".PNG", ... % picture
        soundDir+items+".wav"]); % sound

    events1 = struct( ...
        'Cue', struct('duration',0.5,'shows',conditions(1)), ...
        'Wait', struct('duration',0.75,'jitter',0.25), ...
        'Stimuli', struct('duration',1,'shows',stims), ...
        'Delay', struct('duration',1,'jitter',0.25), ...
        'Go', struct('duration',0.5,'shows','Speak'), ...
        'Response', struct('duration',1.75),...
        'iti', struct('duration',1.25,'jitter',0.25));

    events2 = struct( ...
        'Cue', struct('duration',0.5,'shows',conditions(2)), ...
        'Wait', struct('duration',0.75,'jitter',0.25), ...
        'Stimuli', struct('duration',1,'shows',stims), ...
        'Delay', struct('duration',1,'jitter',0.25), ...
        'iti', struct('duration',1.25,'jitter',0.25));
    
    %% Set main data output
    global trialInfo 
    trialInfo = {};

    % Create output folder/files
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

     % Custom tsv file
    BIDS_out = {'onset','duration','trial_num','trial_type','stim_file','block'};
    writecell(BIDS_out,[filename '.csv'],'FileType','text','Delimiter',',')
    
    %% ready psychtoolbox
    % set global (immutable!) params relating to screen properties
    sca;
    global centeredCircle
    global txtclr
    global win
    [win, centeredCircle, txtclr] = init_psychtoolbox(baseCircleDiam, backgroundColor);

    % Ready
    prompt(char("If you see a red circle, just listen. If you see a " + ...
        "green circle, please repeat when the word 'Speak' appears o" + ...
        "n the screen. Press the space bar to begin."),58);

    %% Block loop
    for iB=startblock:nBlocks
        
        % Generate, Multiply, shuffle, and jitter trials
        trials1 = gen_trials(events1, nTrials1,1,trim);
        trials2 = gen_trials(events2, nTrials2,1,trim);
        trials = [trials1; trials2];
        trials = trials(randperm(length(trials)));
            
        try
            % Initialize audio devices
            rechandle = NaN;
            [pahandle, rechandle] = audio_init(playbackdevID, freqS, ...
                toneVol, nrchannels, StartCue, ...
                WaitForDeviceStart, rec, capturedevID, freqR);

            % run task block
            [~, to_exit] = task_block(iB, trials, pahandle, filename);
        catch e % close and save PsychPortAudio if error occurs
            audio_conclude(rechandle, iB, filename)
            rethrow(e)
        end
        audio_conclude(rechandle, iB, filename)

        % Block end prompt
        Screen('TextSize', win, 50);
        if to_exit % close if chose to exit
            sca;
            return
        elseif iB~=nBlocks % Break screen
            prompt('Take a short break and press any key to continue');
        else
            prompt('You are finished, great job!');
            sca;
        end
    end
end

function [data, to_exit] = task_block(blockNum, block, pahandle, filename)
% function that runs a trials block through psychtoolbox and generates data
% from the experiment. Output can be either a global 'trialInfo' variable
% or the first output of this function 'data'.

    % initialize data
    global trialInfo 
    global win
    data = [];

    % loop through trials
    for iT = 1:length(block)
        to_exit = pause_script(win);
        if to_exit
            return
        end
        trial = block{iT};
        % generate trial data
        [data, BIDS_out] = task_trial(trial, pahandle);
        data.block = blockNum;
        trialInfo{iT+(length(block)*(blockNum-1))} = data;
        save([filename '.mat'],"trialInfo",'-mat')
        
        % Set out data
        [BIDS_out{cellfun('isempty',BIDS_out)}] = deal('n/a');
        BIDS_out(:,6) = {blockNum};
        writecell(BIDS_out,[filename '.csv'],'FileType','text','Delimiter',',','WriteMode','append')
    end
    
    Priority(0);

end

function [data, events_out] = task_trial(trial_struct, pahandle)
% function that presents a Psychtoolbox trial and collects the data
% trial_struct is the trial structure
    global trialInfo
    global centeredCircle
    global txtclr
    global win
    ifi = Screen('GetFlipInterval', win);
    events = fieldnames(trial_struct);

    % image presentation rectangles
    postLatencySecs = PsychPortAudio('LatencyBias', pahandle);
    waitframes = ceil((2 * postLatencySecs) / ifi) + 1;
    events_out = {};
    if any(strcmp(events','Response'))
        data.condition = 'ListenSpeak';
    else
        data.condition = 'JustListen';
    end
    for i = events'
        event = lower(i{:});
        data.([event 'Start']) = GetSecs;
        stage = trial_struct.(i{:});
        frames = round(stage.duration/ifi);
        stim = stage.shows;
        if ischar(stim)
            func = @() DrawFormattedText(win, stim, 'center', 'center',...
                txtclr);
            stimmy = stim;
        elseif any(strcmp(stage.type, {'sound', 'audio'}))
            DrawFormattedText(win, '', 'center', 'center', txtclr);
            Screen('FillOval', win, txtclr, centeredCircle);
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
                txtclr);
            stimmy = stage.item + ".wav";
        elseif any(strcmp(stage.type, {'image', 'picture'}))
            if strcmp(event, "stimuli") && all(txtclr == [1 1 1])
                stim = imcomplement(stim);
            end
            texture = Screen('MakeTexture',win,stim);
            func = @() Screen('DrawTexture', win, texture, []);
            stimmy = stage.item + ".png";
        else
            error("Trial struct %s not formatted correctly",event)
        end

        % Run Trial
        Screen('TextSize', win, 100);
        for j = 1:frames
            if strcmp(event, "stimuli") && j <= 3
                Screen('FillOval', win, txtclr, centeredCircle);
                data.stim = stimmy;
                data.trialnum = length(trialInfo) + 1;
                data.modality = stage.type;
            end
            func();
            Screen('Flip', win);
        end
        data.([event 'End']) = GetSecs;
        

        % BIDS output stuff
        j = height(events_out)+1;
        events_out(j,:) = {data.([event 'Start']), ...
            data.([event 'End']) - data.([event 'Start']), ...
            length(trialInfo)+1, event, stimmy};
    end
end

function prompt(message, wrap)
% function that temporarily halts the experiment and gives the user a text
% prompt. The user can continue the experiment by pressing any key.
    global txtclr
    global win
    if ~exist('wrap','var')
        wrap=[];
    end
    while ~KbCheck
        % Sleep one millisecond after each check, so we don't
        % overload the system in Rush or Priority > 0
        % Set the text size

        DrawFormattedText(win, message, 'center', 'center', txtclr, wrap);
        % Flip to the screen
        Screen('Flip', win);
        WaitSecs(0.001);
    end
end

%% PsychToolBox settings functions

function [win, centeredCircle, textclr] = init_psychtoolbox(baseCircleDiam, clr)
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
    if any(strcmp(["white","grey"],clr))
        textclr = scrnClr.('black');
    elseif strcmp("black",clr)
        textclr = scrnclr.('white');
    else
        error("Possible background color presets are white, grey, and black")
    end
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

function [pahandle, rechandle] = audio_init( playbackID, freqS, ...
    toneVol, nrchannels, StartCue, WaitForDeviceStart, rec, recID, freqR)
% Initializes the audio device startup and presets which device will record
% and which will provide playback
    global win

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
        
        DrawFormattedText(win, '', 'center', 'center', []);
        % Flip to the screen
        Screen('Flip', win);
    end

    prelat = PsychPortAudio('LatencyBias', pahandle, 0);
    disp("Prelatency is " + num2str(prelat))
    Priority(2);
end

function audio_conclude(rechandle, iB, filename)
% write audio data if neccessary and then close the audio devices
    global txtclr
    global win
    if ~isnan(rechandle)
        DrawFormattedText(win,'Saving...','center','center',txtclr);
        Screen('Flip', win);
        [audiodata,~,~,~] = PsychPortAudio('GetAudioData', rechandle);
        status = PsychPortAudio('GetStatus', rechandle);
        audioname = filename+"_Block_"+num2str(iB)+".wav";
        audiowrite(audioname,audiodata,status.SampleRate);
    end
    PsychPortAudio('close')
end