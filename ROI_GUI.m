function LaneDetectionGUI_Stable

clc;
close all;

%% Create GUI Window
fig = figure('Name','Lane Detection and Turn Prediction System',...
    'NumberTitle','off',...
    'Position',[100 100 1400 700],...
    'Color',[0.1 0.1 0.1]);

%% Original Video Axis
ax1 = axes('Parent',fig,...
    'Units','pixels',...
    'Position',[50 180 600 450]);

title(ax1,'Original Video','Color','white');

%% Processed Video Axis
ax2 = axes('Parent',fig,...
    'Units','pixels',...
    'Position',[750 180 600 450]);

title(ax2,'Processed Output','Color','white');

%% Direction Label
directionText = uicontrol('Style','text',...
    'Position',[600 630 220 40],...
    'String','Direction: Waiting',...
    'FontSize',14,...
    'BackgroundColor',[0.1 0.1 0.1],...
    'ForegroundColor','green');

%% Buttons
uicontrol('Style','pushbutton',...
    'String','Load Video',...
    'Position',[300 50 150 50],...
    'FontSize',12,...
    'Callback',@loadVideo);

uicontrol('Style','pushbutton',...
    'String','Start Detection',...
    'Position',[550 50 150 50],...
    'FontSize',12,...
    'Callback',@startDetection);

uicontrol('Style','pushbutton',...
    'String','Stop',...
    'Position',[800 50 150 50],...
    'FontSize',12,...
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

        while hasFrame(VideoFile)

            if stopFlag
                break;
            end

            %% Read frame
            frame = readFrame(VideoFile);

            height = size(frame,1);
            width = size(frame,2);

            imshow(frame,'Parent',ax1);

            %% Preprocessing
            

            gray = rgb2gray(frame);    


            edges = edge(gray,'canny',[0.08 0.25]);
            edges = bwareaopen(edges,20);


           
            %% ROI
            roi_vertices = [ ...
                round(width*0.1), height;
                round(width*0.45), round(height*0.6);
                round(width*0.55), round(height*0.6);
                round(width*0.9), height];

            roiMask = poly2mask(roi_vertices(:,1),roi_vertices(:,2),height,width);

            roi_edges = edges .* roiMask;

            %% Hough Transform
            [H,T,R] = hough(roi_edges);

            peaks = houghpeaks(H,5,'threshold',ceil(0.15*max(H(:))));

            lines = houghlines(roi_edges,T,R,peaks,'FillGap',30,'MinLength',30);

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
                    'LineWidth',6,'Color','green');

                line_frame = insertShape(line_frame,'Line',...
                    [xRight_top y_top xRight_bottom y_bottom],...
                    'LineWidth',6,'Color','green');

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

                line_frame = insertText(line_frame,[round(width*0.4) 50],direction,...
                    'FontSize',20,...
                    'BoxOpacity',0,...
                    'TextColor','green');

                directionText.String = ['Direction: ' direction];

            else

                directionText.String = 'Direction: Lane Not Detected';

            end

            %% Display processed frame
            imshow(roi_edges,[],'Parent',ax2);

            %% Save output
            writeVideo(Output_Video,line_frame);

            drawnow;

        end

        close(Output_Video);

        msgbox('Processing Completed');

    end

end