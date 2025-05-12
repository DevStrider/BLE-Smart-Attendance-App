%% 1) Read video & get dims
obj        = VideoReader('highway.avi');  
a          = read(obj);                         
[H, W, ~, F] = size(a);

%% 2) Convolutional code & puncturing setup
trellis    = poly2trellis(5, [23 35]);         % K=5, rate 1/2
p_values   = 0.0001:0.01:0.2;                  % Channel error probabilities
tbl        = 50;                               % Traceback depth
packetSize = 1024;                             % Bits per packet

% Define puncturing patterns
puncturePatterns = {
    [1 1 1 1 0 1 1 1], [1 0 0 0 1 0 0 0];  % 8/9
    [1 1 1 1 1 1 1 1], [1 0 0 0 1 0 0 0];  % 4/5
    [1 1 1 1 1 1 1 1], [1 0 1 0 1 0 1 0];  % 2/3
};
rateLabels = {'8/9','4/5','2/3'};

% Pre-allocate result matrices
numCodes   = length(puncturePatterns);
numPs      = length(p_values);
bitErrors  = zeros(numCodes, numPs);
throughputs = zeros(numCodes, numPs);

%% 3) Loop over each code/pattern
for code = 1:numCodes
    % build one puncture mask (interleaved X,Y)
    X = puncturePatterns{code,1};
    Y = puncturePatterns{code,2};
    puncMask = reshape([X; Y], 1, []);  

    % preallocate movie struct
    mov(F) = struct('cdata', zeros(H,W,3,'uint8'), 'colormap', []);

    for idx = 1:numPs
        p = p_values(idx);
        totalBitErrors = 0;
        totalBits = 0;
        totalCorrectBits = 0;
        totalTransmittedBits = 0;

        for k = 1:F
            %% 1) Extract frame → binary stream
            frame = a(:,:,:,k);
            pixels = reshape(frame, [], 3);              % (H*W)×3
            Rbin = de2bi(pixels(:,1), 8, 'left-msb');    % (H*W)×8
            Gbin = de2bi(pixels(:,2), 8, 'left-msb');
            Bbin = de2bi(pixels(:,3), 8, 'left-msb');
            bitStream = [Rbin(:); Gbin(:); Bbin(:)]';    % 1×(3*H*W*8)
            L = numel(bitStream);

            %% 2) Pad & packetize
            pad = mod(-L, packetSize);
            bitStreamPad = [bitStream zeros(1,pad)];
            numPackets = numel(bitStreamPad)/packetSize;
            packets = reshape(bitStreamPad, packetSize, [])';  % numPackets×1024

            decodedBits = zeros(1, numel(bitStreamPad));

            %% 3) Encode, puncture, BSC, decode
            for pkt = 1:numPackets
                % encode
                enc = convenc(packets(pkt,:), trellis);  % length = 2*1024
                % build mask for this block
                mask = repmat(puncMask, 1, ceil(numel(enc)/numel(puncMask)));
                mask = mask(1:numel(enc));
                % puncture
                encPunc = enc(mask==1);
                % transmit
                rec = bsc(double(encPunc), p);

                % decode
                dec = vitdec(rec, trellis, tbl, 'trunc', 'hard', puncMask);
                decodedBits((pkt-1)*packetSize + (1:packetSize)) = dec(1:packetSize);

                % Calculate correct bits for throughput
                x = xor(dec(1:packetSize), packets(pkt,:));
                totalCorrectBits = totalCorrectBits + sum(x == 0);
                totalTransmittedBits = totalTransmittedBits + length(encPunc);
            end
            decodedBits = decodedBits(1:L);  % remove pad

            %% 4) Reconstruct RGB frame
            totalPix = H*W;
            idx1 = 1:totalPix*8;
            idx2 = totalPix*8 + (1:totalPix*8);
            idx3 = totalPix*16 + (1:totalPix*8);

            Rmat = bi2de(reshape(decodedBits(idx1), [], 8), 'left-msb');
            Gmat = bi2de(reshape(decodedBits(idx2), [], 8), 'left-msb');
            Bmat = bi2de(reshape(decodedBits(idx3), [], 8), 'left-msb');

            Rrec = reshape(uint8(Rmat), H, W);
            Grec = reshape(uint8(Gmat), H, W);
            Brec = reshape(uint8(Bmat), H, W);

            mov(k).cdata = cat(3, Rrec, Grec, Brec);

            % Calculate bit errors for this frame
            totalBitErrors = totalBitErrors + sum(bitStream ~= decodedBits(1:numel(bitStream)));
            totalBits = totalBits + numel(bitStream);
        end

        % Calculate BER and throughput for this code rate and p value
        ber = totalBitErrors / totalBits;
        bitErrors(code, idx) = ber;
        throughputs(code, idx) = totalCorrectBits / totalTransmittedBits;  % New throughput calculation
    end
end

%% 4) Plot BER vs. p
markers   = {'o','s','d'};
lineStyles= {'-','--',':'};
colors    = {'r','g','b'};

figure; hold on;
for c = 1:numCodes
    plot(p_values, bitErrors(c,:), ...
         [markers{c},lineStyles{c}], ...
         'Color', colors{c}, 'LineWidth',1.5);
end
set(gca,'YScale','log');
xlim([0.0001,0.2]);
xlabel('Channel Error Probability (p)');
ylabel('Bit Error Rate (BER)');
title('BER vs. p for Various Code Rates');
legend(rateLabels,'Location','best');
grid on; hold off;

%% 5) Plot Throughput vs. p
figure; hold on;
for c = 1:numCodes
    plot(p_values, throughputs(c,:), ...
         [markers{c},lineStyles{c}], ...
         'Color', colors{c}, 'LineWidth',1.5);
end
xlim([0.0001,0.2]);
ylim([0,1]);
xlabel('Channel Error Probability (p)');
ylabel('Throughput (Correct Bits / Transmitted Bits)');
title('Throughput vs. p for Various Code Rates');
legend(rateLabels,'Location','best');
grid on; hold off; 