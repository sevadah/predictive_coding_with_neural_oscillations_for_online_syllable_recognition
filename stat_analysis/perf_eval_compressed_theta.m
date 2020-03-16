%% model performance based on readouts from syllable unit - Figure 4, compressed speech
% model variants
N_model = 4;

% variant A  - > preferred gamma rate by theta = exogenous theta - gamma coupling, SU reset, gamma reset by theta
% variant B  - > preferred gamma rate (internally set) = endogenous theta - gamma coupling, SU reset, no gamma reset by theta
% variant C  - > no preferred gamma rate = no theta-gamma coupling, SU reset, gamma reset by theta
% variant D  - > no preferred gamma rate = no theta-gamma coupling, SU reset, no gamma reset by theta
% variant E  - > no preferred gamma rate = no theta-gamma coupling, no SU reset, gamma reset by theta
% variant F  - > no preferred gamma rate = no theta-gamma coupling, no SU reset, no gamma reset by theta
% variant A' - > preferred gamma rate (internally set) = endogenous theta - gamma coupling, SU reset, gamma reset by explicit onsets

%% getting address
currentFold = pwd;
P1_fold = fileparts(currentFold); 

% address and number of dialects
dataFold = fullfile(P1_fold, 'Data');

full_sentence_list = importdata(fullfile(dataFold, 'full_sentence_list.mat'));
N_sentence = length(full_sentence_list);

perf_internal = zeros(N_sentence, N_model); % performance based on the internal timing

compression_factor = [2, 2, 3, 3];
for iModel = 1 : 2 : N_model
    fpath = fullfile(dataFold, ['compressed_' num2str(iModel)])
    comp_factor =  compression_factor(iModel);
	for iSentence = 1 : N_sentence
        curr_sentence = char(full_sentence_list(iSentence));
        sent_data = importdata(fullfile(dataFold, [curr_sentence '.mat'])); % getting sentence data
        
        % getting syllable boundaries
        syllable_boundaries = sent_data.syllable_boundaries;
        startTime = syllable_boundaries(1,:);
        endTime = syllable_boundaries(2,:);

        % re align so the first syllable onset is the start of the sentence 
        % (in TIMIT there is initial 0-padding)
		onsets = startTime - startTime(1) + 1;
		offsets = endTime - startTime(1) + 1;
        
        % adjusting for compressed speech
        onsets = floor(onsets./comp_factor)+1;
        offsets = floor(offsets./comp_factor)+1;
        
        % get DEM file (simulation results) for the current sentence and current model variant
        DEM = importdata(fullfile(fpath, ['DEM_' curr_sentence '.mat']));
        
        % get causal states of level 2
        vv2 = full(DEM.qU.v{2})';

        % get dynamics of causal states of the syllable
        syllable_units = vv2(:, 10 : end); % with the silent unit
        N_syl = size(vv2,2) - 9; % with silent unit

        % dynamics of the causal states of the gamma units
        gammas = vv2(:, 1:8);
        
        % get the internal time reference (internal timing), whenever the first gamma units is activated
        % and there is at least 60ms before the next activated g1 unit
        g1 = gammas(:,1);
		[pks det_locs] = findpeaks(g1,'MinPeakDistance',60); 

        % remove all detected peaks for the gamma 1 units whose amplitude is smaller than 0.6 - so we are sure it is the most active unit at that time

        det_start = det_locs.*(pks>0.6);
		det_start(det_start < 0.5) = [];
        
        % with the Matlab's findpeaks function, from time to time
        % gamma unit at the beginning of the sentence was not detected (probably because of some boundary conditions)
        % although we know that it is the most active unit (in accordance with initial conditions)
        % thus we control for that occurrences.

        if det_start(1) > 25
            det_start = [1 det_start'];
        end

        % performance based on internal timing
        [r, idx_g1] = perf_duration_overlap(syllable_units, det_start, onsets, offsets);
        perf_internal(iSentence, iModel) = r;
        clear r 

        clear gammas syllable_units vv2 N_syl det_start DEM
        clear onsets offsets startTime endTime idx_g1
	end

end

perf_internal_theta = perf_internal;
fname = 'perf_internal_compressed_theta';
save(fname, 'perf_internal_theta');
