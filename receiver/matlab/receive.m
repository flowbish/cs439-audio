%%
%  by Po-Han Huang (c)
%  phuang17@illinois.edu
%
%  Final project for CS439 Wireless Networks in Fall, 2015
%
%  receive()
%
%  DESCRIPTION: receive audio signals, extract messages and send acknowledgements through serial port 
%  INPUT: none
%  OTHERS: requires audio input and serial connection

function receive()

%{  
    %for DEBUG
    clear synth;
%}

% Define some constants:
%   Fs: sample rate
%   BUFFER: buffer size in sound card (must >= WINDOW*2)
%       also influences latency
%   WINDOW_DURATION: duration of a frequency symbol (half transition) in second
%   WINDOW: number of samples of a window (a transition = 2 windows)
%   CHANNEL: how many frequencies are used
%   FREQ: frequencies being used, length must be equal to CHANNEL 
%   BIT_PER_SYMBOL: how many bits a transition represents (should be floor(log2(CHANNEL(CHANNEL-1))))
%   PREAMBLE_SIZE: length of preamble in unit of transitions
%   PREAMBLE: frequency sequence of preamble (in terms of index in FREQ, not actual frequencies)
%       e.g. CHANNEL = 4; FREQ = [5000 6000 7000 8000];
%       if preamble will be 5000->7000->6000->8000,
%       then PREAMBLE = [1 3 2 4];
%   SNR: cutoff SNR (typ.: 1.2 - 3)
%       lower SNR causes system to consider noises as actual signals
%       higher SNR limits the range of transmission
%   NOISE_ADAPTION: the degree of adapting to noise level changes (typ.: 0.02 - 0.2)
%       lower value makes system in sensitive to changes of noise level
%       higher value makes system sensative to sudden noises
%   SYNC_STEP: the precision of synchronization in unit of samples (typ.: 10 - 200)
%       lower value restricts the window length error (actual window length must be close to WINDOW_DURATION)
%       higher value limits the ability to synchronize precisely
%   SYNC_ON: boolean - whether to turn on synchronization
%   CRC_HANDLE: crc detector handler (see:http://www.mathworks.com/help/comm/ref/crc.detector.html)
%
%   See also inline comments for more details and explanations
%
%   When Manchester is used:
%      __    __    
%   __|  |__|  |__
%     |<--->|
%    a transition
%     |  |
%    a window
%
    % Parameters related to hardware settings
    Fs = 96000; % Sampling frequency (depends on hardware, typ: 48k,96k,192k for audible sound waves)
    BUFFER = 19200; % Buffer length (hardware specific)
    
    % Parameters related to package transmission
    WINDOW_DURATION = 0.05; % Symbol duration (half a symbol) time, will be modified based on channel condition, init: 50ms
    DURATION_MODE_COUNT = 4; % Number of transmission rate levels
    DURATIONS = [50 25 10 5]; % Symbol duration of each level, length must be DURATION_MODE_COUNT
    DURATION_MODE = 1; % Current transmission rate level (1 to DURATION_MODE_COUNT), will be modified based on channel condition, init: 1
                            
    WINDOW = floor(Fs*WINDOW_DURATION); % Number of samples in a window (half a symbol)
    CHANNEL = 9; % Number of frequencies
    FREQ = [6000 6200 6400 6600 6800 7000 7400 7600 7800]; % The initial frequencies
    SETTINGS_FREQ = [7200 8200]; % Two frequencies for calibration
    BIT_PER_SYMBOL = 6; % Number of bits a symbol represents
    PREAMBLE_SIZE = 8; % Number of symbols in a preamble
    PREAMBLE = [1 5; 2 6; 3 7; 4 8; 5 9; 6 1; 7 2; 8 3]; % Indices of frequencies in preamble
    SNR = 1.3; % Triggering SNR
    NOISE_ADAPTION = 0.1; % Channel noise adaption rate
    SYNC_STEP = 50; % Number of samples to jump in every step while synchronizing
    SYNC_ON = true; % Turn ON/OFF synchronization
    SOF = 64; % The symbol of SOF
    EOF = 65; % The symbol of EOF
    MTU = 120; % Maximum transmission unit

    % Patameters related to calibration signals                               
    settings_sense_indicator = 0; % A counter indicating whether to detect calibration signals
    SETTINGS_WINDOW_DURATION = 0.05; % Window (half a symbol) length of calibration signals
    SETTINGS_WINDOW = floor(Fs*SETTINGS_WINDOW_DURATION); % Number of samples of a window in calibration signals
    SETTINGS_SENSE_PERIOD = [1 2 5 10]; % Ratio between SETTINGS_WINDOW_DURATION and DURATIONS
    SNR_WINDOW_DURATION = 0.005; % Window length of each frequency while sweeping 
    SNR_SENSE_WINDOW = Fs*SNR_WINDOW_DURATION; %  Number of samples in a window in sweeping
    SNR_DATA_FREQ = 120:40:19000; % Frequencies in sweeping (120,160,200,....,18920,18960,19000)
    SNR_DATA = 0*SNR_DATA_FREQ; % SNR of each frequency (initialized to 0)
    SNR_BOUNDARIES = [0 1000 1000 1000]; % Boundaries to determine channel condition
    FREQ_BASE = [120 160 200 400]; % In each level, frequency must be multiples of FREQ_BASE
                                   % Must be mutiples of 2/DURATIONS (e.g. with 50ms, must be mutiples of 40)
                                   % Change be larger if we want frequencies to separate apart
                                   
    CRC_HANDLE = comm.CRCDetector([8 7 6 4 2 0]); % CRC checker
    
    THRESHOLD = 3; % Number of consecutive ACK/NACK to jump to higher/lower transmission rate level
    ack_balance = 0; % Current status of ACK/NACK, when 3 or -3 is reached, DURATION_MODE increments or decrements
    
    % Statistical variables
    timeout = 0; % Number of timeout packets
    crc_correct = 0; % Number of correct packets
    crc_incorrect = 0; % Number of CRC-fail packets
    byte_count = 0; % Number of bytes received, excluding preamble, control symbols, and CRC
                    % Reset when RESET button is pressed 
    time = 0; % Time elapsed from the first correct packet received
              % Reset when RESET button is pressed 
    time_on = 0; % Timer is on or not. Turned ON when the first correct packet is received.
                 % Turned OFF when RESET button is pressed 
    packet_dist = [0 0 0 0]; % Number of correct packets in each transmission rate level
                             % Length must be DURATION_MODE_COUNT
    

    packet_received = 0; % Number of successful packet received

    % User Interface, Only valid in MATLAB
    figure('Position',[350 200 460 400]);
    t_status = uicontrol('Style','text','Position',[0 370 460 25],'String','Initializing...',...
                        'HorizontalAlignment','center','FontSize',12);
                uicontrol('Style','text','Position',[15 340 90 25],'String','Detected signals:','HorizontalAlignment','left');
    t_signal = uicontrol('Style','text','Position',[110 195 330 170],'String','','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 175 100 20],'String','Packet received:','HorizontalAlignment','left');
    t_num_packet = uicontrol('Style','text','Position',[110 175 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[35 155 80 20],'String','CRC correct:','HorizontalAlignment','left');
    t_crc_correct = uicontrol('Style','text','Position',[110 155 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[35 135 80 20],'String','CRC incorrect:','HorizontalAlignment','left');
    t_crc_incorrect = uicontrol('Style','text','Position',[110 135 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[35 115 80 20],'String','Timeout:','HorizontalAlignment','left');
    t_timeout = uicontrol('Style','text','Position',[110 115 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 90 80 20],'String','Lastest packet:','HorizontalAlignment','left');
    t_latest_packet = uicontrol('Style','text','Position',[110 10 260 100],'String','','HorizontalAlignment','left');
    t_crc_test = uicontrol('Style','text','Position',[370 90 100 20],'String','','HorizontalAlignment','left');
                 uicontrol('Style','text','Position',[135 175 100 20],'String','Speed mode:','HorizontalAlignment','left');
    t_duration = uicontrol('Style','text','Position',[205 175 60 20],'String','50ms','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[135 155 50 20],'String','Freqs:','HorizontalAlignment','left');
    t_freqs = uicontrol('Style','text','Position',[175 155 280 20],'String','[]','HorizontalAlignment','left');
                 uicontrol('Style','text','Position',[135 135 100 20],'String','Packet distribution:','HorizontalAlignment','left');
    t_dist = uicontrol('Style','text','Position',[235 135 100 20],'String','[ 0 0 0 0 ]','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[135 115 130 20],'String','Average speed mode:','HorizontalAlignment','left');
    t_avg_duration = uicontrol('Style','text','Position',[250 115 50 20],'String','50ms','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[370 15 120 20],'String','Exit','HorizontalAlignment','right',...
                            'HorizontalAlignment','center','FontSize',12,'ButtonDownFcn',@set_end_flag,'Enable', 'Inactive');            
    figure('Position',[850 200 460 400]);
                uicontrol('Style','text','Position',[15 370 80 20],'String','Message:','HorizontalAlignment','left');
    t_message = uicontrol('Style','text','Position',[80 50 370 340],'String','','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 10 85 20],'String','Bytes received:','HorizontalAlignment','left');
    t_bytes = uicontrol('Style','text','Position',[100 10 40 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[150 10 30 20],'String','Time:','HorizontalAlignment','left');
    t_time = uicontrol('Style','text','Position',[180 10 50 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[250 10 60 20],'String','Avg. Rate:','HorizontalAlignment','left');
    t_bps = uicontrol('Style','text','Position',[310 10 50 20],'String','0','HorizontalAlignment','left');
    uicontrol('Style','text','Position',[370 15 120 20],'String','Reset','HorizontalAlignment','right',...
                            'HorizontalAlignment','center','FontSize',12,'ButtonDownFcn',@reset,'Enable', 'Inactive');
    set(t_freqs,'String',['[' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ...
            ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9)) ']']);
    drawnow;
 
    % configure audio input (depend on machines)
    recorder = dsp.AudioRecorder('DeviceName','³Á§J­· (Realtek High Definition Audio)', ...
                                 'SampleRate',Fs, ...
                                 'NumChannels',1, ...
                                 'OutputDataType','double', ...
                                 'SamplesPerFrame',BUFFER, ...
                                 'OutputNumOverrunSamples',true, ...
                                 'QueueDuration',0.05);
    % audioIn is buffer of samples
    %   length: BUFFER*3
    audioIn = zeros(BUFFER*3,1);
    
    % Initializing serial IO
    h_serial = serial('COM4');
    fopen(h_serial);
    
    % discard initial samples
    for j = 1 : 20
        load();
    end

    % sense noises (for 10*BUFFER)
    set(t_status,'String','Noise Sensing...');
    drawnow;
    noise = zeros(CHANNEL,1);
    for j = 1 : 10
        load(); % load next BUFFER samples
        % Loop through every window of length=WINDOW/2 and add noise
        % level of each frequency
        for i = 1:2*BUFFER/WINDOW
            F = fft( audioIn( (i-1) * WINDOW/2 + 1 : i * WINDOW/2) );
            noise = noise + abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) ) ;
        end
    end
    noise = noise/10/(2*BUFFER/WINDOW); % Normalize noise level
    drawnow;
    
    % start main loop
    end_flag = 0; % Indicate whether EXIT button is pressed
    index = 2*BUFFER+1; % Index of the sample currently being working on
    while end_flag == 0
        while true
            % listen to channel and look for preamble
            set(t_status,'String','Listening...');
            set(t_signal,'String','');
            drawnow;
            
            while end_flag == 0
                % load new samples if needed
                if index + 2*SETTINGS_WINDOW > 3*BUFFER
                    load();
                    index = index - BUFFER;
                    drawnow;
                end
                
                % If timer is on, update timer
                if(time_on)
                    time = toc;
                    set(t_time,'String',num2str(time));
                    set(t_bps,'String',num2str(byte_count/time));
                end;
                
                % Sense calibration signals if needed
                if ( mod(settings_sense_indicator,SETTINGS_SENSE_PERIOD(DURATION_MODE)) == 0)
                    settings_sense_indicator = 0; % Reset indicator
                    % FFT on the four windows of length=SETTINGS_WINDOW/2
                    % Gather magnitudes of SETTINGS_FREQ as well as FREQ
                    F = fft( audioIn( index : index+SETTINGS_WINDOW/2-1 ) );
                    F1 = abs( F( floor( horzcat(SETTINGS_FREQ,FREQ) * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index+SETTINGS_WINDOW/2 : index+SETTINGS_WINDOW-1 ) );
                    F2 = abs( F( floor( horzcat(SETTINGS_FREQ,FREQ) * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index+SETTINGS_WINDOW : index+SETTINGS_WINDOW*3/2-1 ) );
                    F3 = abs( F( floor( horzcat(SETTINGS_FREQ,FREQ) * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index+SETTINGS_WINDOW*3/2 : index+SETTINGS_WINDOW*2-1 ) );
                    F4 = abs( F( floor( horzcat(SETTINGS_FREQ,FREQ) * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
                    % If calibration preamble outstands, start calibration
                    if ( F1(1) == max(F1) && F3(2) == max(F3) )
                        settings();
                    elseif ( F2(1) == max(F2) && F4(2) == max(F4) )
                        index = index + SETTINGS_WINDOW/2;
                        settings();
                    end
                end
                % detect first symbol of preamble
                % FFT on the four windows of length=WINDOW/2
                % Gather magnitudes of frequencies in FREQ
                F = fft( audioIn( index : index+WINDOW/2-1 ) );
                F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW/2 : index+WINDOW-1 ) );
                F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW : index+WINDOW*3/2-1 ) );
                F3 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW*3/2 : index+WINDOW*2-1 ) );
                F4 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                % If preamble is detected, break the loop
                if ( F1(PREAMBLE(1,1)) > SNR*noise(PREAMBLE(1,1)) && F1(PREAMBLE(1,1)) == max(F1) ...
                        && F3(PREAMBLE(1,2)) > SNR*noise(PREAMBLE(1,2)) && F3(PREAMBLE(1,2)) == max(F3) )
                    break;
                elseif ( F2(PREAMBLE(1,1)) > SNR*noise(PREAMBLE(1,1)) && F2(PREAMBLE(1,1)) == max(F2) ...
                        && F4(PREAMBLE(1,2)) > SNR*noise(PREAMBLE(1,2)) && F4(PREAMBLE(1,2)) == max(F4) )
                    index = index + WINDOW/2;
                    break;
                else
                    % If no preamble is detected, update noise levels
                    noise = noise*(1-NOISE_ADAPTION) + (F1+F2+F3+F4)/4*NOISE_ADAPTION;
                    % Slide to the next window
                    index = index + WINDOW;
                end
            end
            % if EXIT is pressed, break the loop
            if end_flag ~= 0
                break;
            end
            
            % check preamble
            set(t_status,'String','Checking Preamble...');
            drawnow;
            % load new samples if needed
            if index + 2*WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
            end
            % synchronize to first transition
            F_diff_max = 0; 
            index_max = index;
            % Slide by STNC_STEP every loop to find the clearest transition edge
            for i = 0:SYNC_STEP:WINDOW*3/2
                % FFT on two sides of the edge
                F = fft( audioIn( i+index-WINDOW/2 : i+index-1 ) );
                F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( i+index : i+index+WINDOW/2-1 ) );
                F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F_diff_temp = F1(PREAMBLE(1,1))*CHANNEL-sum(F1) + F2(PREAMBLE(1,2))*CHANNEL-sum(F2);
                % If transition edge is clearer than current one, update it
                if  F_diff_temp > F_diff_max
                    F_diff_max = F_diff_temp;
                    index_max = index+i;
                end
            end
            index = index_max-WINDOW;

            % receive the whole preamble
            for i = 1:PREAMBLE_SIZE
                % load new samples if needed
                if index + 2*WINDOW > 3*BUFFER
                    load();
                    index = index - BUFFER;
                end
                % decode a symbol
                % Do FFT and get frequency index of the first half symbol
                F = fft( audioIn( index+WINDOW/4 : index+WINDOW*3/4-1) );
                F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                [F1_max,F1_i] = max(F1);
                % Do FFT and get frequency index of the second half symbol
                F = fft( audioIn( index+WINDOW/4+WINDOW : index+WINDOW*3/4+WINDOW-1) );
                F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                [F2_max,F2_i] = max(F2);
                set(t_signal,'String',[ t_signal.String 'P' num2str(F1_i) num2str(F2_i) ]);
                drawnow;
                % check if preamble incorrect
                if ~isequal(PREAMBLE(i,:),[F1_i F2_i])
                    % If incorrect, go back to listening
                    i=0;
                    break;                
                end
                % synchronize to transition edge
                if SYNC_ON
                    % Do FFT around three transition edges:
                    % current edge - SYNC_STEP,current edge,current edge + SYNC_STEP
                    F = fft( audioIn( index+WINDOW/2+1 : index+WINDOW) );
                    F1_now = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index+WINDOW+1 : index+WINDOW*3/2) );
                    F2_now = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index+WINDOW/2+1-SYNC_STEP : index+WINDOW-SYNC_STEP) );
                    F1_left = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index+WINDOW+1-SYNC_STEP : index+WINDOW*3/2-SYNC_STEP) );
                    F2_left = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index+WINDOW/2+1+SYNC_STEP : index+WINDOW+SYNC_STEP) );
                    F1_right = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index+WINDOW+1+SYNC_STEP : index+WINDOW*3/2+SYNC_STEP) );
                    F2_right = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                    F_diff_now = F1_now(F1_i)*CHANNEL-sum(F1_now) + F2_now(F2_i)*CHANNEL-sum(F2_now);
                    F_diff_left = F1_left(F1_i)*CHANNEL-sum(F1_left) + F2_left(F2_i)*CHANNEL-sum(F2_left);
                    F_diff_right = F1_right(F1_i)*CHANNEL-sum(F1_right) + F2_right(F2_i)*CHANNEL-sum(F2_right);
                    [~,F_diff_max] = max([F_diff_now F_diff_left F_diff_right]);
                    if F_diff_max == 2 % If the edge should be current edge - SYNC_STEP
                        index = index - SYNC_STEP;
                    elseif F_diff_max == 3 % If the edge should be current edge + SYNC_STEP
                        index = index + SYNC_STEP;
                    end
                end
                % Slide to next symbol to decode next symbol in preamble
                index = index + 2*WINDOW;
            end
            % If full preamble is correct, go to receive the main packet
            if i ~= 0
                break;
            end
            % Otherwise, slide to next window and load new samples if needed
            index = index + WINDOW*2;
            if index + 2*WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
            end
            % Listen to signals again
        end
        % if EXIT is pressed, break the loop
        if end_flag ~= 0
            break;
        end
        % receive message
        set(t_status,'String','Receiving Packet...');drawnow;
        message = -1 * ones(1,MTU*4/3); % Initialize message to all -1
        message_on = false; % If SOF already detected
        message_index = 1; % Index of the bit in message currently receiving
        % Only detect upto MTU*4/3 symbols, excluding SOF and EOF
        % (because MTU is in unit of byte)
        for j = 1:MTU*4/3+4
            % load new samples if needed
            if index + 2*WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
            end
            % decode a symbol
            % Do FFT and get frequency index of the first half symbol
            F = fft( audioIn( index+WINDOW/4 : index+WINDOW*3/4) );
            F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
            [~,F1_i] = max(F1);
            % Do FFT and get frequency index of the second half symbol
            F = fft( audioIn( index+WINDOW/4+WINDOW : index+WINDOW*3/4+WINDOW) );
            F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
            [~,F2_i] = max(F2);
            % Calculate what value the symbol represent
            if F2_i <= F1_i
                symbol_value = (CHANNEL-1)*(F1_i-1)+F2_i-1;
            else
                symbol_value = (CHANNEL-1)*(F1_i-1)+F2_i-2;
            end
            % Check if the value is invalid
            % If so, give warning and change value to 63 (all ones)
            if(message_on && symbol_value>63 && symbol_value ~= EOF)
                disp('Warning! symbol value exceeds limit');
                disp(symbol_value);
                symbol_value=63;
            end
            % If SOF already received, append the symbol to message 
            if(message_on)
                % If the symbol is EOF, end receiving message
                if(symbol_value == EOF)
                    set(t_signal,'String',[ t_signal.String 'EOF' ]);
                    break;
                end
                set(t_signal,'String',[ t_signal.String dec2bin(symbol_value,BIT_PER_SYMBOL) ]);
                % Append the symbol to message
                message(BIT_PER_SYMBOL*(message_index-1)+1:BIT_PER_SYMBOL*message_index) =  str2num(sprintf('%c ',dec2bin(symbol_value,BIT_PER_SYMBOL)));
                message_index = message_index + 1;
            % If SOF, turn on message_on
            elseif(symbol_value == SOF)
                set(t_signal,'String',[ t_signal.String 'SOF' ]);
                message_on = true;
            % Otherwise, skip this symbol (but show it on screen)
            else
                set(t_signal,'String',[ t_signal.String dec2bin(symbol_value,BIT_PER_SYMBOL) ]);
            end
            % synchronize to transition
            if SYNC_ON
                % Do FFT around three transition edges:
                % current edge - SYNC_STEP,current edge,current edge + SYNC_STEP
                F = fft( audioIn( index+WINDOW/2+1 : index+WINDOW) );
                F1_now = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW+1 : index+WINDOW*3/2) );
                F2_now = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW/2+1-SYNC_STEP : index+WINDOW-SYNC_STEP) );
                F1_left = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW+1-SYNC_STEP : index+WINDOW*3/2-SYNC_STEP) );
                F2_left = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW/2+1+SYNC_STEP : index+WINDOW+SYNC_STEP) );
                F1_right = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW+1+SYNC_STEP : index+WINDOW*3/2+SYNC_STEP) );
                F2_right = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F_diff_now = F1_now(F1_i)*CHANNEL-sum(F1_now) + F2_now(F2_i)*CHANNEL-sum(F2_now);
                F_diff_left = F1_left(F1_i)*CHANNEL-sum(F1_left) + F2_left(F2_i)*CHANNEL-sum(F2_left);
                F_diff_right = F1_right(F1_i)*CHANNEL-sum(F1_right) + F2_right(F2_i)*CHANNEL-sum(F2_right);
                [~,F_diff_max] = max([F_diff_now F_diff_left F_diff_right]);
                if F_diff_max == 2 % If the edge should be current edge - SYNC_STEP
                    index = index - SYNC_STEP;
                elseif F_diff_max == 3 % If the edge should be current edge + SYNC_STEP
                    index = index + SYNC_STEP;
                end
            end
            % Slide to the next symbol
            index = index + 2*WINDOW;
            drawnow;
        end
        % a whole packet is received!
        message_on = false;
        packet_received = packet_received + 1;
        set(t_num_packet,'String',num2str(packet_received));
        % If the ending symbol is NOT EOF, increment timeout
        if(symbol_value ~= EOF)
            timeout = timeout + 1; % Increment timeout count
            set(t_timeout,'String',num2str(timeout));
            fprintf(h_serial,'%s\n','NACK'); % Send NACK to serial
            disp('Serial: NACK');
            % Update ACK/NACK balance
            if(ack_balance > 0)
                ack_balance = 0;
            else
                ack_balance = ack_balance - 1;
            end
            % If too many consecutive NACKs, jump down a level
            if(ack_balance == -THRESHOLD)
                ack_balance = 0;
                % If DURATION_MODE is still not the lowest, decrement it 
                if(DURATION_MODE ~= 1)
                    DURATION_MODE = DURATION_MODE - 1;
                    % Reset window duration
                    WINDOW_DURATION = DURATIONS(DURATION_MODE)/1000;
                    WINDOW = floor(Fs*WINDOW_DURATION);
                    % Reselect frequencies
                    SNR_DATA_TEMP = vertcat(SNR_DATA,SNR_DATA_FREQ);
                    % Select only frequencies which are multiples of FREQ_BASE in new mode
                    SNR_DATA_TEMP = SNR_DATA_TEMP(1:2,mod(SNR_DATA_FREQ,FREQ_BASE(DURATION_MODE))==0); 
                    % Exclude low frequencies
                    SNR_DATA_TEMP = SNR_DATA_TEMP(1:2,SNR_DATA_TEMP(2,:)>=14000);
                    % Select first 9 frequencies according to SNR
                    [~,sortIndex] = sort(SNR_DATA_TEMP(1,:),'descend');
                    FREQ = SNR_DATA_TEMP(2,sortIndex(1:9));
                    % Send new DURATION and FREQS in serial
                    fprintf(h_serial,'%s\n',['DURATION' num2str(DURATIONS(DURATION_MODE))]);
                    disp(['Serial: DURATION:' num2str(DURATIONS(DURATION_MODE))]);
                    set(t_duration,'String',[num2str(DURATIONS(DURATION_MODE)) 'ms']);
                    fprintf(h_serial,'%s\n',['FREQS' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9))]);
                    disp(['Serial: FREQS:' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ...
                        ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9)) ]);
                    set(t_freqs,'String',['[' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ...
                        ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9)) ']']);
                end
            end
        else
        % If the EOF is received
            message = message(message ~= -1); % Truncate tailing -1
            message = message(1:floor(size(message,2)/8)*8); % Truncate to bytes
            message_hex = binaryVectorToHex(message); % Get hex representation of message
            message_hex = sprintf('%c%c ',message_hex); % Add space to hex representation
            set(t_latest_packet,'String',['0x' message_hex]); % Show hex on screen
            disp(get(t_signal,'String'));
            % check CRC
            [~,crc_e] = step(CRC_HANDLE,message');
            if crc_e == 0 % If CRC is correct
                % Increment crc_correct packet count
                crc_correct = crc_correct + 1;
                set(t_crc_correct,'String',num2str(crc_correct));
                set(t_crc_test,'String','CRC pass');
                % Initial message characters to NULL characters
                message_char = char(zeros(1,size(message,2)/8-1));
                % Turn message into ASCII characters
                for j=1:size(message,2)/8-1;
                    message_char(j) = char(bi2de(message((j-1)*8+1:j*8),'left-msb'));
                end
                % Replace all NULL characters to space
                message_char(message_char==char(0)) = ' ';
                % Show message on screen
                set(t_message,'String',[t_message.String message_char]);
                % Increment successful packet count in current mode
                packet_dist(DURATION_MODE) = packet_dist(DURATION_MODE) + 1;
                set(t_dist,'String',['[ ' num2str(packet_dist(1)) ' ' num2str(packet_dist(2)) ' ' num2str(packet_dist(3)) ' ' num2str(packet_dist(4)) ' ]']);
                set(t_avg_duration,'String',num2str(sum(packet_dist.*DURATIONS)/sum(packet_dist)));
                % Update received byte count
                byte_count = byte_count + size(message,2)/8-1;
                set(t_bytes,'String',num2str(byte_count));
                % Turn on timer
                if(time_on == false)
                    time_on = true;
                    tic;
                end
                % Send an ACK in serial
                fprintf(h_serial,'%s\n','ACK');
                disp('Serial: ACK');
                % Update ACK/NACK balance
                if(ack_balance < 0)
                    ack_balance = 0;
                else
                    ack_balance = ack_balance + 1;
                end
                % If consecutive ACKs, jump to next level
                if(ack_balance == THRESHOLD)
                    % Reset ACK/NACK balance
                    ack_balance = 0;
                    % If not in the highest mode, increment DURATION_MODE
                    if(DURATION_MODE ~= 4)
                        DURATION_MODE = DURATION_MODE + 1;
                        % Reset window duration
                        WINDOW_DURATION = DURATIONS(DURATION_MODE)/1000;
                        WINDOW = floor(Fs*WINDOW_DURATION);
                        % Reselect frequencies
                        SNR_DATA_TEMP = vertcat(SNR_DATA,SNR_DATA_FREQ);
                        % Select only frequencies which are multiples of FREQ_BASE in new mode
                        SNR_DATA_TEMP = SNR_DATA_TEMP(1:2,mod(SNR_DATA_FREQ,FREQ_BASE(DURATION_MODE))==0);
                        % Exclude low frequencies
                        SNR_DATA_TEMP = SNR_DATA_TEMP(1:2,SNR_DATA_TEMP(2,:)>=14000);
                        % Select first 9 frequencies according to SNR
                        [~,sortIndex] = sort(SNR_DATA_TEMP(1,:),'descend');
                        FREQ = SNR_DATA_TEMP(2,sortIndex(1:9));
                        % Send new DURATION and FREQS in serial
                        fprintf(h_serial,'%s\n',['DURATION' num2str(DURATIONS(DURATION_MODE))]);
                        disp(['Serial: DURATION:' num2str(DURATIONS(DURATION_MODE))]);
                        set(t_duration,'String',[num2str(DURATIONS(DURATION_MODE)) 'ms']);
                        fprintf(h_serial,'%s\n',['FREQS' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9))]);
                        disp(['Serial: FREQS:' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ...
                            ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9)) ]);
                        set(t_freqs,'String',['[' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ...
                            ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9)) ']']);
                    end
                end
            else % If CRC is incorrect
                % Increment crc_incorrect packet count
                crc_incorrect = crc_incorrect + 1;
                set(t_crc_incorrect,'String',num2str(crc_incorrect));
                set(t_crc_test,'String','CRC fail');
                % Send a NACK in serial
                fprintf(h_serial,'%s\n','NACK');
                disp('Serial: NACK');
                % Update ACK/NACK balance
                if(ack_balance > 0)
                    ack_balance = 0;
                else
                    ack_balance = ack_balance - 1;
                end
                % If too many consecutive NACKs, jump down a level
                if(ack_balance == -THRESHOLD)
                    ack_balance = 0;
                    % If DURATION_MODE is still not the lowest, decrement it 
                    if(DURATION_MODE ~= 1)
                        DURATION_MODE = DURATION_MODE - 1;
                        % Reset window duration
                        WINDOW_DURATION = DURATIONS(DURATION_MODE)/1000;
                        WINDOW = floor(Fs*WINDOW_DURATION);
                        % Reselect frequencies
                        SNR_DATA_TEMP = vertcat(SNR_DATA,SNR_DATA_FREQ);
                        % Select only frequencies which are multiples of FREQ_BASE in new mode
                        SNR_DATA_TEMP = SNR_DATA_TEMP(1:2,mod(SNR_DATA_FREQ,FREQ_BASE(DURATION_MODE))==0);
                        % Exclude low frequencies
                        SNR_DATA_TEMP = SNR_DATA_TEMP(1:2,SNR_DATA_TEMP(2,:)>=14000);
                        % Select first 9 frequencies according to SNR
                        [~,sortIndex] = sort(SNR_DATA_TEMP(1,:),'descend');
                        FREQ = SNR_DATA_TEMP(2,sortIndex(1:9));
                        % Send new DURATION and FREQS in serial
                        fprintf(h_serial,'%s\n',['DURATION' num2str(DURATIONS(DURATION_MODE))]);
                        disp(['Serial: DURATION:' num2str(DURATIONS(DURATION_MODE))]);
                        set(t_duration,'String',[num2str(DURATIONS(DURATION_MODE)) 'ms']);
                        fprintf(h_serial,'%s\n',['FREQS' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9))]);
                        disp(['Serial: FREQS:' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ...
                            ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9)) ]);
                        set(t_freqs,'String',['[' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ...
                            ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9)) ']']);
                    end
                end
            end
        end
        drawnow;
        % Go back to listening to the channel
    end
    
    % exit
    release(recorder); % terminate audio port
    fclose(h_serial); % terminate searial port
    set(t_status,'String','Finish!'); % Set title to Finish!
    drawnow;
    
