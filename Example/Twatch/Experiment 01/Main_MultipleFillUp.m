%==========================================================================
% 2017/08/17: Just plays and records one sound. No fancy callback orw
% anything.
%==========================================================================
Setup
clear all;
global PS; PS = struct(); 
global FillUpBuffer;
global FillUpPointers;
global AlreadyProcessed;
global DidMicModeCheck;
global AcceptTaps TapReceived;

AcceptTaps = 0;
TapReceived = 0;
DidMicModeCheck = [0 0 1 1];

%% Initialize global variables
% FillUpBuffer is <Audio signal, Chirp number, Buffer Index>
%PS.PERIOD = 2400;
%PS.downPass = [2000 6000];
%PS.upPass = [2000 6000];
%PS.downPass = [8000 12000];

PS.bandpassFilter = 0;
PS.downPass = [2000 6000]; PS.upPass = [2000 6000];
%PS.downPass = [17000 20000]; PS.upPass = [17000 20000];
[upChirp, upSignal] = Helper_CreateSignal('up');
[downChirp, downSignal] = Helper_CreateSignal('down');    

NUMSOURCES = 2;
FillUpBuffer = zeros(PS.PERIOD, 2000, NUMSOURCES*2);
FillUpPointers = zeros(1, NUMSOURCES*2);
AlreadyProcessed = 0;

PS.upchirp_data = upChirp;
PS.downchirp_data = downChirp;
PS.detectEnabled = 0;
PS.detectRef = 0;


%% Set up sensing server
% Only one plays up chirp
% First one plays upSignal

global SIGNALGAIN;
SIGNALGAIN = 0.2;
audioSources(1) = SetupAudioSource('upsound', upSignal);
audioSources(1).preambleGain = 1;
audioSources(1).signalGain = SIGNALGAIN;
for asIdx=2:NUMSOURCES
    audioSources(asIdx) = SetupAudioSource('downsound', downSignal);
    audioSources(asIdx).preambleGain = 0;
    audioSources(asIdx).signalGain = SIGNALGAIN;
end

for asIdx=3:NUMSOURCES
    audioSources(asIdx).signalGain = 0;
end

StartSensingServer(audioSources);

%% Functions
function as = SetupAudioSource (soundName, signal)
    global SIGNALGAIN;
    %% Allocate audio sources and sensing servers
    import edu.umich.cse.yctung.*;
    FS = 48000;
    SIGNAL_GAIN = SIGNALGAIN;
    
    
    PREAMBLE_TYPE = 'CHIRP';            % only support chirp preambles now
    PREAMBLE_FREQS = [22000, 15000];    % [start freq, end freq] in Hz
    PREAMBLE_LENS = [500, 1000];        % [length of real signals, length of single repeatition]
    PREAMBLE_FS = 48000;                % sample rate (should be consistent to the sensing signals)
    PREAMBLE_REPEAT_CNT = 10;           % number of sync to be played
    PREAMBLE_START_OFFSET = 4800;       % number of silent samples before the preamble is played
    PREAMBLE_END_OFFSET = 48000;         % number of silent samples after the preamble is played
    PREAMBLE_FADING_RATIO = -1;         % -1 menas no fading
    preamble = PreambleBuilder(PREAMBLE_TYPE, PREAMBLE_FREQS, PREAMBLE_LENS, PREAMBLE_FS, PREAMBLE_REPEAT_CNT, PREAMBLE_START_OFFSET, PREAMBLE_END_OFFSET, PREAMBLE_FADING_RATIO);
    REPEAT_CNT = 20*60*4;
    
    as = AudioSource(soundName, signal, FS, REPEAT_CNT, SIGNAL_GAIN, preamble);
    
    %as.signal = signal;
    %as.repeatCnt = 20*60*4;
    %as.signalGain = 0.8;
end

function StartSensingServer (audioSources)
    %% Create sensing servers with signals
    global phoneSensor watchSensor;
    import edu.umich.cse.yctung.*;
    close all;
    JavaSensingServer.closeAll(); 
    pause(1.0);
    
    analysisFunction = @BufferCallback_TWatchExperiment;
    %analysisFunction = @BufferCallback_PeakFeedback;
    
    
    %clear sensingServers;
    
    phoneSensor = SensingServer(...
            50005, ...
            CallbackFactory_FillUpIndices(1,2,analysisFunction), ...
            SensingServer.DEVICE_AUDIO_MODE_PLAY_AND_RECORD, ...
            audioSources(1));
    phoneSensor.startSensingAfterConnectionInit = 0;
    
    
    
    watchSensor = SensingServer(...
            50006, ...
            CallbackFactory_FillUpIndices(3,4,analysisFunction), ...
            SensingServer.DEVICE_AUDIO_MODE_PLAY_AND_RECORD, ...
            audioSources(2));
    watchSensor.startSensingAfterConnectionInit = 0;
    
    phoneSensor.addSlaveServer(watchSensor);
end