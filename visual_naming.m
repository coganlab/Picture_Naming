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

    sca;
    soundDir = 'Stimuli/sounds/';
    imgDir = 'Stimuli/pictures/';
    
    if ~exist('startblock','var')
        startblock = 1;
    end
    
    % Load the stimuli
    imgfiles = dir(imgDir);
    imgfiles = {imgfiles.name};
    imgfiles = imgfiles(3:end);
    stimuli = struct();
    conditions = {'Repeat',':=:'};
    modality = {'text','image','sound'};
    for i = 1:length(imgfiles) % items (5)
        text = imgfiles{i}(1:end-4);
        stimuli(i).text = text;
        stimuli(i).image = imread([imgDir imgfiles{i}]);
        [stimuli(i).sound, Fs] = audioread([soundDir stimuli(i).text '.wav']);
        stimuli(i).duration = length(stimuli(i).sound)/Fs;
    end
    % Initialize values
    nBlocks = 4; 
    nTrials = 100;
    freqS = 44100;
    
    if practice==1
        nTrials = 12; % 2 items
        nBlocks = 1;
        fileSuff = '_Pract';
    end

    event = struct( ...
        'Cue', struct('duration',2,'jitter',0.25), ...
        'Stimuli', struct('duration','sound'), ...
        'Go', struct('duration',1,'jitter',0.25), ...
        'Response', struct('duration',3,'jitter',0.25));

    trials = genTrials(stimuli, conditions, event);

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
    window = init_psychtoolbox();
    ifi = Screen('GetFlipInterval', window);

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
        data = task_block(trials, 5);

        % Write data to file
        save([subjectDir '/' iB],"data",'-mat')
    end

end
    

function data = task_block(trials, reps, items)
% function that generates the data for a block of trials
% trials is the structure of stimuli organized by items
% reps is the number of times the stim set is repeated in the block
% items is the stimuli subjects you are using (optional)

    % initialize data
    data = [];
    block = [];
    if exist('items','var')
        non_items = setdiff(items,fieldnames(trials));
        trials = rmfield(trials,non_items);
    else
        items = fieldnames(trials);
    end

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
    
    % Setup recording!
    %pahandle = PsychPortAudio('Open', [], 1, 1, freq, nrchannels,64);
    pahandle2 = PsychPortAudio('Open', capturedevID, 2, 0, freqR, nrchannels,0, 0.015);
    
    % Preallocate an internal audio recording  buffer with a capacity of 10 seconds:
    PsychPortAudio('GetAudioData', pahandle2, 9000); %nTrials
    
    %PsychPortAudio('Start', pahandle, repetitions, StartCue, WaitForDeviceStart);
    PsychPortAudio('Start', pahandle2, 0, 0, 1);
    
    % play tone!
    tone500=audioread('c:\psychtoolbox_scripts\Lexical_Passive\stim\tone500_3.wav');
    % tone500=.5*tone500;
    pahandle = PsychPortAudio('Open', playbackdevID, 1, 2, freqS, nrchannels,0, 0.015);
    % PsychPortAudio('Volume', pahandle, 1); % volume
    PsychPortAudio('FillBuffer', pahandle, 0.005*tone500');
    PsychPortAudio('Start', pahandle, repetitions, StartCue, WaitForDeviceStart);
    PsychPortAudio('Volume', pahandle, 0.5);
    toneTimeSecs = (freqS+length(tone500))./freqS; %max(cat(1,length(kig),length(pob)))./freqS;
    toneTimeFrames = ceil(toneTimeSecs / ifi);
    for i=1:toneTimeFrames
        
        DrawFormattedText(window, '', 'center', 'center', [1 1 1]);
        % Flip to the screen
        Screen('Flip', window);
    end
    %
    %while ~kbCheck
    ifi_window = Screen('GetFlipInterval', window);
    suggestedLatencySecs = 0.015;
    waitframes = ceil((2 * suggestedLatencySecs) / ifi_window) + 1;
    prelat = PsychPortAudio('LatencyBias', pahandle, 0) %#ok<NOPRT,NASGU>
    postlat = PsychPortAudio('LatencyBias', pahandle);
    Priority(2);

    % loop through trials
    for iT = 1:length(block)
        trial = block(iT);
        % generate trial data
        data(iT) = task_trial(trial);
    end
    % Break Screen
    Screen('TextSize', window, 50);
    while ~KbCheck
        % Sleep one millisecond after each check, so we don't
        % overload the system in Rush or Priority > 0
        % Set the text size
 
        DrawFormattedText(window, 'Take a short break and press any key to continue', 'center', 'center', [1 1 1]);
        % Flip to the screen
        Screen('Flip', window);
        WaitSecs(0.001);
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
                trial.Go.stimuli = "Go";
                trial.Response.stimuli = "";
                trials(k+3*(j-1)).(text) = trial;
            end
        end
    end    
end


function data = task_trial(trial_struct)
% function that presents a Psychtoolbox trial and collects the data
% trial_struct is the trial structure
% Fs is the sampling rate of the sound (optional)
    events = fielednames(trial_struct);
    for i = events
        event = i{:};
        info = trial_struct.(event);
        if strcmp(info.duration, {'sound','audio'})
            info.duration = info.duration;
        end
    end
end

function window = init_psychtoolbox()

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
    baseCircleDiam=75;
    baseCircle = [0 0 baseCircleDiam baseCircleDiam];
    %centeredCircle = CenterRectOnPointd(baseCircle, screenXpixels-0.5*baseCircleDiam, screenYpixels-0.5*baseCircleDiam); %
    centeredCircle = CenterRectOnPointd(baseCircle, screenXpixels-0.5*baseCircleDiam, 1+0.5*baseCircleDiam); %
    circleColor1 = [1 1 1]; % white
    circleColor2 = [0 0 0]; % black
    % Query the frame duration
end