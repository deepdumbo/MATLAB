function NDPreader(NDPFile)
% NDPREADER opens an NDP image file from the nanozoomer.
%
% Requirements: 
%  o NDPRead.dll and NDPRead.h provided by Hamamatsu 
%  o Compiler
%  o headerReader.m and headerWriter.m by J.A. Disselhorst [optional]
%
% Input [all inputs are optional]:
%  o filename = Full path and filename to a NDP image.
%
% JA Disselhorst 2013. Werner Siemens Imaging Center
% version 2013.06.27

% Define variable that is used across functions.
NDPi = struct('filename','','finished',0);

buildGUI(); % Build the user interface.
if nargin   % If the user provided a file, load it. 
    loadNDP('auto',NDPFile);
end

    function buildGUI(varargin)
        % BUILDGUI creates the user interface for the program.
        bgc = [.8 .8 .8];
        NDPi.thisFig = figure('Name', 'NanoZoomer', 'NumberTitle','off', 'MenuBar', 'figure','Units','normalized','OuterPosition',[0 0.05 1 0.95], 'DeleteFcn',@closeWindow,'Color',bgc);
        set(NDPi.thisFig,'Nextplot','new');
        % Image
        IMG = reshape(bgc,[1 1 3]);
        NDPi.imagePanel = uipanel('Parent',NDPi.thisFig,'Units','normalized','Position',[0 0 0.9 1],'BackgroundColor',bgc);
        NDPi.thisAxs = axes('Parent',NDPi.imagePanel,'Units','Normalized','Position',[0 0 1 1]);
        imshow(IMG,'Border','tight','Parent',NDPi.thisAxs,'InitialMagnification',100);
        
        % File loading
        filePanel = uipanel('Parent',NDPi.thisFig,'Units','normalized','Position',[0.9 0.9 0.1 .1],'BackgroundColor',bgc);
        uicontrol('Parent',filePanel,'Units','normalized','Position',[0.01 0.69 0.48 0.3],'String','Load File','Callback',@loadNDP)
        uicontrol('Parent',filePanel,'Units','normalized','Position',[0.51 0.69 0.48 0.3],'String','Exit','Callback',@closeWindow);
        
        % ROIs
        roiPanel = uipanel('Parent',NDPi.thisFig,'Units','normalized','Position',[0.9 .1 0.1 .8],'Title','Regions of Interest','BackgroundColor',bgc);
        uicontrol('Parent',roiPanel,'Style','pushbutton','String','Create','Units','normalized','Position',[0.01 0.97 0.48 0.03],'Callback',@createROI,'Enable','off');
        uicontrol('Parent',roiPanel,'Style','pushbutton','String','Delete','Units','normalized','Position',[0.51 0.97 0.48 0.03],'Callback',@deleteROI,'Enable','off');
        defaultThreshold = 210;
        NDPi.threshSlide = uicontrol('Parent',roiPanel,'Style','slider','Units','normalized','Position',[0 0.94 0.6 0.03],'BackgroundColor',bgc,'Enable','on','Min',0,'Max',255,'Value',defaultThreshold,'SliderStep',[1 10]/255,'Callback',@changeThreshold);
        NDPi.threshEdit = uicontrol('Parent',roiPanel,'Style','edit','Units','normalized','Position',[0.6 0.94 0.2 0.03],'BackgroundColor','w','Enable','on','String',sprintf('%1.0f',defaultThreshold),'Callback',@changeThreshold);
        uicontrol('Parent',roiPanel,'Style','pushbutton','String','Auto','Units','normalized','Position',[0.8 0.94 0.2 0.03],'Callback',@autoSeparate,'Enable','off');
        uicontrol('Parent',roiPanel,'Style','pushbutton','String','Save all ROIs','Units','normalized','Position',[0.01 0 0.48 0.03],'Callback',@saveROIs,'Enable','off');
        uicontrol('Parent',roiPanel,'Style','pushbutton','String','Load all ROIs','Units','normalized','Position',[0.51 0 0.48 0.03],'Callback',@loadROIs,'Enable','off');
        NDPi.ROIlist = uicontrol('Parent',roiPanel,'Style','listbox','Units','normalized','Position',[0 0.03 1 0.91],'BackgroundColor','w','Callback',@listSelect,'Enable','off','Min',0,'Max',2,'KeyPressFcn',@keyPressed);
        NDPi.ROIs = [];
        
        % save files
        savePanel = uipanel('Parent',NDPi.thisFig,'Units','normalized','Position',[0.9 0 0.1 0.1],'Title', 'Export ROIs','BackgroundColor',bgc);
        NDPi.zoomLevels = {'0.5x','1x','1.25x','2.5x','5x','10x','20x','40x'};
        uicontrol('Parent',savePanel,'Style','text', 'String','Zoom:','Units','normalized','Position',[0 0.75 0.3 0.2],'BackgroundColor',bgc);
        NDPi.zoomMenu = uicontrol('Parent',savePanel,'Style','popupmenu','Units','normalized','Position',[0.3 0.8 0.7 0.2],'BackgroundColor','w','String',NDPi.zoomLevels,'Enable','off');
        uicontrol('Parent',savePanel,'Style','pushbutton','String','Workspace','Units','normalized','Position',[0 0.33 0.5 0.3],'Callback',{@exportROIs,0},'Enable','off');
        uicontrol('Parent',savePanel,'Style','pushbutton','String','File','Units','normalized','Position',[0.5 0.33 0.5 0.3],'Callback',{@exportROIs,1},'Enable','off');
        
        set(NDPi.thisFig,'Nextplot','new');
    end
    function loadNDP(varargin)
        % LOADNDP loads a NDP image file
        [INIpath, INIname] = fileparts(mfilename('fullpath'));
        if exist(fullfile(INIpath,[INIname, '.config']),'file') && exist('headerReader.m','file');
            INI = headerReader(fullfile(INIpath,[INIname, '.config']));
            filename = INI.General.filename;
            zoomLevel = round(INI.General.zoomlevel);
            saveFolder = INI.General.savefolder;
        else
            filename = cd;
            zoomLevel = 1;
            saveFolder = '0';
        end
        if ~isempty(NDPi.filename), filename = NDPi.filename; end;
        
        % If initial settings were provided.
        if ischar(varargin{1})
            filename = varargin{2};
        else
            [filename,pathname] = uigetfile({'*.ndpi', 'Hamamatsu NDP images (*.ndpi)'; '*.*', 'All files (*.*'}, 'Select Hamamatsu NDP file',filename);
            filename = fullfile(pathname,filename);
        end
        if ~exist(filename,'file')
            fprintf('No valid file selected\n');
            return
        else
            delete(NDPi.ROIs);
            NDPi.ROIs = []; set(NDPi.ROIlist,'String','','Value',0);
            NDPi.filename = filename;
            set(NDPi.thisFig,'Name',['NanoZoomer: ',filename]);
            set(findall(NDPi.thisFig,'Enable','off'),'Enable','on')
            if exist(saveFolder,'dir')
                NDPi.saveFolder = saveFolder;
            else
                NDPi.saveFolder = fileparts(filename);
            end
            if zoomLevel>0 && zoomLevel<9
                set(NDPi.zoomMenu,'Value',zoomLevel);
            end
        end
        if not(libisloaded('NDPRead'))
            fprintf('Loading library:...');
            loadlibrary('NDPRead.dll','NDPRead.h')
            fprintf('\b\b\b done.\n');
        else
            calllib('NDPRead','CleanUp');
        end
        NDPi.noChannels = double(calllib('NDPRead','GetNoChannels',filename));
        NDPi.channelOrder = calllib('NDPRead','GetChannelOrder',filename);   % 0: Error, 1: BGR [default], 2: RGB, 3: Greyscale
        NDPi.sourceLens = double(calllib('NDPRead','GetSourceLens',filename));
        [~,~, fullPixelWidth, fullPixelHeight] = calllib('NDPRead','GetSourcePixelSize',filename,1,1);
        NDPi.fullPixelWidth = double(fullPixelWidth);
        NDPi.fullPixelHeight = double(fullPixelHeight);
        [~,~,minFocalDepth,maxFocalDepth,focalDistance] = calllib('NDPRead','GetZRange',filename,1,1,1);
        if minFocalDepth~=maxFocalDepth
            focalDepths = minFocalDepth:focalDistance:maxFocalDepth;
            focalMenu = cell(1,length(focalDepths));
            for ii = 1:length(focalDepths)
                focalMenu{ii} = num2str(focalDepths(ii));
            end
            NDPi.Z = focalDepths(menu('Focal depth:',focalMenu));
        else
            NDPi.Z = 0;
        end
        
        % YR = getpixelposition(NDPi.thisAxs); XR = floor(YR(3)); YR = floor(YR(4));
        XR = 3000; YR = 2000;
        calllib('NDPRead','SetCameraResolution',XR, YR);
        [~,~,~,~,~,~,~,bufferSize] = calllib('NDPRead','GetMap',NDPi.filename,1,1,1,1,1,1,1,1);
        [~,~,physPosX,physPosY,physWidth,physHeight,buffer,~,pixelWidth,pixelHeight] = calllib('NDPRead','GetMap',NDPi.filename,1,1,1,1,zeros(bufferSize,1,'uint8'),bufferSize,1,1);
        NDPi.pixelWidth = double(pixelWidth); NDPi.pixelHeight = double(pixelHeight);
        NDPi.physPosX = double(physPosX); NDPi.physPosY = double(physPosY);
        NDPi.physWidth = double(physWidth); NDPi.physHeight = double(physHeight);
        IMG = buildImage(buffer,NDPi.pixelWidth,NDPi.pixelHeight,NDPi.noChannels,NDPi.channelOrder);
        NDPi.dim = size(IMG);
        delete(NDPi.thisAxs);
        NDPi.thisAxs = axes('Parent',NDPi.imagePanel,'Units','Normalized','Position',[0 0 1 1]);
        imshow(IMG,'Border','tight','Parent',NDPi.thisAxs,'InitialMagnification',100);
        set(NDPi.thisFig,'Nextplot','new');
        NDPi.finished = 1;
        
    end
    function exportROIs(varargin)
        % SAVEROIs get the selected regions from the image and saves them.
        % The regions can be saved to file or to the workspace.
        if ~isempty(NDPi.filename) && ~isempty(NDPi.ROIs)
            if varargin{3} % save to file
                saveFolder = uigetdir(NDPi.saveFolder,'Select output folder');
                if ~saveFolder
                    warning('No output folder selected, nothing saved!');
                    return;
                else
                    NDPi.saveFolder = saveFolder;
                end
            end
            
            % Disable interaction:
            busytext = text(mean(get(NDPi.thisAxs,'XLim')),mean(get(NDPi.thisAxs,'YLim')),sprintf('Saving ROIs... (1/%1.0f)',length(NDPi.ROIs)),...
                'HorizontalAlignment','Center','FontSize',20,'Color',[.7 0 0]);
            set(findall(NDPi.thisFig,'Enable','on'),'Enable','off')
            for ii = 1:length(NDPi.ROIs)
                setResizable(NDPi.ROIs(ii),0);
                pos = getPosition(NDPi.ROIs(ii));
                fcn = makeConstrainToRectFcn('imrect',[pos(1) pos(1)+pos(3)], [pos(2) pos(2)+pos(4)]);
                setPositionConstraintFcn(NDPi.ROIs(ii),fcn);
            end
            drawnow;
            
            % Save the data:
            try
                ROInames = get(NDPi.ROIlist,'String');
                zoomLevel = sscanf(NDPi.zoomLevels{get(NDPi.zoomMenu,'Value')},'%fx');
                for ii = 1:length(NDPi.ROIs)
                    set(busytext,'String',sprintf('Saving ROIs... (%1.0f/%1.0f)',ii,length(NDPi.ROIs))); drawnow
                    thisROI = NDPi.ROIs(ii);
                    ROIname = strrep(ROInames{ii},' ','');
                    rect = thisROI.getPosition; rect(2) = NDPi.pixelHeight-rect(2)-rect(4)+1;
                    center = ([rect(1)+rect(3)/2, rect(2)+rect(4)/2] ./ [NDPi.pixelWidth, NDPi.pixelHeight] - [0.5, 0.5]).*[1, -1]; % relative units
                    center = (center .* [NDPi.physWidth, NDPi.physHeight]) + [NDPi.physPosX,NDPi.physPosY];
                    fullRes = mean([NDPi.physWidth/NDPi.fullPixelWidth, NDPi.physHeight/NDPi.fullPixelHeight])*NDPi.sourceLens;  % nm/pixel for the full thing at 1x zoom
                    reqRes = fullRes/zoomLevel; % nm/pixel for the requested image.
                    reqSize = [rect(3), rect(4)]./[NDPi.pixelWidth, NDPi.pixelHeight].*[NDPi.physWidth, NDPi.physHeight];  % requested size in nm;
                    reqPix = round(reqSize/reqRes);
                    
                    calllib('NDPRead','SetCameraResolution',reqPix(1), reqPix(2));
                    [~,~,~,~,~,bufferSize] = calllib('NDPRead','GetImageData',NDPi.filename,center(1),center(2),0,zoomLevel,0,0,0,0);
                    [~,~,physWidth,physHeight,buffer,~] = calllib('NDPRead','GetImageData',NDPi.filename,center(1),center(2),NDPi.Z,zoomLevel,0,0,zeros(1,bufferSize,'uint8'),bufferSize);
                    physWidth = double(physWidth); physHeight = double(physHeight);
                    IMG = buildImage(buffer,reqPix(1),reqPix(2),NDPi.noChannels,NDPi.channelOrder);
                    dimensions = [physWidth,physHeight];
                    if ~isempty(IMG)
                        if varargin{3}  % Save to File
                            [~,originalFile] = fileparts(NDPi.filename);
                            outputFile = fullfile(saveFolder,sprintf('%s_%s_zoom%1.3g.jpg',originalFile,ROIname,zoomLevel));
                            if exist(outputFile,'file')
                                choice = questdlg(sprintf('File %s_%s_zoom%1.3g.jpg exists, overwrite?',originalFile,ROIname,zoomLevel),'Overwrite?','Yes','No','No');
                                if ~strcmp(choice,'Yes')
                                    num = 0;
                                    while exist(outputFile,'file')
                                        num = num+1;
                                        outputFile = fullfile(saveFolder,sprintf('%s_%s_zoom%1.3g_%1.0f.jpg',originalFile,ROIname,zoomLevel,num));
                                    end
                                    fprintf('File saved as %s.\n',outputFile);
                                end
                            end
                            imwrite(IMG,outputFile,'jpg');
                        else            % Save to Workspace
                            if regexp(ROIname(1),'[0-9_ ]')
                                ROIname = ['ROI' ROIname]; %#ok<AGROW>
                            end
                            assignin('base',ROIname,IMG);
                            assignin('base',[ROIname '_dimensions'], dimensions);
                        end
                    end
                end
            catch ME
                warning('Error: %s',ME.message);
            end
            
            % Re-enable interaction:
            delete(busytext)
            set(findall(NDPi.thisFig,'Enable','off'),'Enable','on')
            for ii = 1:length(NDPi.ROIs)
                setResizable(NDPi.ROIs(ii),1);
                fcn = makeConstrainToRectFcn('imrect',get(NDPi.thisAxs,'XLim'), get(NDPi.thisAxs,'YLim'));
                setPositionConstraintFcn(NDPi.ROIs(ii),fcn);
            end
        else
            fprintf('No file loaded or ROI created.\n');
        end
    end
    function saveROIs(varargin)
        N = length(NDPi.ROIs);
        if N
            set(findall(NDPi.thisFig,'Enable','on'),'Enable','off')
            [filename,PathName] = uiputfile('*.csv','Save ROIs as',[NDPi.filename,'.csv']);
            if filename
                filename = fullfile(PathName,filename);
                roiNames = get(NDPi.ROIlist,'String');
                roiData = zeros(N,4);
                fid = fopen(filename,'wt');
                for ii = 1:length(NDPi.ROIs)
                    rect = NDPi.ROIs(ii).getPosition;
                    rect(2) = NDPi.pixelHeight-rect(2)-rect(4)+1;
                    center = ([rect(1)+rect(3)/2, rect(2)+rect(4)/2] ./ [NDPi.pixelWidth, NDPi.pixelHeight] - [0.5, 0.5]).*[1, -1]; % relative units
                    center = (center .* [NDPi.physWidth, NDPi.physHeight]) + [NDPi.physPosX,NDPi.physPosY];
                    fullRes = mean([NDPi.physWidth/NDPi.fullPixelWidth, NDPi.physHeight/NDPi.fullPixelHeight])*NDPi.sourceLens;
                    reqSize = [rect(3), rect(4)]./[NDPi.pixelWidth, NDPi.pixelHeight].*[NDPi.physWidth, NDPi.physHeight];  % requested size in nm;
                    reqPix = reqSize/fullRes;
                    roiData(ii,:) = [center, reqPix];
                    fprintf(fid, '%s,%1.15E,%1.15E,%1.15E,%1.15E\n', roiNames{ii},roiData(ii,:));
                end
                fclose(fid);
            end
            set(findall(NDPi.thisFig,'Enable','off'),'Enable','on')
        end
    end
    function loadROIs(varargin)
        set(findall(NDPi.thisFig,'Enable','on'),'Enable','off')
        [filename,PathName] = uigetfile('*.csv','Load ROIs file',[NDPi.filename,'.csv']);
        filename = fullfile(PathName,filename);
        if exist(filename,'file')
            fid = fopen(filename);
            data = regexpi(char(fread(fid)'),'[,\n]','split');
            data(cellfun(@isempty,data)) = [];
            fclose(fid);
            N = (length(data))/5;
            if ~rem(N,1)  % Should be integer.
                data = reshape(data,5,[])'; % Reshape to matrix
                data = sortrows(data);      % Sort ROIs alphabetically
                for ii = 1:N
                    currentlist = get(NDPi.ROIlist,'String');
                    NN = length(currentlist);
                    ROIname = data{ii,1};
                    center = str2double(data(ii,[2,3]));
                    reqPix = str2double(data(ii,[4,5]));
                    rect = zeros(1,4);
                    fullRes = mean([NDPi.physWidth/NDPi.fullPixelWidth, NDPi.physHeight/NDPi.fullPixelHeight])*NDPi.sourceLens;
                    reqSize = reqPix*fullRes;
                    rect(3:4) = reqSize./[NDPi.physWidth, NDPi.physHeight].*[NDPi.pixelWidth, NDPi.pixelHeight];
                    center = (center - [NDPi.physPosX,NDPi.physPosY])./[NDPi.physWidth, NDPi.physHeight];
                    rect(1:2) = (center./[1, -1] + [0.5, 0.5]).*[NDPi.pixelWidth, NDPi.pixelHeight] - rect(3:4)/2;
                    rect(2) = NDPi.pixelHeight-rect(4)+1-rect(2);
                    
                    thisROI = imrect(NDPi.thisAxs,rect);
                    fcn = makeConstrainToRectFcn('imrect',[0, NDPi.dim(2)]+0.5, [0, NDPi.dim(1)]+0.5);
                    setPositionConstraintFcn(thisROI,fcn);
                    setConstrainedPosition(thisROI,getPosition(thisROI));
                    
                    number = 1; roiName = ROIname;
                    while ismember(ROIname,currentlist)
                        number = number+1;
                        ROIname = sprintf('%s_%1.0f',roiName,number);
                    end
                    currentlist{NN+1} = ROIname;
                    if ~NN,
                        NDPi.ROIs = thisROI;
                    else
                        NDPi.ROIs(NN+1) = thisROI;
                    end
                    set(NDPi.ROIlist,'String',currentlist)
                end
                selectCorrect(NN+1)
            end
        end
        set(findall(NDPi.thisFig,'Enable','off'),'Enable','on')
    end
    function createROI(varargin)
        % CREATEROI creates an ROI on the image.
        set(findall(NDPi.thisFig,'Enable','on'),'Enable','off')
        thisROI = imrect(NDPi.thisAxs);
        if ~isempty(thisROI)
            fcn = makeConstrainToRectFcn('imrect',[0, NDPi.dim(2)]+0.5, [0, NDPi.dim(1)]+0.5);
            setPositionConstraintFcn(thisROI,fcn);
            setConstrainedPosition(thisROI,getPosition(thisROI));
            currentlist = get(NDPi.ROIlist,'String');
            N = length(currentlist);
            number = 1; ROIname = sprintf('ROI %02.0f',number);
            while ismember(ROIname,currentlist)
                number = number+1;
                ROIname = sprintf('ROI %02.0f',number);
            end
            currentlist{N+1} = ROIname;
            if ~N,
                NDPi.ROIs = thisROI;
            else
                NDPi.ROIs(N+1) = thisROI;
            end
            set(NDPi.ROIlist,'String',currentlist)
            selectCorrect(N+1)
        end
        set(findall(NDPi.thisFig,'Enable','off'),'Enable','on')
    end
    function deleteROI(varargin)
        % DELETEROI deletes the currently selected ROI
        N = get(NDPi.ROIlist,'Value');
        if ~isempty(NDPi.ROIs) && ~isempty(N)
            currentlist = get(NDPi.ROIlist,'String');
            currentlist(N) = [];
            set(NDPi.ROIlist,'String',currentlist,'Value',max([1 min(N-1)]))
            delete(NDPi.ROIs(N));
            NDPi.ROIs(N) = [];
            selectCorrect(max([1 min(N-1)]));
        end
    end
    function selectCorrect(N)
        % SELECTCORRECT highlights the selected ROI.
        set(NDPi.ROIlist,'Value',N);
        if ~isempty(NDPi.ROIs)
            for ii = 1:length(NDPi.ROIs)
                setColor(NDPi.ROIs(ii),[.5 .5 .5]);
            end
            for ii = N
                setColor(NDPi.ROIs(ii),'b');
            end
        end
    end
    function listSelect(varargin)
        % LISTSELECT is called when the user selects an ROI
        % The correct ROI will then be highlighted, and its name can be
        % changed.
        if ~isempty(NDPi.ROIs)
            N = get(NDPi.ROIlist,'Value');
            selectCorrect(N);
            if strcmpi(get(NDPi.thisFig,'SelectionType'),'open')
                roinames = get(NDPi.ROIlist,'String');
                roiname = roinames{N(1)};
                answer = inputdlg('ROI Name:','Change ROI name',1,{roiname});
                if ~isempty(answer)
                    answer = strtrim(regexprep(answer{1},'[^a-zA-Z0-9_ ]',''));
                    if ~isempty(answer)
                        if ismember(answer,roinames(setdiff(1:length(roinames),N(1))))
                            msgbox(sprintf('ROI name ''%s'' already exists.',answer),'Error','warn');
                            return
                        end
                        roinames{N(1)} = answer;
                        set(NDPi.ROIlist,'String',roinames);
                    end
                end
            end
        end
    end
    function changeThreshold(varargin)
        % CHANGETHRESHOLD is called when the auto-roi threshold is changed
        handle = varargin{1};
        switch handle
            case NDPi.threshSlide
                value = get(handle,'Value');
            case NDPi.threshEdit
                value = str2double(get(handle,'String'));
                backup = get(NDPi.threshSlide,'Value');
        end
        if ~isempty(value) && value>=0 && value<=255
            set(NDPi.threshSlide,'Value',round(value));
            set(NDPi.threshEdit,'String',sprintf('%1.0f',value));
        else
            set(NDPi.threshEdit,'String',sprintf('%1.0f',backup));
        end
    end
    function IMG = buildImage(rawdata,width,height,channels,channelOrder)
        % BUILDIMAGE creates an image from the raw data from the NDPi file
        IMG = uint8(zeros(height,width,channels));
        linesize = ceil((width*channels)/4)*4;
        for X = 1:height
            position = (X-1)*linesize+1;
            currentline = rawdata(position:position+linesize-1);
            currentline = currentline(1:width*3);
            currentline = reshape(currentline,3,width);
            currentline = permute(currentline,[2,1]);
            if channelOrder==1
                IMG(X,:,3:-1:1) = currentline;
            elseif channelOrder==2
                IMG(X,:,1:3) = currentline;
            elseif channelOrder==3
                IMG(X,:,1) = currentline;
            else
                error('Number of channels undefined!')
            end
        end
        IMG = IMG(end:-1:1,:,:);
    end
    function autoSeparate(varargin)
        % AUTOSEPARATE creates ROIs automatically
        set(findall(NDPi.thisFig,'Enable','on'),'Enable','off')
        IMG1 = mean(get(findobj(NDPi.thisAxs,'Type','image'),'CData'),3);
        thresh = get(NDPi.threshSlide,'Value');
        IMG = imresize(IMG1,[400, NaN]);
        IMG = IMG(:,:)<=thresh;
        IMG = bwmorph(bwmorph(IMG,'fill'),'dilate');
        [BW1, num] = bwlabeln(IMG);
        BW = imresize(BW1,size(IMG1),'nearest');
        
        for jj = 1:num
            if sum(BW1(:)==jj)<250
                continue;
            end
            currentlist = get(NDPi.ROIlist,'String');
            N = length(currentlist);
            maxCol = max(BW==jj,[],2);
            maxRow = max(BW==jj);
            subIMG = [find(maxRow,1,'first'), find(maxCol,1,'first'), find(maxRow,1,'last'), find(maxCol,1,'last')];
            subIMG(3:4) = subIMG(3:4)-subIMG(1:2)+1;
            subIMG(1:2) = subIMG(1:2)-0.5;
            thisROI = imrect(NDPi.thisAxs,subIMG);
            fcn = makeConstrainToRectFcn('imrect',[0, NDPi.dim(2)]+0.5, [0, NDPi.dim(1)]+0.5);
            setPositionConstraintFcn(thisROI,fcn);
            setConstrainedPosition(thisROI,getPosition(thisROI));
            number = 1; ROIname = sprintf('ROI %02.0f',number);
            while ismember(ROIname,currentlist)
                number = number+1;
                ROIname = sprintf('ROI %02.0f',number);
            end
            currentlist{N+1} = ROIname;
            if ~N,
                NDPi.ROIs = thisROI;
            else
                NDPi.ROIs(N+1) = thisROI;
            end
            set(NDPi.ROIlist,'String',currentlist)
            selectCorrect(N+1)
        end
        set(findall(NDPi.thisFig,'Enable','off'),'Enable','on')
    end
    function keyPressed(varargin)
        % KEYPRESSED is run when the user presses a key
        key = varargin{2};
        if strcmpi(key.Key,'delete')
            deleteROI();
        end
    end
    function closeWindow(varargin)
        % CLOSEWINDOW is called when the program exits, to clean up.
        if NDPi.finished
            calllib('NDPRead','CleanUp');
            [INIpath, INIname] = fileparts(mfilename('fullpath'));
            INI = struct;
            INI.General.filename = NDPi.filename;
            INI.General.zoomlevel = get(NDPi.zoomMenu,'Value');
            INI.General.savefolder = NDPi.saveFolder;
            if exist('headerReader.m','file');
                headerWriter(INI,fullfile(INIpath,[INIname '.config']));
            end
        end
        delete(NDPi.thisFig);
    end
    
end