function block = gen_trials(template, repetitions, shuffle)
% Takes a set of stimuli with varying modalities and conditions and 
% assembles, replicates, and shuffles them into a multiple sets of all
% possible trials, made up of events
% 
% Accepts a template structure, which consists of fields containing
% structure arrays. 
%   'Stimuli' is a required top level field, denoting the event of stimulus
%   presentation
%   'duration' is a required substructure field for each array. It is a 
%   number denoting the duration of the event in seconds. if you are
%   presenting sounds, the 'sound' flag may be used to set the duration of
%   the event to be equal to the sound equivalent of the stimulus item
%   being presented that trial (make sure the sound file and text/item name
%   are the same)
%   'jitter' is an optional substructure field that randomly adds a value
%   to each trial duration between the number given and 0
%   'shows' is an optional substructure field that indicates either image
%   or sound file to be played or text to be displayed
%   'skip' is an optional substructure field that takes a string 
%   conditional statement and skips the current event if the condition is
%   fulfilled
%
% repetitions (optional) indicates the number of times each trial is
% repeated. Default is 1.
%
% shuffle (optional) is a logical that determines whether or not to 
% randomize the order of the trials. Default is 1.
%
% output trials should be multiplied, shuffled, and jittered. Wtih the
% exception of the required 'Stimuli' event, output events should only have
% the fields 'duration' and 'shows'. 'Stimuli' will also have the fields
% 'type' and 'item'. Any 'shows' values that were files will be converted
% to MATLAB audio/image data.

    
    if ~exist('repetitions','var')
        repetitions = 1;
    end
    if ~exist('shuffle','var')
        shuffle = 1;
    end
    
    fnames = string(fieldnames(template)');
    trials = permute_struct(template);
    sound_len = struct();
    block = cell(length(trials),1);

    % apply the options according to description
    for iT = 1:length(trials)
        block{iT} = struct();
        for name = fnames
            event = trials(iT).(name);
            opt = string(fieldnames(event)');
            
            % remove events based on 'skip' conditionals
            if any(ismember(opt,'skip'))
                if contains(event.skip,'=')
                    elem = split(event.skip);
                    trialcond = str2func("@(trial) isequal(trial." ...
                        + elem(1) + "," + elem(end) + ")");
                else
                    error("Function does not currently support " + ...
                        "unequal comparisons")
                end
                if trialcond(trials(iT))
                    continue
                else 
                    event = rmfield(event,'skip');
                end
            end

            % fix the 'shows field to make it consistent and read any files
            if ~any(ismember(opt,'shows'))
                event.shows = '';
            elseif isfile(event.shows)
                [~,fname,ext] = fileparts(event.shows);
                event.item = fname;
                if any(ismember({'.jpg','.png'},lower(ext)))
                    event.shows = imread(event.shows);
                    event.type = 'image';
                elseif any(ismember({'.wav'},lower(ext)))
                    [event.shows, Fs] = audioread(event.shows);
                    event.duration = length(event.shows)/Fs;
                    event.type = 'sound';
                    sound_len.(fname) = event.duration;
                end
            else
                event.item = event.shows;
                event.type = 'text';
            end

            block{iT}.(name) = event;
        end
    end
    
    % Multiply, shuffle, and jitter trials
    block = repmat(block,repetitions,1); % multiply and stack
    if shuffle
        block = block(randperm(length(block))); % shuffle
    end

    for iT = 1:length(block)
        for name = string(fieldnames(block{iT})')
            info = block{iT}.(name);

            % apply jitter
            if any(ismember(fieldnames(info)','jitter'))
                info.duration = info.duration + info.jitter*rand(1,1);
                block{iT}.(name) = rmfield(info,'jitter');
            end

            % Check for 'sound' option
            if strcmp(info.duration, 'sound')
                item = block{iT}.Stimuli.item;
                block{iT}.(name).duration = sound_len.(item);
            end
        end
    end
end

function expanded_struct = permute_struct(nd_substructs)
% Takes a set of substructure arrays and permutes all possible substuctures
% in a single structure array
    expanded_struct = struct();
    C = struct2cell(nd_substructs);
    X = cellfun(@(s)1:numel(s),C,'uni',0);
    [X{:}] = ndgrid(X{:});
    T = cellfun(@(c,x)c(x),C,X,'uni',0);
    S = cellfun(@(F)reshape(F,[1,numel(F)]),T,'uni',0);
    fnames = fieldnames(nd_substructs);
    for i = 1:length(fnames)
        for j = 1:length(S{i})
            expanded_struct(j).(fnames{i}) = S{i}(j);
        end
    end
end

