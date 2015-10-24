function [out,overrun] = synth()
    persistent signal t;
    Fs = 96000;
    BUFFER = 9600;
    WINDOW = 4800;
    if size(signal) == 0
        signal = zeros(Fs*30,1);
        m = hexToBinaryVector('5555313233343536000000007c');
        m = [0 m];
        index = 534201;
        for i = 1:104
            if m(i) == 1
                signal(index:index+WINDOW-1) = sin(2*pi*8000/Fs*(1:WINDOW)');
            else
                signal(index:index+WINDOW-1) = sin(2*pi*7000/Fs*(1:WINDOW)');
            end
            index = index + WINDOW;
        end 
        t=1;
    end
    if size(signal,1) < t + BUFFER
        out = zeros(BUFFER,1);
        t = t + BUFFER;
    else
        out = signal(t + 1 : t + BUFFER);
        t = t + BUFFER;
    end
    if t > 1500000
        t = 96000;
    end
    overrun = 0;
    pause(0.1);
end
