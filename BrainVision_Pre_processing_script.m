%% EEG Pre-Processing Script for removing artifacts from EEG collected using brain vision system 
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%                  EEG Preprocessing Tutorial Code                       %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Summary: From zero to hero in EEG pre-processing;  
% The code will help you navigate how to clean an EEG data collected using
% brain vision system. The code will focus on the following sections
%
% i)  Loading the required libraries, reading the EEG to EEGlab format
% ii) Downsample if needed
% iii)High Pass filtering
% iv) H-infinity filtering
% v)  Low pass filter
% vi) Remove Bad segments (Visually inspecting)
% vii)Remove Bad channels (ASR / Visual Inspection)
% Viii) Remove burst artifacts using ASR
% ix) ICA clearning
% x) Interpolating removed channels
%
% Additional Commands
% xi) Notch filter 
% xii) Common Average Reference
% xiii) Multiple plots for sanity checks
%
%
% Here by default EEG.data has the dimension channels x samples; If using
% custom data/matlab variable, ensure the dimension is correct
%
% Author: Akshay Sujatha Ravindran
% email: akshay dot s dot ravindran at gmail dot com
% June 16th 2020

plot_check = 1;
%% ia. Add EEGlab to the path 
addpath('D:\Dropbox\Interns\Workshop_DL\Presentation\eeglab2019');% Replace this line with the folder in your directory
% To add permanently, go to home> set path > add folder > <Add the folder corresponding to EEGlab>
eeglab % run this to load all dependencies and subfolders

% **************************************************************************************************************************************************
%% ib. Load the EEG variable
% Load the EEG data from the .vhdr file onto malab


% Template: EEG_output_variable = pop_loadbv('directory/folder','filename.vhdr');   
EEG = pop_loadbv([],'MotionArtifactTest.vhdr');  % Leave the directory part empty if the file is in the working directory
% Checks: Change the folder name appropriately 




% **************************************************************************************************************************************************
%% ic. Load the channels
% Add EEG channel location to the EEG structure variable

% Template: EEG_output_variable.chanlocs = pop_chanedit(EEG_output_variable.chanlocs, 'load',{ 'directory\EEG_channel_location_file.ced', 'filetype', 'autodetect'});
EEG.chanlocs = pop_chanedit(EEG.chanlocs, 'load',{ 'ChannelLocations.ced', 'filetype', 'autodetect'}); % No need for directory if file is in the same folder
% Checks: Add the directory name if the folder is different




% **************************************************************************************************************************************************
%% 2 Downsample if required
% Downsample into a smaller sampling frequency

% >> Double click the EEG structure variable in the workspace and check the srate
% >> variable inside the EEG structure; Otherwise type the following in command
% >> window: disp(EEG.srate);


% Template: EEG_output_variable = pop_resample(EEG_input_variable,Required_sampling_frequency); 
EEG = pop_resample(EEG,100); % resample from 1000 Hz to 100 Hz 

% >> Check <<
% Make sure the resampled frequency is atleast twice the frequency
% of interest Nyquist criterion; If looking at 50 Hz component, sampling
% rate should be 100+ Hz

% **************************************************************************************************************************************************
%% 3 High Pass filter
% Remove slow drift from the EEG signal
EEG_HPF = EEG; % You do not need to explicitly create new variables 

