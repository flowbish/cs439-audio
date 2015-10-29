function [raw] = receive_old()
%clear synth;
    Fs = 96000;
    BUFFER = 9600;
    WINDOW_DURATION = 0.05;
    WINDOW = floor(Fs*WINDOW_DURATION);
    LOW = 7000;
    HIGH = 8000;
    SNR = 10;
    PACKET_SIZE = 104;
    NOISE_ADAPTION = 0.1;
    CRC_KERNEL = [1 1 1 0 1 0 1 0 1];
    
    raw_i = 1;
    raw = zeros(1,Fs*WINDOW_DURATION*PACKET_SIZE);

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
    audioIn = zeros(BUFFER);
    for j = 1 : 100
        [~,~] = step(recorder);
    end
    set(t_status,'String','Noise Sensing...');
    drawnow;
    noise = 0;
    for j = 1 : 10
        [audioIn,~] = step(recorder);
        for i = 1:BUFFER/WINDOW
            F = fft( audioIn( (i-1) * WINDOW + 1 : i * WINDOW) );
            noise = noise + abs( F( floor( LOW * WINDOW / Fs ) + 1 ) );
        end
    end
    noise = noise/10/(BUFFER/WINDOW);
    set(t_noise,'String',num2str(noise));
    drawnow;
    end_flag = 0;
    while end_flag == 0
        while true
            set(t_status,'String','Listening...');
            raw(raw_i,:) = zeros(1,Fs*WINDOW_DURATION*PACKET_SIZE);
            set(t_signal,'String','');
            set(t_high,'String','0.0000');
            index = -1;
            drawnow;
            while index < 0 && end_flag == 0
                audioOld = audioIn;
                [audioIn,nOverrun] = step(recorder);
                if nOverrun > 0
                    disp(['Overrun: ' num2str(nOverrun)]);
                end
                for i = 1:BUFFER/WINDOW
                    F = fft( audioIn( (i-1) * WINDOW + 1 : i * WINDOW) );
                    F_low = abs( F( floor( LOW * WINDOW / Fs ) + 1 ) );
                    set(t_low,'String',num2str(F_low));
                    if F_low > SNR * noise
                        index = (i-1) * WINDOW + 1;
                        break;
                    else
                        noise = noise*(1-NOISE_ADAPTION) + F_low*NOISE_ADAPTION;
                        set(t_noise,'String',num2str(noise));
                    end
                    drawnow;
                end
            end
            if end_flag ~= 0
                break;
            end
            set(t_status,'String','Checking Preamble...');
            drawnow;
            for i = 1:WINDOW/2
                if index <= 1
                    audioTemp = [ audioOld(BUFFER+index-1 : BUFFER) ; audioIn(1:WINDOW+1)];
                elseif index > BUFFER-WINDOW
                    audioOld = audioIn;
                    [audioIn,nOverrun] = step(recorder);
                    if nOverrun > 0
                        disp(['Overrun: ' num2str(nOverrun)]);
                    end
                    index = index - BUFFER;
                    audioTemp = [ audioOld(BUFFER+index-1 : BUFFER) ; audioIn(1:WINDOW+1)];
                else
                    audioTemp = audioIn(index - 1 : index + WINDOW);
                end
                F = fft( audioTemp( 1 : WINDOW) );
                F_left = abs( F( floor( LOW * WINDOW / Fs ) + 1 ) );
                F = fft( audioTemp( 2 : WINDOW+1 ) );
                F_now = abs( F( floor( LOW * WINDOW / Fs ) + 1 ) );
                F = fft( audioTemp( 3 : WINDOW+2 ) );
                F_right = abs( F( floor( LOW * WINDOW / Fs ) + 1 ) );
                if max([F_left F_now F_right]) == F_right
                    index = index + 1;
                elseif max([F_left F_now F_right]) == F_left
                    index = index - 1;
                else
                    raw(raw_i,1:WINDOW) = audioTemp( 2 : WINDOW+1 );
                    break;
                end
            end
            set(t_signal,'String','0');
            drawnow;
            message = -1 * ones(PACKET_SIZE,1);
            message(1) = 0;
            index = index + WINDOW;

            if index > BUFFER
                [audioIn,nOverrun] = step(recorder);
                if nOverrun > 0
                    disp(['Overrun: ' num2str(nOverrun)]);
                end
                index = index - BUFFER;
            end
            for message_i = 2:16
                if index > BUFFER-WINDOW
                    audioOld = audioIn;
                    [audioIn,nOverrun] = step(recorder);
                    if nOverrun > 0
                        disp(['Overrun: ' num2str(nOverrun)]);
                    end
                    index = index - BUFFER;
                end
                if index < 1
                    audioTemp = [ audioOld( BUFFER + index : BUFFER ) ; audioIn( 1 : WINDOW + index - 1)];
                    raw(raw_i,(message_i-1)*WINDOW+1:message_i*WINDOW) = audioTemp;
                    F = fft( audioTemp );
                else
                    audioTemp = audioIn( index : index + WINDOW - 1);
                    raw(raw_i,(message_i-1)*WINDOW+1:message_i*WINDOW) = audioTemp;
                    F = fft( audioTemp );
                end
                F_low = abs( F( floor( LOW * WINDOW / Fs ) + 1 ) );
                set(t_low,'String',num2str(F_low));
                F_high = abs( F( floor( HIGH * WINDOW / Fs ) + 1 ) );
                set(t_high,'String',num2str(F_high));
                if F_low <= SNR*noise && F_high <= SNR*noise
                    message_i = 0;
                    break;
                end
                if F_low < F_high
                    set(t_signal,'String',[ t_signal.String '1' ]);
                    message(message_i) = 1; 
                else 
                    set(t_signal,'String',[ t_signal.String '0' ]);
                    message(message_i) = 0;
                end
                index = index + WINDOW;
                drawnow;
            end
            if message_i ~= 0 && isequal(message(1:16),[0;1;0;1;0;1;0;1;0;1;0;1;0;1;0;1])
                break;
            end
        end
        if end_flag ~= 0
            break;
        end
        set(t_status,'String','Receiving Packet...');drawnow;
        index = index + WINDOW;
        for j = 1:88
            if index > BUFFER-WINDOW
                audioOld = audioIn;
                [audioIn,nOverrun] = step(recorder);
                if nOverrun > 0
                    disp(['Overrun: ' num2str(nOverrun)]);
                end
                index = index - BUFFER;
            end
            if index < 1
                audioTemp = [ audioOld( BUFFER + index : BUFFER ) ; audioIn( 1 : WINDOW + index - 1)];
                raw(raw_i,(j+15)*WINDOW+1:(j+16)*WINDOW) = audioTemp;
                F = fft( audioTemp );
            else
                audioTemp = audioIn( index : index + WINDOW - 1);
                raw(raw_i,(j+15)*WINDOW+1:(j+16)*WINDOW) = audioTemp;
                F = fft( audioTemp );
            end
            F_low = abs( F( floor( LOW * WINDOW / Fs ) + 1 ) );
            set(t_low,'String',num2str(F_low));
            F_high = abs( F( floor( HIGH * WINDOW / Fs ) + 1 ) );
            set(t_high,'String',num2str(F_high));
            if F_low < F_high
                set(t_signal,'String',[ t_signal.String '1' ]);
                message(16+j) = 1; 
            else 
                set(t_signal,'String',[ t_signal.String '0' ]);
                message(16+j) = 0;
            end
            index = index + WINDOW;
            drawnow;
        end
        set(t_num_packet,'String',num2str(str2double(t_num_packet.String) + 1));
        message_hex = binaryVectorToHex(transpose(message));
        message_new = '0000000000';
        for j=1:10
            message_new(j) = char(hex2dec(message_hex(2*j-1:2*j)));
        end
        set(t_message,'String',[t_message.String message_new]);
        for j = 2:3:35
            message_hex = [message_hex(1:j) ' ' message_hex(j+1:length(message_hex))];
        end
        set(t_latest_packet,'String',['0x' message_hex]);
        [~,r] = deconv(message,CRC_KERNEL);
        if isequal(r,zeros(PACKET_SIZE,1))
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
end