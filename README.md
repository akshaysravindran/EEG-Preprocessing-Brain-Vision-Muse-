# EEG-Preprocessing-Brain-Vision data
<p style="font-family: Garamond; font-size:14pt; font-style:normal">
This is a script based preprocessing flowchart to handle artifacts in EEG collected using either brain vision 32+ channel EEG systems
<br/><br/>
 **The most important thing to note is that these steps are not universal. It really depends on the study, what specifically you are looking for and how your data looks like. Then step zero is always looking at the data in raw form. This is a general framework which might work for most studies, but some of these steps might not be ideal for certain studies
<br/><br/>
  
The overall flowchart I typically prefer for brainvision 32-64 channel system is given below <br/><br/><img src='/images/flowchart.png' width=500 align=center> <br/><br/>


Some key steps and pitfalls or sanity checks to look for are<br/><br/>

1) Downsampling <br/>
Make sure the sampling rate to which you are downsampling is greater than twice of the frequency of interest (Nyquist Criterion). Figure below shows how reducing the sampling rate can severely distort the signal if done without care

<br/><img src='/images/downsample.png'>

2) Filtering <br/>
Plot the power spectra to make sure the filtering is done properly 
<br/><img src='/images/filter.png'><br/>

3) Hinfinity <br/>
Plot the time series on the frontal (highest effect of ocular artifact) and occipital channels (smaller effect of ocular artifact) to ensure ocular artifacts are removed. Also make sure it doesnt distort segments not involving ocular artifacts
<br/><img src='/images/hinfinity.png'><br/>


4) Artifact Subspace Reconstruction <br/>
Plot the time series and the spectrogram to check how good the data is cleaning. Cutoff for ASR is critical, too low/ conservative value can end up distorting even the cleaner part whereas too lax of a cutoff might not remove artifacts. Empirically identify the best threshold. I typically go for values in the range 10 - 30 if using ICA later. If using only ASR (low density system), I tend to use more conservative values. 
<br/><img src='/images/asr.png'><br/>

<br/><img src='/images/ASR_cleaning.png'><br/>
^^This figure is from Muse headset and not brain vision. Added to explain the process. 

5) Common Average Reference <br/>
If using CAR before ICA, add a channel of zeros to account for the rank 

