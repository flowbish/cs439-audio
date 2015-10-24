function [raw] = realtime_display()
    recorder = dsp.AudioRecorder('DeviceName','³Á§J­· (Realtek High Definition Audio)', ...
                                 'SampleRate',48000, ...
                                 'NumChannels',1, ...
                                 'OutputDataType','double', ...
                                 'SamplesPerFrame',1024, ...
                                 'OutputNumOverrunSamples',true, ...
                                 'QueueDuration',0.2);
    raw = [];
    figure();
    N = 4096;
    x = 0:N-1;
    y = zeros(N,1);
    subplot(2,1,1);
    time_data = plot(x,y);
    xlim([0 N-1]);
    ylim([-0.5 0.5]);
    Y = fft(y);
    subplot(2,1,2);
    freq_data = plot(48000/N*x(1:N/2),abs(Y(1:N/2)));
    xlim([0 48000/2]);
    ylim([0 N/16]);
    set(gcf,'CurrentCharacter',' ');
    while get(gcf,'CurrentCharacter')==' '
        [audioIn,nOverrun] = step(recorder);
        if nOverrun > 0
            disp(['Overrun: ' num2str(nOverrun)]);
        end
        raw = [raw ; audioIn];
        y = [y(1025:N);audioIn];
        Y = fft(y);
        set(time_data,'YData',y);
        set(freq_data,'YData',abs(Y(1:N/2)));
        drawnow;
    end
    release(recorder);
end
