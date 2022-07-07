function visual_naming(subject, pediatric, practice, startblock)
% startblock,
% A function that runs a visual naming task in pyschtoolbox.
%
% The task is to name the objects in the image.
%
% The task is divided into three phases:
%   1. Fixation
%   2. Stimulus
%   3. Response
%
% The task is divided into blocks. Each block is divided into trials.
    sca;
    soundDir = 'Stimuli/sounds/';
    if pediatric == 1
        imgDir = 'Stimuli/pictures/pediatric/';
    else
        imgDir = 'Stimuli/pictures/adult/';
    end
    
    if ~exist('startblock','var')
        startblock = 1;
    end
    % Load the sounds
    sounds = {};
    sounds{1} = audioread([soundDir 'All_Tokens_1.wav']);
    sounds{2} = audioread([soundDir 'All_Tokens_2.wav']);
    sounds{3} = audioread([soundDir 'All_Tokens_3.wav']);
    
    % Load the images
    imgfiles = dir(imgDir);
    imgfiles = {imgfiles.name};
    imgfiles = imgfiles(3:end);
    imgs = {};
    for i = 1:length(imgfiles)
        imgs{i} = imread([imgDir imgfiles{i}]);
    end
    
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

    % Initialize values
    nBlocks = 4; % 10
    trialCount=0;
    blockCount=0;
    freqS = 44100;
    
    if practice==1
        trialEnd = 12; %12
        nBlocks = 1;
        fileSuff = '_Pract';
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
        