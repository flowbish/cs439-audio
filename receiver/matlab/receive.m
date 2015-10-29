function [raw] = receive()
%clear synth;

    Fs = 96000;
    BUFFER = 9600;
    WINDOW_DURATION = 0.05;
    WINDOW = floor(Fs*WINDOW_DURATION);
    CHANNEL = 4;
    FREQ = [7000 8000 9000 10000];
    SYMBOL = {  '2','0','2','2';
                '1','2','2','2';
                '2','2','2','2';
                '2','2','2','2' };
    BIT_PER_SYMBOL = 1;
    SNR = 2;
    PREAMBLE_SIZE = 16;
    PREAMBLE_FIRST = [1 2];
    PACKET_SIZE = 104;
    PACKET_SAMPLE = WINDOW*PACKET_SIZE*2;
    NOISE_ADAPTION = 0.1;
    SYNC_STEP = 100;
    SYNC_ON = true;
    CRC_HANDLE = comm.CRCDetector([8 7 6 4 2 0]);
    
    raw_i = 1;
    raw = zeros(1,PACKET_SAMPLE*2);

    figure('Position',[600 200 460 400]);
    t_status = uicontrol('Style','text','Position',[0 370 460 25],'String','Initializing...',...
                        'HorizontalAlignment','center','FontSize',12);
                uicontrol('Style','text','Position',[15 340 90 25],'String','Detected signals:','HorizontalAlignment','left');
    t_signal = uicontrol('Style','text','Position',[110 335 330 30],'String','','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 295 100 20],'String','Packet received:','HorizontalAlignment','left');
    t_num_packet = uicontrol('Style','text','Position',[110 295 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[35 275 80 20],'String','CRC correct:','HorizontalAlignment','left');
    t_crc_correct = uicontrol('Style','text','Position',[110 275 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[35 255 80 20],'String','CRC incorrect:','HorizontalAlignment','left');
    t_crc_incorrect = uicontrol('Style','text','Position',[110 255 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 290-20*CHANNEL 80 20],'String','Lastest packet:','HorizontalAlignment','left');
    t_latest_packet = uicontrol('Style','text','Position',[110 290-20*CHANNEL 220 20],'String','','HorizontalAlignment','left');
    t_crc_test = uicontrol('Style','text','Position',[330 290-20*CHANNEL 100 20],'String','','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 270-20*CHANNEL 80 20],'String','Message:','HorizontalAlignment','left');
    t_message = uicontrol('Style','text','Position',[80 10 370 280-20*CHANNEL],'String','','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[400 315 80 20],'String','Noise:','HorizontalAlignment','left');
    for j = 1:CHANNEL
                 uicontrol('Style','text','Position',[250 315-20*j 100 20],'String',['F' num2str(j) ' magnitude:'],'HorizontalAlignment','left');
        t_f(j) = uicontrol('Style','text','Position',[340 315-20*j 100 20],'String','0.0000','HorizontalAlignment','left');
        t_noise(j) = uicontrol('Style','text','Position',[400 315-20*j 100 20],'String','0.0000','HorizontalAlignment','left');
    end
                uicontrol('Style','text','Position',[330 15 120 20],'String','Exit (Right Click)','HorizontalAlignment','right',...
                            'HorizontalAlignment','center','FontSize',12,'ButtonDownFcn',@set_end_flag);
    drawnow;
 
    recorder = dsp.AudioRecorder('DeviceName','³Á§J­· (Realtek High Definition Audio)', ...
                                 'SampleRate',Fs, ...
                                 'NumChannels',1, ...
                                 'OutputDataType','double', ...
                                 'SamplesPerFrame',BUFFER, ...
                                 'OutputNumOverrunSamples',true, ...
                                 'QueueDuration',0.2);
    audioIn = zeros(BUFFER*3,1);
    for j = 1 : 20
        load();
    end

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
    for j = 1:CHANNEL
        set(t_noise(j),'String',num2str(noise(j)));
    end
    drawnow;
    
    end_flag = 0;
    index = 2*BUFFER+1;
    while end_flag == 0
        while true
            set(t_status,'String','Listening...');
            raw(raw_i,:) = zeros(1,PACKET_SAMPLE*2);
            raw_j = 1;
            set(t_signal,'String','');
            drawnow;
            while end_flag == 0
                if index + 2*WINDOW > 3*BUFFER
                    load();
                    index = index - BUFFER;
                    drawnow;
                end
                F = fft( audioIn( index : index+WINDOW/2-1 ) );
                F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW/2 : index+WINDOW-1 ) );
                F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW : index+WINDOW*3/2-1 ) );
                F3 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( index+WINDOW*3/2 : index+WINDOW*2-1 ) );
                F4 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                for j = 1:CHANNEL
                    set(t_f(j),'String',num2str( (F1(j)+F2(j)+F3(j)+F4(j))/4 ));
                end
                if ( F1(PREAMBLE_FIRST(1)) > SNR*noise(PREAMBLE_FIRST(1)) && F1(PREAMBLE_FIRST(1)) == max(F1) ...
                        && F3(PREAMBLE_FIRST(2)) > SNR*noise(PREAMBLE_FIRST(2)) && F3(PREAMBLE_FIRST(2)) == max(F3) )
                    break;
                elseif ( F2(PREAMBLE_FIRST(1)) > SNR*noise(PREAMBLE_FIRST(1)) && F2(PREAMBLE_FIRST(1)) == max(F2) ...
                        && F4(PREAMBLE_FIRST(2)) > SNR*noise(PREAMBLE_FIRST(2)) && F4(PREAMBLE_FIRST(2)) == max(F4) )
                    index = index + WINDOW/2;
                    break;
                else
                    noise = noise*(1-NOISE_ADAPTION) + (F1+F2+F3+F4)/4*NOISE_ADAPTION;
                    for j = 1:CHANNEL
                        set(t_noise(j),'String',num2str(noise(j)));
                    end
                    index = index + WINDOW;
                end
            end
            if end_flag ~= 0
                break;
            end
            set(t_status,'String','Checking Preamble...');
            drawnow;
            if index + 2*WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
            end
            F_diff_max = 0; 
            index_max = index;
            
            for i = 0:SYNC_STEP:WINDOW*3/2
                F = fft( audioIn( i+index-WINDOW/2 : i+index-1 ) );
                F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( i+index : i+index+WINDOW/2-1 ) );
                F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                F_diff_temp = F1(PREAMBLE_FIRST(1))*CHANNEL-sum(F1) + F2(PREAMBLE_FIRST(2))*CHANNEL-sum(F2);
                if  F_diff_temp > F_diff_max
                    F_diff_max = F_diff_temp;
                    index_max = index+i;
                end
            end
            index = index_max-WINDOW;
            
            raw(raw_i,raw_j:raw_j+(3*BUFFER-index)) = audioIn(index:3*BUFFER);
            raw_j = raw_j+(3*BUFFER-index)+1;
            message = -1 * ones(1,ceil(PACKET_SIZE/BIT_PER_SYMBOL)*BIT_PER_SYMBOL);
            for i = 1:ceil(PREAMBLE_SIZE/BIT_PER_SYMBOL)
                if index + 2*WINDOW > 3*BUFFER
                    load();
                    index = index - BUFFER;
                    raw(raw_i,raw_j:raw_j+BUFFER-1) = audioIn(2*BUFFER+1:3*BUFFER);
                    raw_j = raw_j + BUFFER;
                end
                F = fft( audioIn( index+WINDOW/4 : index+WINDOW*3/4-1) );
                F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                [F1_max,F1_i] = max(F1);
                F = fft( audioIn( index+WINDOW/4+WINDOW : index+WINDOW*3/4+WINDOW-1) );
                F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
                [F2_max,F2_i] = max(F2);
                for k = 1:CHANNEL
                    set(t_f(k),'String',num2str( (F1(k)+F2(k))/2 ));
                end
                if F1_max > SNR*noise(F1_i) && F2_max > SNR*noise(F2_i)
                    set(t_signal,'String',[ t_signal.String strrep(SYMBOL{F1_i,F2_i},' ','') ]);
                    message((i-1)*BIT_PER_SYMBOL+1:i*BIT_PER_SYMBOL) = str2num(SYMBOL{F1_i,F2_i});
                else
                    i=0;
                    break;
                end
                drawnow;
                if ~check_message(message)
                    i=0;
                    break;
                end
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
            if i ~= 0
                break;
            end
            index = index + WINDOW*2;
            if index + 2*WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
            end
        end
        if end_flag ~= 0
            break;
        end
        set(t_status,'String','Receiving Packet...');drawnow;
        for j = ceil(PREAMBLE_SIZE/BIT_PER_SYMBOL)+1:ceil(PACKET_SIZE/BIT_PER_SYMBOL)
            if index + 2*WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
                raw(raw_i,raw_j:raw_j+BUFFER-1) = audioIn(2*BUFFER+1:3*BUFFER);
                raw_j = raw_j + BUFFER;
            end
            F = fft( audioIn( index+WINDOW/4 : index+WINDOW*3/4) );
            F1 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
            [~,F1_i] = max(F1);
            F = fft( audioIn( index+WINDOW/4+WINDOW : index+WINDOW*3/4+WINDOW) );
            F2 = abs( F( floor( FREQ * WINDOW/2 / Fs ) + 1 ) );
            [~,F2_i] = max(F2);
            for k = 1:CHANNEL
                set(t_f(k),'String',num2str( (F1(k)+F2(k))/2 ));
            end
            set(t_signal,'String',[ t_signal.String strrep(SYMBOL{F1_i,F2_i},' ','') ]);
            message((j-1)*BIT_PER_SYMBOL+1:j*BIT_PER_SYMBOL) = str2num(SYMBOL{F1_i,F2_i});
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
            drawnow;
        end
        set(t_num_packet,'String',num2str(str2double(t_num_packet.String) + 1));
        message(message==2)=0;
        message_hex = binaryVectorToHex(message(1:PACKET_SIZE));
        message_new = char(zeros(1,floor((PACKET_SIZE-PREAMBLE_SIZE-8)/8)));
        for j=floor(PREAMBLE_SIZE/8)+1:floor(PACKET_SIZE/8)-1
            message_new(j-floor(PREAMBLE_SIZE/8)) = char(hex2dec(message_hex(2*j-1:2*j)));
        end
        set(t_message,'String',deblank([t_message.String message_new]));
        for j = 2:3:floor(PACKET_SIZE/8)*3-4
            message_hex = [message_hex(1:j) ' ' message_hex(j+1:length(message_hex))];
        end
        set(t_latest_packet,'String',['0x' message_hex]);
        [~,crc_e] = step(CRC_HANDLE,message(17:104)');
        if crc_e == 0
            set(t_crc_correct,'String',num2str(str2double(t_crc_correct.String) + 1));
            set(t_crc_test,'String','CRC pass');
        else
            set(t_crc_incorrect,'String',num2str(str2double(t_crc_incorrect.String) + 1));
            set(t_crc_test,'String','CRC fail');
        end
        raw_i = raw_i + 1;
        raw = vertcat(raw,zeros(1,PACKET_SAMPLE*2));
        drawnow;
    end
    
    release(recorder);
    set(t_status,'String','Finish!');
    for j = 1:CHANNEL
        set(t_f(j),'String','0.0000');
        set(t_noise(j),'String','0.0000');
    end
    drawnow;
    
    function set_end_flag(~,~)
        end_flag = 1;
    end
    function load()
        [temp,overrun] = step(recorder);
        %[temp,overrun] = synth();
        if overrun > 0
            disp(['Overrun: ' num2str(overrun)]);
        end
        audioIn = [audioIn(BUFFER+1:3*BUFFER) ; temp];
    end

end

function out = check_message(m)
    t = m(m~=-1);
    out = true;
    for j = 1:size(t,2)
        if t(j) ~= mod(j+1,2)
            out = false;
            return;
        end
    end
end
