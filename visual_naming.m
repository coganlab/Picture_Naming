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
    nBlocks = 4; % 10
    nTrials = 100;
    freqS = 44100;
    
    if practice==1
        nTrials = 12; %12
        nBlocks = 1;
        fileSuff = '_Pract';
    end

    event = struct( ...
        'Cue', struct('duration',2,'jitter',0.25), ...
        'Stimuli', struct('duration','sound','jitter',0.25), ...
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
    ifi = Screen('GetFlipInterval', window);
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
    for iB=iBStart:nBlocks
        % Run block and collect data
        data = task_block(iB, nTrials, stimuli, cond, event);

        % Write data to file
        save([subjectDir '/' iB],"data",'-mat')
    end

end
    

function data = task_block(block_num, n_trials, Stimuli, cond, event)
% function that generates the data for a block of trials
% block_num is the block number
% n_trials is the number of trials in the block
% Stimuli is the stimuli for the block

    % initialize data
    data = [];

    % Generate trials by shuffling stimuli and jittering timing
    
    
    stim_table = reshape(struct2cell(stimuli),[3,5]);
    % loop through trials
    for iT = 1:n_trials
        trial = trials(iT);
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
end