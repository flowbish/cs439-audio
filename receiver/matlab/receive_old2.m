function [raw] = receive_old2()
    Fs = 96000;
    BUFFER = 9600;
    WINDOW_DURATION = 0.05;
    WINDOW = floor(Fs*WINDOW_DURATION);
    LOW = 7000;
    HIGH = 8000;
    SNR = 1;
    PACKET_SIZE = 104;
    NOISE_ADAPTION = 0.1;
    SYNC_STEP = 100;
    SYNC_ON = true;
    CRC_HANDLE = comm.CRCDetector([8 7 6 4 2 0]);
    
    raw_i = 1;
    raw = zeros(1,WINDOW*PACKET_SIZE*2);

    figure('Position',[600 200 460 400]);
    t_status = uicontrol('Style','text','Position',[0 370 460 25],'String','Initializing...',...
                        'HorizontalAlignment','center','FontSize',12);
                uicontrol('Style','text','Position',[15 340 90 25],'String','Detected signals:','HorizontalAlignment','left');
    t_signal = uicontrol('Style','text','Position',[110 335 330 30],'String','','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 300 100 20],'String','Packet received:','HorizontalAlignment','left');
    t_num_packet = uicontrol('Style','text','Position',[110 300 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[35 280 80 20],'String','CRC correct:','HorizontalAlignment','left');
    t_crc_correct = uicontrol('Style','text','Position',[110 280 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[35 260 80 20],'String','CRC incorrect:','HorizontalAlignment','left');
    t_crc_incorrect = uicontrol('Style','text','Position',[110 260 20 20],'String','0','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 230 80 20],'String','Lastest packet:','HorizontalAlignment','left');
    t_latest_packet = uicontrol('Style','text','Position',[110 230 220 20],'String','','HorizontalAlignment','left');
    t_crc_test = uicontrol('Style','text','Position',[330 230 100 20],'String','','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[15 210 80 20],'String','Message:','HorizontalAlignment','left');
    t_message = uicontrol('Style','text','Position',[80 10 370 220],'String','','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[250 300 80 20],'String','Noise level:','HorizontalAlignment','left');
    t_noise = uicontrol('Style','text','Position',[340 300 100 20],'String','0.0000','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[250 280 100 20],'String','LOW magnitude:','HorizontalAlignment','left');
    t_low = uicontrol('Style','text','Position',[340 280 100 20],'String','0.0000','HorizontalAlignment','left');
                uicontrol('Style','text','Position',[250 260 100 20],'String','HIGH magnitude:','HorizontalAlignment','left');
    t_high = uicontrol('Style','text','Position',[340 260 100 20],'String','0.0000','HorizontalAlignment','left');
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
    noise = 0;
    for j = 1 : 10
        load();
        for i = 1:2*BUFFER/WINDOW
            F = fft( audioIn( (i-1) * WINDOW/2 + 1 : i * WINDOW/2) );
            noise = noise + abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) ) +  abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
        end
    end
    noise = noise/10/(2*BUFFER/WINDOW)/2;
    set(t_noise,'String',num2str(noise));
    drawnow;
    end_flag = 0;
    index = 2*BUFFER+1;
    while end_flag == 0
        while true
            set(t_status,'String','Listening...');
            raw(raw_i,:) = zeros(1,Fs*WINDOW_DURATION*PACKET_SIZE*2);
            raw_j = 1;
            set(t_signal,'String','');
            drawnow;
            while end_flag == 0
                if index + 2*WINDOW > 3*BUFFER
                    load();
                    index = index - BUFFER;
                    drawnow;
                end
                F1 = fft( audioIn( index : index+WINDOW/2-1 ) );
                F1_low = abs( F1( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                F1_high = abs( F1( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                F2 = fft( audioIn( index+WINDOW/2 : index+WINDOW-1 ) );
                F2_low = abs( F2( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                F2_high = abs( F2( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                F3 = fft( audioIn( index+WINDOW : index+WINDOW*3/2-1 ) );
                F3_low = abs( F3( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                F3_high = abs( F3( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                F4 = fft( audioIn( index+WINDOW*3/2 : index+WINDOW*2-1 ) );
                F4_low = abs( F4( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                F4_high = abs( F4( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                
                set(t_low,'String',num2str( (F1_low+F2_low+F3_low+F4_low)/4 ));
                set(t_high,'String',num2str( (F1_high+F2_high+F3_high+F4_high)/4 ));
                if (F1_low > SNR*noise && F1_low > F1_high && F3_high > SNR*noise && F3_high > F3_low)
                    break;
                elseif (F2_low > SNR*noise && F2_low > F2_high && F4_high > SNR*noise && F4_high > F4_low)
                    index = index + WINDOW/2;
                    break;
                else
                    noise = noise*(1-NOISE_ADAPTION) + (F1_low+F1_high+F2_low+F2_high)/4*NOISE_ADAPTION;
                    set(t_noise,'String',num2str(noise));
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
                F_low = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                F = fft( audioIn( i+index : i+index+WINDOW/2-1 ) );
                F_high = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                if F_high + F_low > F_diff_max
                    F_diff_max = F_high + F_low;
                    index_max = index;
                end
            end
            index = index_max-WINDOW;
            raw(raw_i,raw_j:raw_j+(3*BUFFER-index)) = audioIn(index:3*BUFFER);
            raw_j = raw_j+(3*BUFFER-index)+1;
            message = -1 * ones(1,PACKET_SIZE);
            for i = 1:16
                if index + 2*WINDOW > 3*BUFFER
                    load();
                    index = index - BUFFER;
                    raw(raw_i,raw_j:raw_j+BUFFER-1) = audioIn(2*BUFFER+1:3*BUFFER);
                    raw_j = raw_j + BUFFER;
                end
                F = fft( audioIn( index+WINDOW/4 : index+WINDOW*3/4-1) );
                F_low = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                F_high = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                if F_low > SNR*noise && F_low > F_high
                    set(t_signal,'String',[ t_signal.String '0' ]);
                    message(i) = 0;
                elseif F_high > SNR*noise && F_high > F_low
                    set(t_signal,'String',[ t_signal.String '1' ]);
                    message(i) = 1;
                else
                    i=0;
                    break;
                end
                drawnow;
                if i ~= 1 && message(i) == message(i-1)
                    i=0;
                    break;
                elseif i == 1 && message(i) ~= 0
                    i=0;
                    break;
                end
                if SYNC_ON
                    if i ~= 1 && mod(i,2) == 1
                        F = fft( audioIn( index-WINDOW/2 : index-1) );
                        F_high_now = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                        F = fft( audioIn( index : index+WINDOW/2-1) );
                        F_low_now = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                        F = fft( audioIn( index-WINDOW/2-SYNC_STEP : index-1-SYNC_STEP ) );
                        F_high_left = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                        F = fft( audioIn( index-SYNC_STEP : index+WINDOW/2-1-SYNC_STEP) );
                        F_low_left = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                        F = fft( audioIn( index-WINDOW/2+SYNC_STEP : index-1+SYNC_STEP ) );
                        F_high_right = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                        F = fft( audioIn( index+SYNC_STEP : index+WINDOW/2-1+SYNC_STEP) );
                        F_low_right = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                        if max([F_high_now+F_low_now F_high_left+F_low_left F_high_right+F_low_right]) == F_high_left+F_low_left
                            index = index - SYNC_STEP;
                        elseif max([F_high_now+F_low_now F_high_left+F_low_left F_high_right+F_low_right]) == F_high_right+F_low_right
                            index = index + SYNC_STEP;
                        end
                    else
                        F = fft( audioIn( index-WINDOW/2 : index-1) );
                        F_low_now = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                        F = fft( audioIn( index : index+WINDOW/2-1) );
                        F_high_now = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                        F = fft( audioIn( index-WINDOW/2-SYNC_STEP : index-1-SYNC_STEP ) );
                        F_low_left = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                        F = fft( audioIn( index-SYNC_STEP : index+WINDOW/2-1-SYNC_STEP) );
                        F_high_left = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                        F = fft( audioIn( index-WINDOW/2+SYNC_STEP : index-1+SYNC_STEP ) );
                        F_low_right = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                        F = fft( audioIn( index+SYNC_STEP : index+WINDOW/2-1+SYNC_STEP) );
                        F_high_right = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                        if max([F_high_now+F_low_now F_high_left+F_low_left F_high_right+F_low_right]) == F_high_left+F_low_left
                            index = index - SYNC_STEP;
                        elseif max([F_high_now+F_low_now F_high_left+F_low_left F_high_right+F_low_right]) == F_high_right+F_low_right
                            index = index + SYNC_STEP;
                        end
                    end
                end
                index = index + WINDOW;
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
        for j = 17:104
            if index + 2*WINDOW > 3*BUFFER
                load();
                index = index - BUFFER;
                raw(raw_i,raw_j:raw_j+BUFFER-1) = audio(2*BUFFER+1:3*BUFFER);
                raw_j = raw_j + BUFFER;
            end
            F = fft( audioIn( index+WINDOW/4 : index+WINDOW*3/4) );
            F_low = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
            F_high = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
            set(t_low,'String',num2str(F_low));
            set(t_high,'String',num2str(F_high));
            if F_low < F_high
                set(t_signal,'String',[ t_signal.String '1' ]);
                message(j) = 1; 
            else 
                set(t_signal,'String',[ t_signal.String '0' ]);
                message(j) = 0;
            end
            if SYNC_ON
                if message(j-1) == 1 && message(j) == 0
                    F = fft( audioIn( index-WINDOW/2 : index-1) );
                    F_high_now = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index : index+WINDOW/2-1) );
                    F_low_now = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index-WINDOW/2-SYNC_STEP : index-1-SYNC_STEP ) );
                    F_high_left = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index-SYNC_STEP : index+WINDOW/2-1-SYNC_STEP) );
                    F_low_left = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index-WINDOW/2+SYNC_STEP : index-1+SYNC_STEP ) );
                    F_high_right = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index+SYNC_STEP : index+WINDOW/2-1+SYNC_STEP) );
                    F_low_right = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                    if max([F_high_now+F_low_now F_high_left+F_low_left F_high_right+F_low_right]) == F_high_left+F_low_left
                        index = index - SYNC_STEP;
                    elseif max([F_high_now+F_low_now F_high_left+F_low_left F_high_right+F_low_right]) == F_high_right+F_low_right
                        index = index + SYNC_STEP;
                    end
                elseif message(j-1) == 0 && message(j) == 1
                    F = fft( audioIn( index-WINDOW/2 : index-1) );
                    F_low_now = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index : index+WINDOW/2-1) );
                    F_high_now = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index-WINDOW/2-SYNC_STEP : index-1-SYNC_STEP ) );
                    F_low_left = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index-SYNC_STEP : index+WINDOW/2-1-SYNC_STEP) );
                    F_high_left = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index-WINDOW/2+SYNC_STEP : index-1+SYNC_STEP ) );
                    F_low_right = abs( F( floor( LOW * WINDOW/2 / Fs ) + 1 ) );
                    F = fft( audioIn( index+SYNC_STEP : index+WINDOW/2-1+SYNC_STEP) );
                    F_high_right = abs( F( floor( HIGH * WINDOW/2 / Fs ) + 1 ) );
                    if max([F_high_now+F_low_now F_high_left+F_low_left F_high_right+F_low_right]) == F_high_left+F_low_left
                        index = index - SYNC_STEP;
                    elseif max([F_high_now+F_low_now F_high_left+F_low_left F_high_right+F_low_right]) == F_high_right+F_low_right
                        index = index + SYNC_STEP;
                    end
                end
            end
            index = index + WINDOW;
            drawnow;
        end
        set(t_num_packet,'String',num2str(str2double(t_num_packet.String) + 1));
        message_hex = binaryVectorToHex(message);
        message_new = transpose(char(0,0,0,0,0,0,0,0,0,0));
        for j=3:12
            message_new(j-2) = char(hex2dec(message_hex(2*j-1:2*j)));
        end
        set(t_message,'String',[t_message.String message_new]);
        for j = 2:3:35
            message_hex = [message_hex(1:j) ' ' message_hex(j+1:length(message_hex))];
        end
        set(t_latest_packet,'String',['0x' message_hex]);
        [~,crc_e] = step(CRC_HANDLE,message(17:104));
        if crc_e == 0
            set(t_crc_correct,'String',num2str(str2double(t_crc_correct.String) + 1));
            set(t_crc_test,'String','CRC pass');
        else
            set(t_crc_incorrect,'String',num2str(str2double(t_crc_incorrect.String) + 1));
            set(t_crc_test,'String','CRC fail');
        end
        raw_i = raw_i + 1;
        raw = vertcat(raw,zeros(1,Fs*WINDOW_DURATION*PACKET_SIZE));
        drawnow;
    end
    
    release(recorder);
    set(t_status,'String','Finish!');
    set(t_noise,'String','0.0000');
    set(t_low,'String','0.0000');
    set(t_high,'String','0.0000');
    drawnow;
    
    function set_end_flag(~,~)
        end_flag = 1;
    end
    function load()
        [temp,overrun] = step(recorder);
        if overrun > 0
            disp(['Overrun: ' num2str(overrun)]);
        end
        audioIn = [audioIn(BUFFER+1:3*BUFFER) ; temp];
    end

end