%%
%  raw = receive()
%
%  DESCRIPTION: receive audio signals and extract messages
%  INPUT: none
%  OUTPUT: raw samples of each message
%   size will be 
%  OTHERS: requires audio input


function [raw] = receive_old5()

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
%   PACKET_SIZE: total transitions of a packet
%   PACKET_SAMPLE: number of samples of a packet
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
%   When Manchester is used:
%      __    __    
%   __|  |__|  |__
%     |<--->|
%    a transition
%     |  |
%    a window
%

    Fs = 96000;
    BUFFER = 9600;
    WINDOW_DURATION = 0.01;
    WINDOW = floor(Fs*WINDOW_DURATION);
    CHANNEL = 9;
    FREQ = [6000 6200 6400 6600 6800 7000 7200 7400 7600];
    BIT_PER_SYMBOL = 6;
    PREAMBLE_SIZE = 8;
    PREAMBLE = [1 5; 2 6; 3 7; 4 8; 5 9; 6 1; 7 2; 8 3];
    PACKET_SIZE = 52;
    PACKET_SAMPLE = WINDOW*PACKET_SIZE*2;
    SNR = 1.5;
    NOISE_ADAPTION = 0.1;
    SYNC_STEP = 50;
    SYNC_ON = true;
    CRC_HANDLE = comm.CRCDetector([8 7 6 4 2 0]);
    
    % set up raw data storage
    raw = {};
    packet_received = 0;
    raw_now = zeros(1,PACKET_SAMPLE*2);

    % User Interface
    figure('Position',[600 200 460 400]);
    t_status = uicontrol('Style','text','Position',[0 370 460 25],'String','Initializing...',...
                        'HorizontalAlignment','center','FontSize',12);
                uicontrol('Style','text','Position',[15 340 90 25],'String','Detected signals:','HorizontalAlignment','left');
    t_signal = uicontrol('Style','text','Position',[110 275 330 90],'String','','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 255 100 20],'String','Packet received:','HorizontalAlignment','left');
    t_num_packet = uicontrol('Style','text','Position',[110 255 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[35 235 80 20],'String','CRC correct:','HorizontalAlignment','left');
    t_crc_correct = uicontrol('Style','text','Position',[110 235 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[35 215 80 20],'String','CRC incorrect:','HorizontalAlignment','left');
    t_crc_incorrect = uicontrol('Style','text','Position',[110 215 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 190 80 20],'String','Lastest packet:','HorizontalAlignment','left');
    t_latest_packet = uicontrol('Style','text','Position',[110 170 260 40],'String','','HorizontalAlignment','left');
    t_crc_test = uicontrol('Style','text','Position',[370 190 100 20],'String','','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 150 80 20],'String','Message:','HorizontalAlignment','left');
    t_message = uicontrol('Style','text','Position',[80 10 370 160],'String','','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[370 15 120 20],'String','Exit','HorizontalAlignment','right',...
                            'HorizontalAlignment','center','FontSize',12,'ButtonDownFcn',@set_end_flag,'Enable', 'Inactive');
    drawnow;
 
    % configure audio input (depend on machines)
    recorder = dsp.AudioRecorder('DeviceName','³Á§J­· (Realtek High Definition Audio)', ...
                                 'SampleRate',Fs, ...
                                 'NumChannels',1, ...
                                 'OutputDataType','double', ...
                                 'SamplesPerFrame',BUFFER, ...
                                 'OutputNumOverrunSamples',true, ...
                                 'QueueDuration',0.2);
    % audioIn is buffer of samples
    %   length: BUFFER*3
    audioIn = zeros(BUFFER*3,1);
    
    % discard initial samples
    for j = 1 : 20
        load();
    end

    % sense noises (for 10*BUFFER)
    set(t_status,'String','Noise Sensing...');
    drawnow;
    noise = zeros(CHANNEL,1);
    for j = 1 : 10
        load();
        for i = 1:2*BUFFER/WINDOW
            F = fft( audioIn( (i-1) * WINDOW/2 + 1 : i * WINDOW/2) );
            noise = noise + abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) ) ;
        end
    end
    noise = noise/10/(2*BUFFER/WINDOW);
    drawnow;
    
    % start main loop
    end_flag = 0;
    index = 2*BUFFER+1;
    while end_flag == 0
        while true
            % listen
            set(t_status,'String','Listening...');
            % flush raw samples
            raw_now = zeros(1,PACKET_SAMPLE*2);
            raw_j = 1;
            set(t_signal,'String','');
            drawnow;
            
            while end_flag == 0
                % load new samples
                if index + 2*WINDOW > 3*BUFFER
                    load();
                    index = index - BUFFER;
                    drawnow;
                end
                % detect first symbol of preamble
                F = fft( audioIn( index : index+WINDOW/2-1 ) );
                F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW/2 : index+WINDOW-1 ) );
                F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW : index+WINDOW*3/2-1 ) );
                F3 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW*3/2 : index+WINDOW*2-1 ) );
                F4 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                if ( F1(PREAMBLE(1,1)) > SNR*noise(PREAMBLE(1,1)) && F1(PREAMBLE(1,1)) == max(F1) ...
                        && F3(PREAMBLE(1,2)) > SNR*noise(PREAMBLE(1,2)) && F3(PREAMBLE(1,2)) == max(F3) )
                    break;
                elseif ( F2(PREAMBLE(1,1)) > SNR*noise(PREAMBLE(1,1)) && F2(PREAMBLE(1,1)) == max(F2) ...
                        && F4(PREAMBLE(1,2)) > SNR*noise(PREAMBLE(1,2)) && F4(PREAMBLE(1,2)) == max(F4) )
                    index = index + WINDOW/2;
                    break;
                else
                    noise = noise*(1-NOISE_ADAPTION) + (F1+F2+F3+F4)/4*NOISE_ADAPTION;
                    index = index + WINDOW;
                end
            end
            % if EXIT is pressed
            if end_flag ~= 0
                break;
            end
            
            % check preamble
            set(t_status,'String','Checking Preamble...');
            drawnow;
            % load new samples
            if index + 2*WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
            end
            % synchronize to first transition
            F_diff_max = 0; 
            index_max = index;
            for i = 0:SYNC_STEP:WINDOW*3/2
                F = fft( audioIn( i+index-WINDOW/2 : i+index-1 ) );
                F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( i+index : i+index+WINDOW/2-1 ) );
                F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F_diff_temp = F1(PREAMBLE(1,1))*CHANNEL-sum(F1) + F2(PREAMBLE(1,2))*CHANNEL-sum(F2);
                if  F_diff_temp > F_diff_max
                    F_diff_max = F_diff_temp;
                    index_max = index+i;
                end
            end
            index = index_max-WINDOW;
            
            % store raw samples to raw_now
            raw_now(raw_j:raw_j+(3*BUFFER-index)) = audioIn(index:3*BUFFER);
            raw_j = raw_j+(3*BUFFER-index)+1;
            % receive preamble
            for i = 1:PREAMBLE_SIZE
                % load new samples
                if index + 2*WINDOW > 3*BUFFER
                    load();
                    index = index - BUFFER;
                    raw_now(raw_j:raw_j+BUFFER-1) = audioIn(2*BUFFER+1:3*BUFFER);
                    raw_j = raw_j + BUFFER;
                end
                % decode a symbol
                F = fft( audioIn( index+WINDOW/4 : index+WINDOW*3/4-1) );
                F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                [F1_max,F1_i] = max(F1);
                F = fft( audioIn( index+WINDOW/4+WINDOW : index+WINDOW*3/4+WINDOW-1) );
                F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                [F2_max,F2_i] = max(F2);
                % check if signal disappear
                if F1_max > SNR*noise(F1_i) && F2_max > SNR*noise(F2_i)
                    set(t_signal,'String',[ t_signal.String 'P' num2str(F1_i) num2str(F2_i) ]);
                else
                    i=0;
                    break;
                end
                drawnow;
                % check if preamble incorrect
                if ~isequal(PREAMBLE(i,:),[F1_i F2_i])
                    i=0;
                    break;                
                end
                % synchronize to transition
                if SYNC_ON
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
                    if F_diff_max == 2
                        index = index - SYNC_STEP;
                    elseif F_diff_max == 3
                        index = index + SYNC_STEP;
                    end
                end
                index = index + 2*WINDOW;
            end
            % jump out loop if full preamble is correct 
            if i ~= 0
                break;
            end
            % shift sample window and load new samples
            index = index + WINDOW*2;
            if index + 2*WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
            end
        end
        % if EXIT is pressed
        if end_flag ~= 0
            break;
        end
        % receive message
        set(t_status,'String','Receiving Packet...');drawnow;
        message = -1 * ones(1,(PACKET_SIZE-PREAMBLE_SIZE)*BIT_PER_SYMBOL);
        for j = 1:PACKET_SIZE-PREAMBLE_SIZE
            % load new samples
            if index + 2*WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
                raw_now(raw_j:raw_j+BUFFER-1) = audioIn(2*BUFFER+1:3*BUFFER);
                raw_j = raw_j + BUFFER;
            end
            % decode a symbol
            F = fft( audioIn( index+WINDOW/4 : index+WINDOW*3/4) );
            F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
            [~,F1_i] = max(F1);
            F = fft( audioIn( index+WINDOW/4+WINDOW : index+WINDOW*3/4+WINDOW) );
            F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
            [~,F2_i] = max(F2);
            if F2_i <= F1_i
                symbol_value = (CHANNEL-1)*(F1_i-1)+F2_i-1;
            else
                symbol_value = (CHANNEL-1)*(F1_i-1)+F2_i-2;
            end
            set(t_signal,'String',[ t_signal.String dec2bin(symbol_value,BIT_PER_SYMBOL) ]);
            if(symbol_value>63)
                disp('Warning! symbol value exceeds limit');
                disp(symbol_value);
                symbol_value=63;
            end
            message(BIT_PER_SYMBOL*(j-1)+1:BIT_PER_SYMBOL*j) =  str2num(sprintf('%c ',dec2bin(symbol_value,BIT_PER_SYMBOL)));
            % synchronize to transition
            if SYNC_ON
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
                if F_diff_max == 2
                    index = index - SYNC_STEP;
                elseif F_diff_max == 3
                    index = index + SYNC_STEP;
                end
            end
            % shift sample window
            index = index + 2*WINDOW;
            drawnow;
        end
        % a packet is received!
        set(t_num_packet,'String',num2str(str2double(t_num_packet.String) + 1));
        message_hex = binaryVectorToHex(message);
        message_char = char(zeros(1,size(message,2)));
        for j=1:size(message,2)/8-1;
            message_char(j) = char(hex2dec(message_hex(2*j-1:2*j)));
        end
        message_char(message_char==char(0)) = ' ';
        set(t_message,'String',deblank([t_message.String message_char]));
        message_hex = sprintf('%c%c ',message_hex);
        set(t_latest_packet,'String',['0x' message_hex]);
        % check CRC
        [~,crc_e] = step(CRC_HANDLE,message');
        if crc_e == 0
            set(t_crc_correct,'String',num2str(str2double(t_crc_correct.String) + 1));
            set(t_crc_test,'String','CRC pass');
        else
            set(t_crc_incorrect,'String',num2str(str2double(t_crc_incorrect.String) + 1));
            set(t_crc_test,'String','CRC fail');
        end
        packet_received = packet_received + 1;
        raw{packet_received} = raw_now;
        drawnow;
    end
    
    % exit
    release(recorder);
    set(t_status,'String','Finish!');
    drawnow;
    
    % set_end_flag(handel,event)
    %   set end_flag
    function set_end_flag(~,~)
        end_flag = 1;
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

end
