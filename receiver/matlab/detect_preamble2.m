function [raw,message] = detect_preamble2()
%clear synth;
    Fs = 96000;
    BUFFER = 9600;
    WINDOW_DURATION = 0.05;
    WINDOW = floor(Fs*WINDOW_DURATION);
    LOW = 7000;
    HIGH = 8000;
    SNR = 5;
    PACKAGE_MAX = 10000;
    recorder = dsp.AudioRecorder('DeviceName','���J�� (Realtek High Definition Audio)', ...
                                 'SampleRate',Fs, ...
                                 'NumChannels',1, ...
                                 'OutputDataType','double', ...
                                 'SamplesPerFrame',BUFFER, ...
                                 'OutputNumOverrunSamples',true, ...
                                 'QueueDuration',0.2);
    audioIn = zeros(BUFFER);
    for j = 1 : 100
        [~,~] = step(recorder);
        %[audioIn,~] = synth();
    end
    disp('Noise sensing:');
    noise = 0;
    for j = 1 : 10
        [audioIn,~] = step(recorder);
        %[audioIn,~] = synth();
        for i = 1:BUFFER/WINDOW
            F = fft( audioIn( (i-1) * WINDOW + 1 : i * WINDOW) );
            noise = noise + abs( F( floor( LOW * WINDOW / Fs ) + 1 ) );
        end
    end
    noise = noise/10/(BUFFER/WINDOW);
    disp('Average noise level=');
    disp(noise);
    while true
        disp('Detection started:');
        index = -1;
        while index < 0
            audioOld = audioIn;
            [audioIn,nOverrun] = step(recorder);
            %[audioIn,nOverrun] = synth();
            if nOverrun > 0
                disp(['Overrun: ' num2str(nOverrun)]);
            end
            for i = 1:BUFFER/WINDOW
                F = fft( audioIn( (i-1) * WINDOW + 1 : i * WINDOW) );
                F_low = abs( F( floor( LOW * WINDOW / Fs ) + 1 ) );
                if F_low > SNR * noise
                    index = (i-1) * WINDOW + 1;
                    break;
                end
            end
        end
        disp('Signal detected');

        for i = 1:WINDOW-2
            if index <= 1
                audioTemp = [ audioOld(BUFFER+index-1 : BUFFER) ; audioIn(1:WINDOW+1)];
            elseif index > BUFFER-WINDOW
                audioOld = audioIn;
                [audioIn,nOverrun] = step(recorder);
                %[audioIn,nOverrun] = synth();
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
                raw = audioTemp( 2 : WINDOW+1 );
                break;
            end
        end
        disp('Finish synchronizing');

        disp('Detect 0');
        message = -1 * ones(PACKAGE_MAX,1);
        message_i = 1;
        message(message_i) = 0;
        message_i = message_i + 1;
        index = index + WINDOW;

        if index > BUFFER
            [audioIn,nOverrun] = step(recorder);
            %[audioIn,nOverrun] = synth();
            if nOverrun > 0
                disp(['Overrun: ' num2str(nOverrun)]);
            end
            index = index - BUFFER;
        end
        raw = [raw ; audioIn(index : BUFFER)];

        while true
            if index > BUFFER-WINDOW
                audioOld = audioIn;
                [audioIn,nOverrun] = step(recorder);
                %[audioIn,nOverrun] = synth();
                if nOverrun > 0
                    disp(['Overrun: ' num2str(nOverrun)]);
                end
                index = index - BUFFER;
                raw = [raw ; audioIn];
            end
            if index < 1
                F = fft( [ audioOld( BUFFER + index - 1 : BUFFER ) ; audioIn( 1 : WINDOW + index - 1)] );
            else
                F = fft( audioIn( index : index + WINDOW - 1) );
            end
            F_low = abs( F( floor( LOW * WINDOW / Fs ) + 1 ) );
            F_high = abs( F( floor( HIGH * WINDOW / Fs ) + 1 ) );
            if F_low <= SNR*noise && F_high <= SNR*noise
                disp('Signal disappeared');
                break;
            end
            if F_low < F_high
                disp('Detect 1');
                message(message_i) = 1; 
                message_i = message_i + 1;
            else 
                disp('Detect 0');
                message(message_i) = 0;
                message_i = message_i + 1;
            end
            if message_i == 17
                break;
            end
            index = index + WINDOW;
        end
        if message_i == 17 && ~isequal(message(1:16),[0;1;0;1;0;1;0;1;0;1;0;1;0;1;0;1])
            disp('Detected message:');
            disp(message(1:16));
            disp('Not Preamble!');
        elseif message_i == 17 && isequal(message(1:16),[0;1;0;1;0;1;0;1;0;1;0;1;0;1;0;1])
            disp('Preamble detected!');
            break;
        end
    end
    index = index + WINDOW;
    while true
        if index > BUFFER-WINDOW
            audioOld = audioIn;
            [audioIn,nOverrun] = step(recorder);
            %[audioIn,nOverrun] = synth();
            if nOverrun > 0
                disp(['Overrun: ' num2str(nOverrun)]);
            end
            index = index - BUFFER;
            raw = [raw ; audioIn];
        end
        if index < 1
            F = fft( [ audioOld( BUFFER + index - 1 : BUFFER ) ; audioIn( 1 : WINDOW + index - 1)] );
        else
            F = fft( audioIn( index : index + WINDOW - 1) );
        end
        F_low = abs( F( floor( LOW * WINDOW / Fs ) + 1 ) );
        F_high = abs( F( floor( HIGH * WINDOW / Fs ) + 1 ) );
        if F_low <= SNR*noise && F_high <= SNR*noise
            disp('Signal disappeared');
            break;
        end
        if F_low < F_high
            disp('Detect 1');
            message(message_i) = 1; 
            message_i = message_i + 1;
        else 
            disp('Detect 0');
            message(message_i) = 0;
            message_i = message_i + 1;
        end
        if message_i == PACKAGE_MAX + 1
            disp('Reached Maximum Package Size!');
            break;
        end
        index = index + WINDOW;
    end
    message = message(1:message_i-1);
    disp('Finish!');
end