% THE END OF THE MAIN PART %
% Below are some functions
    
    % set_end_flag(handle,event)
    %   set end_flag
    function set_end_flag(~,~)
        end_flag = 1;
    end

    % reset(handle,event)
    %   reset timer and byte counter
    function reset(~,~)
        byte_count = 0;
        set(t_bytes,'String','0');
        time_on = 0;
        set(t_time,'String','0');
        set(t_message,'String','');
        set(t_bps,'String','0');
    end

    % load()
    %   load samples from buffer to audioIn
    function load()
        [temp,overrun] = step(recorder);
%{      
        % for DEBUG
        [temp,overrun] = synth();
%}
        % if there is overrun, some samples are skipped
        if overrun > 0
            disp(['Overrun: ' num2str(overrun)]);
        end
        % left shift audioIn by BUFFER
        audioIn = [audioIn(BUFFER+1:3*BUFFER) ; temp];
    end

    % settings()
    %   Do calibration
    function settings()
        % check preamble
        set(t_status,'String','Checking Settings Preamble...');
        drawnow;
        % load new samples if needed
        if index + 2*SETTINGS_WINDOW > 3*BUFFER
            load();
            index = index - BUFFER;
        end
        original_index = index;
        % synchronize to first transition
        F_diff_max = 0; 
        index_max = index;
        % Slide by STNC_STEP every loop to find the clearest transition edge
        for iter = 0:SYNC_STEP:SETTINGS_WINDOW*3/2
            % FFT on two sides of the edge
            F = fft( audioIn( iter+index-SETTINGS_WINDOW/2 : iter+index-1 ) );
            F1 = abs( F( floor( SETTINGS_FREQ * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
            F = fft( audioIn( iter+index : iter+index+SETTINGS_WINDOW/2-1 ) );
            F2 = abs( F( floor( SETTINGS_FREQ * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
            F_diff_temp = F1(1)-F1(2) + F2(2)-F(1);
            % If transition edge is clearer than current one, update it
            if  F_diff_temp > F_diff_max
                F_diff_max = F_diff_temp;
                index_max = index+iter;
            end
        end
        index = index_max-SETTINGS_WINDOW;
        % receive preamble
        for iter = 1:PREAMBLE_SIZE
            % load new samples if needed
            if index + 2*SETTINGS_WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
            end
            % decode a symbol
            F = fft( audioIn( index+SETTINGS_WINDOW/4 : index+SETTINGS_WINDOW*3/4-1) );
            F1 = abs( F( floor( SETTINGS_FREQ * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
            F = fft( audioIn( index+SETTINGS_WINDOW/4+SETTINGS_WINDOW : index+SETTINGS_WINDOW*3/4+SETTINGS_WINDOW-1) );
            F2 = abs( F( floor( SETTINGS_FREQ * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
            % Check if the symbol in preamble is correct
            if(F1(1) > F1(2) && F2(2) > F2(1))
                set(t_signal,'String',[ t_signal.String 'SP' num2str(iter)]);
                 drawnow;
            else
                % If preamble is incorrect, leave the function
                set(t_status,'String','Listening...');
                set(t_signal,'String','');
                drawnow;
                index = original_index;
                return;
            end
            % synchronize to transition edge
            if SYNC_ON
                % Do FFT around three transition edges:
                % current edge - SYNC_STEP,current edge,current edge + SYNC_STEP
                F = fft( audioIn( index+SETTINGS_WINDOW/2+1 : index+SETTINGS_WINDOW) );
                F1_now = abs( F( floor( SETTINGS_FREQ * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+SETTINGS_WINDOW+1 : index+SETTINGS_WINDOW*3/2) );
                F2_now = abs( F( floor( SETTINGS_FREQ * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+SETTINGS_WINDOW/2+1-SYNC_STEP : index+SETTINGS_WINDOW-SYNC_STEP) );
                F1_left = abs( F( floor( SETTINGS_FREQ * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+SETTINGS_WINDOW+1-SYNC_STEP : index+SETTINGS_WINDOW*3/2-SYNC_STEP) );
                F2_left = abs( F( floor( SETTINGS_FREQ * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+SETTINGS_WINDOW/2+1+SYNC_STEP : index+SETTINGS_WINDOW+SYNC_STEP) );
                F1_right = abs( F( floor( SETTINGS_FREQ * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+SETTINGS_WINDOW+1+SYNC_STEP : index+SETTINGS_WINDOW*3/2+SYNC_STEP) );
                F2_right = abs( F( floor( SETTINGS_FREQ * SETTINGS_WINDOW/2 / Fs ) + 1 ) );
                F_diff_now = F1_now(1)-F1_now(2) + F2_now(2)-F2_now(1);
                F_diff_left = F1_left(1)-F1_left(2) + F2_left(2)-F2_left(1);
                F_diff_right = F1_right(1)-F1_right(2) + F2_right(2)-F2_right(1);
                [~,F_diff_max] = max([F_diff_now F_diff_left F_diff_right]);
                if F_diff_max == 2 % If the edge should be current edge - SYNC_STEP
                    index = index - SYNC_STEP;
                elseif F_diff_max == 3 % If the edge should be current edge + SYNC_STEP
                    index = index + SYNC_STEP;
                end
            end
            % Slide to the next symbol
            index = index + 2*SETTINGS_WINDOW;
        end
        % If full preamble is correct, start receiving frequency sweeping 
        SIGNAL = SNR_DATA;
        NOISE = SNR_DATA;
        set(t_status,'String','Listening to Frequency Sweep...');
        drawnow;
        % loop through all frequencies being swept
        for iter = 1:size(SNR_DATA_FREQ,2)
            % load new samples if needed
            if index + 2*SETTINGS_WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
            end
            % Do FFT on the window (zero-padded to lenght=4800 for more precision)
            F = fft( audioIn( index : index+SNR_SENSE_WINDOW-1) , 4800 );
            F1 = abs( F( floor( SNR_DATA_FREQ * 4800 / Fs ) + 1 ) );
            % Update signal strength of the current frequency
            SIGNAL(iter) = F1(iter);
            % Update noise level of all other frequencies
            NOISE(:) = NOISE(:) + F1(:);
            NOISE(iter) = NOISE(iter) - F1(iter);
            % Slide to next window
            index = index + SNR_SENSE_WINDOW;
        end
        % Calculate SNR of all frequencies
        SNR_DATA = SIGNAL ./ (NOISE ./ (size(SNR_DATA_FREQ,2)-1));
        % Set reverved frequencies (7.2 and 8.2kHz) to SNR=0
        SNR_DATA(SNR_DATA_FREQ==SETTINGS_FREQ(1)) = 0;
        SNR_DATA(SNR_DATA_FREQ==SETTINGS_FREQ(2)) = 0;
        % Determine DURATION_MODE based on SNR
        [~,sortIndex] = sort(SNR_DATA,'descend');
        DURATION_MODE = sum(SNR_BOUNDARIES<SNR_DATA(sortIndex(9)));
        % Reset window duration
        WINDOW_DURATION = DURATIONS(DURATION_MODE)/1000;
        WINDOW = floor(Fs*WINDOW_DURATION);
        % Reselect frequencies
        SNR_DATA_TEMP = vertcat(SNR_DATA,SNR_DATA_FREQ);
        % Select only frequencies which are multiples of FREQ_BASE in new mode
        SNR_DATA_TEMP = SNR_DATA_TEMP(1:2,mod(SNR_DATA_FREQ,FREQ_BASE(DURATION_MODE))==0);
        % Exclude low frequencies
        SNR_DATA_TEMP = SNR_DATA_TEMP(1:2,SNR_DATA_TEMP(2,:)>=14000);
        % Select first 9 frequencies according to SNR
        [~,sortIndex] = sort(SNR_DATA_TEMP(1,:),'descend');
        FREQ = SNR_DATA_TEMP(2,sortIndex(1:9));
        % Send an ACK, DURATION, FREQS, and MTU in serial
        fprintf(h_serial,'%s\n','ACK');
        disp('Serial: ACK');
        fprintf(h_serial,'%s\n',['DURATION' num2str(DURATIONS(DURATION_MODE))]);
        disp(['Serial: DURATION:' num2str(DURATIONS(DURATION_MODE))]);
        fprintf(h_serial,'%s\n',['FREQS' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9))]);
        disp(['Serial: FREQS:' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ...
            ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9)) ]);
        set(t_freqs,'String',['[' num2str(FREQ(1)) ',' num2str(FREQ(2)) ',' num2str(FREQ(3)) ',' num2str(FREQ(4)) ...
            ',' num2str(FREQ(5)) ',' num2str(FREQ(6)) ',' num2str(FREQ(7)) ',' num2str(FREQ(8)) ',' num2str(FREQ(9)) ']']);
        set(t_duration,'String',[num2str(DURATIONS(DURATION_MODE)) 'ms']);
        fprintf(h_serial,'%s\n',['MTU' num2str(MTU)]);
        disp(['Serial: MTU:' num2str(MTU)]);
        set(t_status,'String','Listening...');
        set(t_signal,'String','');
        % Reset ACK/NACK balance
        ack_balance = 0;
        drawnow;
        % Load new samples if needed
        if index + 2*SETTINGS_WINDOW > 3*BUFFER
            load();
            index = index - BUFFER;
        end
    end
end