% Template: [filter coefficients] = butter(filter_order ,Sampling_rate/2, 'Type_of_filter'); 
Fc = 1; % Cut off frequency
[a,b] = butter(4,Fc/(EEG.srate/2),'high');  % Create the butterworth filter coefficients
EEG_HPF.data = filtfilt(a,b,double(EEG.data)')'; 




% **************************************************************************************************************************************************
%% 4 Hinfinity Adaptive Filter 
% An adaptive filter to remove eye movement artifacts adaptively using
% references signals that measure the electrical activity around the eye
% Based on the paper - DOI: 10.1088/1741-2560/13/2/026013

EEG_Hinf = EEG_HPF;
eogdata  = EEG_Hinf.data([17,22,28,32],:);   % Extract the EOG channels (measuring eye movements)   
EEG_Hinf = pop_select(EEG_Hinf,'nochannel',[17,22,28,32]); % remove EOG channels  

% EEG data to be cleaned
inDataEEG = double(EEG_Hinf.data');

% reference eog data
inDataRef =  double([eogdata(3,:)-eogdata(4,:); 
eogdata(1,:)-eogdata(2,:);    
ones(1,size(EEG.data,2))]');


% Hyperparameters required for Hinfinity Filter
wh    = 0+zeros(3,61); % Dimension in bracket should be (3, number of channels +1); 
Pt    = 0.5*eye(3);      
gamma = 1.15;
q     = 1e-15;  

[sh,zh,Pt,WH] = uhbmi_HinfFilter(inDataEEG, inDataRef, gamma, Pt, wh, q);
EEG_Hinf.data = sh';


EEG     = pop_select(EEG,'nochannel',[17,22,28,32]); % remove EOG channels 
EEG_HPF = pop_select(EEG_HPF,'nochannel',[17,22,28,32]); % remove EOG channels  


chanlocs      = EEG_HPF.chanlocs; % For interpolation later
% **************************************************************************************************************************************************

%% 5 Low Pass filter
% Remove higher frequency contents from the data; Minimize muscular
% artifacts

EEG_LPF      = EEG_Hinf;

% Template: [filter coefficients] = butter(filter_order ,Sampling_rate/2, 'Type_of_filter'); 
Fc           = 49; % Cut off frequency
[a,b]        = butter(4,Fc/(EEG_Hinf.srate/2),'low');  % Create the butterworth filter coefficients
EEG_LPF.data = filtfilt(a,b,double(EEG_Hinf.data)')'; 



% **************************************************************************************************************************************************


%% Sanity Check Required
if plot_check

% >> Sanity Check 1 <<
% Plot the PSD always to check if the filter is doing what you expect
    nw = 4;
    channel_to_plot = 28;
    freq         = [0:0.5:EEG.srate/2]; %frequencies of interest   
    pxx_original = pmtm(EEG.data',nw,freq,EEG.srate);         % Compute PSD or filtered EEG        
    pxx_HPF      = pmtm(EEG_HPF.data',nw,freq,EEG.srate);         % Compute PSD or filtered EEG  
    pxx_Hinf     = pmtm(EEG_Hinf.data',nw,freq,EEG.srate);         % Compute PSD or filtered EEG    
    pxx_LPF      = pmtm(EEG_LPF.data',nw,freq,EEG.srate);         % Compute PSD or filtered EEG    
    
    figure
    plot(freq, 10.*log10(pxx_original(:,channel_to_plot)),'linewidth',1.5)
    hold on
    plot(freq, 10.*log10(pxx_HPF(:,channel_to_plot)),'linewidth',1.5)
    plot(freq, 10.*log10(pxx_Hinf(:,channel_to_plot)),'linewidth',1.5)
    plot(freq, 10.*log10(pxx_LPF(:,channel_to_plot)),'linewidth',1.5) 
    line([1 1],[-80,45],'linestyle',':','linewidth',1.5,'color','k')
    line([30 30],[-80,45],'linestyle','--','linewidth',1.5,'color','k')
    ylim([-60,45])
    
    title('O2 Channel PSD Comparison') 
    legend('Original','HPF','Hinfinity','LPF','HP cutoff','LP cutoff')
    ylabel('PSD (in dB)')
    xlabel('Frequency (Hz)')
    
    set(gca,'FontName','Times New Roman','fontsize',14)
    set(gca, 'XColor', [0 0 0], 'YColor', [0 0 0])   
% **************************************************************************************************************************************************
% >> Sanity Check 2 <<
%%  Hinifnity filter Check
% Plot the time series before and after Hinfinity    
    
    
    N = 5000; % Length of data to plot in samples
    % plot the channel in the frontal region
    figure
    subplot(2,1,1)    
    plot([1:N]./EEG_HPF.srate, EEG_HPF.data(1,1:N));
    hold on
    plot([1:N]./EEG_Hinf.srate, EEG_Hinf.data(1,1:N));
    
    title('Channel FP1')
    ylabel('Magnitude (in uV)')
    xticklabels('')
    legend('EEG after high pass filter ', 'EEG after Hinfinity')
    set(gca,'FontName','Times New Roman','fontsize',14)
    set(gca, 'XColor', [0 0 0], 'YColor', [0 0 0])   
    

    % plot the channel in the occipital region
    subplot(2,1,2)
    plot([1:N]./EEG_HPF.srate, EEG_HPF.data(channel_to_plot,1:N));
    hold on
    plot([1:N]./EEG_Hinf.srate, EEG_Hinf.data(channel_to_plot,1:N));
    title('Channel O2')
    ylabel('Magnitude (in uV)')
    xlabel('Time (sec)')
    set(gca,'FontName','Times New Roman','fontsize',14)
    set(gca, 'XColor', [0 0 0], 'YColor', [0 0 0])  


end

% **************************************************************************************************************************************************
 %% Save the EEG data as set file
pop_saveset(EEG_LPF,'filename' ,'EEG_cleanV0','filepath','')

% **************************************************************************************************************************************************
%% Step  6: Remove bad windows
% Preferable to check visually and remove using the GUI: Tutorial inside
% the slides

% Remove EEG samples between the points inside the bracket; use start and
% end sample number; If multiple segments are to be removed, use semi colon
% and add the next entry
% Template: Remove two windows corresponding to two pairs of begin and end
%EEG_output_variable = eeg_eegrej( EEG_input_variable, [begin_sample_1  end_sample_1; begin_sample_2  end_sample_2]);

if false % this is just to show the format for running the code in script, samples removed are clean so dont execute this
    EEG = eeg_eegrej( EEG_LPF, [1 , 1000; 150000 158000]); % segment between 1:1000 and 150000:158000 is removed   
end

% **************************************************************************************************************************************************


%% Step 7: Remove bad channels
if false % Make it true if you want to remove any channels
    EEG_CR = pop_select(EEG_LPF,'nochannel',[12 40]); % For the purpose of the tutorial removing the(12th and 40th) channel
end
% Go to EEG.chanlocs to know which channel is 12

% **************************************************************************************************************************************************
%% Step 8: Artifact Subspace Reconstruction

EEG_ASR = clean_artifacts(EEG_CR, 'FlatlineCriterion','off',...  % Remove flatline channels
'Highpass','off',... % Keep it off as we already performed high pass filter
'ChannelCriterion','off',... % Keep it off if we are removing channels manually
'LineNoiseCriterion', 'off',... % Keep it off if dont want to remove channels based on line noise criterion
'BurstCriterion',10, ... % Standard deviation cutoff for removal of bursts; Less than 10 is considered very conservative (try 15-30 if doing ICA laterand lower otherwise)
'WindowCriterion','off'); % Keep it off if you dont want to remove too noisy windows
% vis_artifacts(EEG_ASR,EEG_CR) : See all channels before and after ASR

% >> Sanity Check 3 <<
% Plot to check how the ASR is performing
figure
N  = EEG.pnts-1000;
N1 = EEG.pnts;
plot([N:N1]./EEG_ASR.srate, EEG_CR.data(1,N:N1));
hold on
plot([N:N1]./EEG_ASR.srate, EEG_ASR.data(1,N:N1));
xlim([N N1]./EEG_ASR.srate)

title('Channel Fp1')
ylabel('Magnitude (in uV)')
xlabel('Time (in s)')
legend('Before ASR','After ASR','location','northwest')
set(gca,'FontName','Times New Roman','fontsize',14)
set(gca, 'XColor', [0 0 0], 'YColor', [0 0 0])   
% **************************************************************************************************************************************************
%% Step 9: ICA decomposition and cleaning
% Run ICA decomposition and save the eeg data as another .set file
EEG_ICA = pop_runica(EEG_ASR,'icatype','runica'); 
pop_saveset(EEG_ICA,'filename' ,'EEG_cleanV1','filepath','') % save the variable so that it can be opened in GUI later

% type eeglab, load EEG_cleanV1.set; go to tools> classfify components
% using IClabels> Label Components

% **************************************************************************************************************************************************
%% Step 10: Remove identified components 
% *** warning: Make sure the ICs removed below are indeed artifactual ***
EEG_ICA_clean = pop_subcomp(EEG_ICA,[11,17,20]); % remove the artifactual IC's identified by visual inspection

%% Interpolate removed channel
EEG           = pop_interp(EEG_ICA_clean,chanlocs,'spherical'); % Interpolate removed channels
pop_saveset(EEG,'filename' ,'EEG_cleanVF','filepath','') % save final cleaned data
% **************************************************************************************************************************************************

%% Additional useful scripts
if false % change to true if you want to run this
    
    % 1) Line Noise Removal 
    % Remove 60 Hz line noise using notch filter
    Q_fact   = 20;
    wo       = 59.5/(EEG.srate/2);  bw = wo/Q_fact;
    [b,a]    = iirnotch(wo,bw); 
    EEG.data = filtfilt(b,a,double(EEG.data'))'; 
    
    
    % 2) Common Average Reference
    % Compute the average of the signal at all EEG electrodes and subtract 
    % it from the EEG signal at every electrode for every time point
    EEG_AVG  = pop_reref(EEG,[]); 
    
end

        
