function LaneDetectionGUI_Stable1

clc;
close all;

%% Create GUI Window
fig = figure('Name','Lane Detection and Turn Prediction System',...
    'NumberTitle','off',...
    'Position',[100 100 1400 700],...
    'Color',[0.1 0.1 0.1]);

% ---------- TOP ROW ----------
ax1 = axes('Parent',fig,'Position',[0.05 0.72 0.27 0.22]); title(ax1,'Original','Color','white');
ax2 = axes('Parent',fig,'Position',[0.37 0.72 0.27 0.22]); title(ax2,'Gray','Color','white');
ax3 = axes('Parent',fig,'Position',[0.69 0.72 0.27 0.22]); title(ax3,'Gaussian','Color','white');

% ---------- MIDDLE ROW ----------
ax4 = axes('Parent',fig,'Position',[0.05 0.42 0.27 0.22]); title(ax4,'CLAHE','Color','white');
ax5 = axes('Parent',fig,'Position',[0.37 0.42 0.27 0.22]); title(ax5,'Median','Color','white');
ax6 = axes('Parent',fig,'Position',[0.69 0.42 0.27 0.22]); title(ax6,'Edges','Color','white');

% ---------- BOTTOM ROW ----------
ax7 = axes('Parent',fig,'Position',[0.05 0.12 0.27 0.22]); title(ax7,'ROI','Color','white');
ax8 = axes('Parent',fig,'Position',[0.37 0.12 0.27 0.22]); title(ax8,'Hough','Color','white');
ax9 = axes('Parent',fig,'Position',[0.69 0.12 0.27 0.22]); title(ax9,'Final','Color','white');




%% Buttons
%% Buttons (Neat Centered Layout)

btnWidth = 180;
btnHeight = 50;
gap = 25;

totalWidth = (3 * btnWidth) + (2 * gap);
startX = (1400 - totalWidth) / 2;   % Center align in figure
yPos = 25;

% Load Video Button
uicontrol('Style','pushbutton',...
    'String','Load Video',...
    'Position',[startX, yPos, btnWidth, btnHeight],...
    'FontSize',13,...
    'FontWeight','bold',...
    'BackgroundColor',[0.15 0.15 0.15],...
    'ForegroundColor','white',...
    'Callback',@loadVideo);

% Start Detection Button
uicontrol('Style','pushbutton',...
    'String','Start Processing',...
    'Position',[startX + btnWidth + gap, yPos, btnWidth, btnHeight],...
    'FontSize',13,...
    'FontWeight','bold',...
    'BackgroundColor',[0 0.6 0],...
    'ForegroundColor','white',...
    'Callback',@startDetection);

% Stop Button
uicontrol('Style','pushbutton',...
    'String','Stop',...
    'Position',[startX + 2*(btnWidth + gap), yPos, btnWidth, btnHeight],...
    'FontSize',13,...
    'FontWeight','bold',...
    'BackgroundColor',[0.75 0 0],...
    'ForegroundColor','white',...
    'Callback',@stopDetection);

%% Variables
videoPath = '';
stopFlag = false;

%% Previous frame smoothing values
prev_xLeft_top = [];
prev_xLeft_bottom = [];
prev_xRight_top = [];
prev_xRight_bottom = [];

%% Load Video
    function loadVideo(~,~)

        [file,path] = uigetfile('*.mp4');

        if isequal(file,0)
            return;
        end

        videoPath = fullfile(path,file);

        msgbox('Video Loaded Successfully');

    end

%% Stop
    function stopDetection(~,~)

        stopFlag = true;

    end

%% Start Detection
    function startDetection(~,~)

        if isempty(videoPath)
            msgbox('Please load video first');
            return;
        end

        stopFlag = false;

        VideoFile = VideoReader(videoPath);

        Output_Video = VideoWriter('GUI_Output_Stable.mp4','MPEG-4');
        Output_Video.FrameRate = VideoFile.FrameRate;
        open(Output_Video);

        frameCount = 0;

        while hasFrame(VideoFile)

            if stopFlag
                break;
            end

            %% Read frame
            frame = readFrame(VideoFile);
            frameCount = frameCount + 1;

            height = size(frame,1);
            width = size(frame,2);


            %% Preprocessing
            
                % 1. Original
                imshow(frame,'Parent',ax1);
                title(ax1,'Original','Color','white');

                % 2. Gray
                gray = rgb2gray(frame);
                
                % 3. Gaussian
                gauss = imgaussfilt(gray,1);
                
                % 4. CLAHE
                clahe = adapthisteq(gauss);
                
                % 5. Median
                median_img = medfilt2(clahe,[5 5]);
                
                % 6. Edges
                edges = edge(median_img,'canny',[0.08 0.25]);
                edges = bwareaopen(edges,20);
                
                            

            
            %% ROI
            roi_vertices = [ ...
                round(width*0.1), height;
                round(width*0.45), round(height*0.6);
                round(width*0.55), round(height*0.6);
                round(width*0.9), height];

            roiMask = poly2mask(roi_vertices(:,1),roi_vertices(:,2),height,width);

            roi_edges = edges .* roiMask;

            if mod(frameCount,2)==0
                imshow(gray,[],'Parent',ax2);
                title(ax2,'Gray','Color','white');

               
                imshow(gauss,[],'Parent',ax3);
                title(ax3,'Gaussian','Color','white');

                imshow(clahe,[],'Parent',ax4);
                title(ax4,'CLAHE','Color','white');

                imshow(median_img,[],'Parent',ax5);
                title(ax5,'Median','Color','white');

                imshow(edges,[],'Parent',ax6);
                title(ax6,'Edge detection','Color','white');

                imshow(roi_edges,[],'Parent',ax7);
                title(ax7,'ROI','Color','white');

            end


            %% Hough Transform
[H,T,R] = hough(roi_edges);

peaks = houghpeaks(H,5,'threshold',ceil(0.15*max(H(:))));

lines = houghlines(roi_edges,T,R,peaks,...
    'FillGap',30,...
    'MinLength',30);

%% Better Hough Visualization
if mod(frameCount,2)==0

    % Convert ROI edge image to RGB
    hough_display = cat(3,...
        uint8(roi_edges)*255,...
        uint8(roi_edges)*255,...
        uint8(roi_edges)*255);

    % Draw detected Hough lines
    for k = 1:length(lines)

        xy = [lines(k).point1 lines(k).point2];

        hough_display = insertShape(hough_display,...
            'Line',xy,...
            'LineWidth',6,...
            'Color','cyan');

    end

    % Display
    imshow(hough_display,'Parent',ax8);

    title(ax8,'Hough Line Detection',...
        'Color','white');

end
            %% Separate lanes
            left_lines = [];
            right_lines = [];

            for k = 1:length(lines)

                xy = [lines(k).point1; lines(k).point2];

                x1 = xy(1,1);
                y1 = xy(1,2);
                x2 = xy(2,1);
                y2 = xy(2,2);

                slope = (y2-y1)/(x2-x1+eps);

                if slope < -0.3
                    left_lines = [left_lines; x1 y1 x2 y2];
                elseif slope > 0.3
                    right_lines = [right_lines; x1 y1 x2 y2];
                end

            end

            %% Output frame
            line_frame = frame;

            if ~isempty(left_lines) && ~isempty(right_lines)

                left_mean = mean(left_lines,1);
                right_mean = mean(right_lines,1);

                slopeL = (left_mean(4)-left_mean(2))/(left_mean(3)-left_mean(1)+eps);
                slopeR = (right_mean(4)-right_mean(2))/(right_mean(3)-right_mean(1)+eps);

                %% Reject unstable slopes
                if abs(slopeL) < 0.3 || abs(slopeR) < 0.3
                    continue;
                end



                y_bottom = height;
                y_top = round(height*0.6);

                xLeft_bottom = round((y_bottom-left_mean(2))/slopeL + left_mean(1));
                xLeft_top    = round((y_top-left_mean(2))/slopeL + left_mean(1));

                xRight_bottom = round((y_bottom-right_mean(2))/slopeR + right_mean(1));
                xRight_top    = round((y_top-right_mean(2))/slopeR + right_mean(1));

                %% Anti-flicker smoothing
                if ~isempty(prev_xLeft_top)

                    xLeft_top = round(0.8*prev_xLeft_top + 0.2*xLeft_top);
                    xLeft_bottom = round(0.8*prev_xLeft_bottom + 0.2*xLeft_bottom);

                    xRight_top = round(0.8*prev_xRight_top + 0.2*xRight_top);
                    xRight_bottom = round(0.8*prev_xRight_bottom + 0.2*xRight_bottom);

                end

                %% Store current frame
                prev_xLeft_top = xLeft_top;
                prev_xLeft_bottom = xLeft_bottom;

                prev_xRight_top = xRight_top;
                prev_xRight_bottom = xRight_bottom;

                %% Polygon
                polygon = [xLeft_top y_top ...
                           xLeft_bottom y_bottom ...
                           xRight_bottom y_bottom ...
                           xRight_top y_top];

                line_frame = insertShape(line_frame,'FilledPolygon',polygon,...
                    'Opacity',0.25,'Color','green');

                %% Lane lines
                line_frame = insertShape(line_frame,'Line',...
                    [xLeft_top y_top xLeft_bottom y_bottom],...
                    'LineWidth',6,'Color','red');

                line_frame = insertShape(line_frame,'Line',...
                    [xRight_top y_top xRight_bottom y_bottom],...
                    'LineWidth',6,'Color','red');

                %% Direction
                vanishing_x = (xLeft_top + xRight_top)/2;
                ratio = vanishing_x / width;

                if ratio < 0.48
                    direction = 'Turn Left';
                elseif ratio > 0.52
                    direction = 'Turn Right';
                else
                    direction = 'Go Straight';
                end

                

          
            end

            %% Display processed frame
            imshow(line_frame,'Parent',ax9);
            title(ax9,'Final','Color','white');

            %% Save output
            writeVideo(Output_Video,line_frame);

            drawnow limitrate;

        end

        close(Output_Video);

        msgbox('Processing Completed');

    end

end