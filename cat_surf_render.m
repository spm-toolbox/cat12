function varargout = cat_surf_render(action,varargin)
% Display a surface mesh & various utilities
% FORMAT H = cat_surf_render('Disp',M,'PropertyName',propertyvalue)
% M        - a GIfTI filename/object or patch structure
% H        - structure containing handles of various objects
% Opens a new figure unless a 'parent' Property is provided with an axis
% handle.
%
% FORMAT H = cat_surf_render(M)
% Shortcut to previous call format.
%
% FORMAT H = cat_surf_render('ContextMenu',AX)
% AX       - axis handle or structure returned by cat_surf_render('Disp',...)
%
% FORMAT H = cat_surf_render('Overlay',AX,P)
% AX       - axis handle or structure given by cat_surf_render('Disp',...)
% P        - data to be overlayed on mesh (see spm_mesh_project)
%
% FORMAT H = cat_surf_render('ColourBar',AX,MODE)
% AX       - axis handle or structure returned by cat_surf_render('Disp',...)
% MODE     - {['on'],'off'}
%
% FORMAT H = vbm_mesh_render('Clim',AX,[mn mx])
% AX       - axis handle or structure given by vbm_mesh_render('Disp',...)
% mn mx    - min/max of range
%
% FORMAT H = vbm_mesh_render('Clip',AX,[mn mx])
% AX       - axis handle or structure given by vbm_mesh_render('Disp',...)
% mn mx    - min/max of clipping range
%
% FORMAT H = cat_surf_render('ColourMap',AX,MAP)
% AX       - axis handle or structure returned by cat_surf_render('Disp',...)
% MAP      - a colour map matrix
%
% FORMAT MAP = cat_surf_render('ColourMap',AX)
% Retrieves the current colourmap.
%
% FORMAT H = cat_surf_render('Underlay',AX,P)
% AX       - axis handle or structure given by cat_surf_render('Disp',...)
% P        - data (curvature) to be underlayed on mesh (see spm_mesh_project)
%
% FORMAT H = cat_surf_render('Clim',AX, range)
% range    - range of colour scaling
%
% FORMAT H = cat_surf_render('SaveAs',AX, filename)
% filename - filename
%
% FORMAT cat_surf_render('Register',AX,hReg)
% AX       - axis handle or structure returned by cat_surf_render('Disp',...)
% hReg     - Handle of HandleGraphics object to build registry in.
% See spm_XYZreg for more information.
%__________________________________________________________________________
% Copyright (C) 2010-2011 Wellcome Trust Centre for Neuroimaging

% based on spm_mesh_render.m
% $Id$

%-Input parameters
%--------------------------------------------------------------------------
if ~nargin, action = 'Disp'; end

if ~ischar(action)
    varargin = {action varargin{:}};
    action   = 'Disp';
end

varargout = {[]};

%-Action
%--------------------------------------------------------------------------
switch lower(action)
    
    %-Display
    %======================================================================
    case 'disp'
        if isempty(varargin)
            [M, sts] = spm_select(1,'mesh','Select surface mesh file');
            if ~sts, return; end
        else
            M = varargin{1};
        end
        if ischar(M) || isstruct(M) % default - one surface
            M  = gifti(M); 
        elseif iscellstr(M) % multiple surfaces
          %%
            MS = M; % save filelist 
            M  = gifti(MS{1}); 
            for mi = 2:numel(MS)
                try
                    MI         = gifti(MS{mi});
                    M.faces    = [M.faces; MI.faces + size(M.vertices,1)];   % further faces with increased vertices ids
                    M.vertices = [M.vertices; MI.vertices];                 % further points at the end of the list
                    if isfield(M,'cdata');
                        M.cdata  = [M.cdata; MI.cdata];                     % further texture values at the end of the list
                    end
                catch
                    error('cat_surf_render:multisurf','Error adding surface %d: ''%s''.\n',mi,MS{mi});
                end
            end
        end
        if ~isfield(M,'vertices')
            try
                MM = M;
                M  = gifti(MM.private.metadata(1).value);
                try %#ok<TRYNC>
                    M.cdata = MM.cdata();
                end
            catch
                error('Cannot find a surface mesh to be displayed.');
            end
        end
        O = getOptions(varargin{2:end});
        
        if isfield(O,'cdata') % data input
            M.cdata = O.cdata; 
        elseif isfield(O,'pcdata') % single file input 
            if ischar(O.pcdata)
                [pp,ff,ee] = fileparts(O.pcdata);
                if strcmp(ee,'.gii')
                    Mt = gifti(O.pcdata);
                    M.cdata = Mt.cdata;
                elseif strcmp(ee,'.annot')
                  labelmap = zeros(0); labelnam = cell(0); ROIv = zeros(0);
            
                  %%
                    [fsv,cdata,colortable] = cat_io_FreeSurfer('read_annotation',O.pcdata); %clear fsv;
                    [sentry,id] = sort(colortable.table(:,5));
                    M.cdata = cdata; nid=1;
                    for sentryi = 1:numel(sentry)
                      ROI = round(cdata)==sentry(sentryi); 
                      if sum(ROI)>0 && ( (sentryi==numel(sentry)) || sentry(sentryi)~=sentry(sentryi+1) && ...
                        (sentryi==1 || sentry(sentryi)~=sentry(sentryi+1))), 
                        M.cdata(round(cdata)==sentry(sentryi)) = nid;  
                        labelmap(nid,:) = colortable.table(id(sentryi),1:3)/255;
                        labelnam(nid)   = colortable.struct_names(id(sentryi));
                        nid=nid+1;
                        ROIv(nid) = sum(ROI); 
                      end
                    end
                    %labelmap = colortable.table(id,1:3)/255;
                    % addition maximum element
                    M.cdata(M.cdata>=colortable.numEntries)=0; %colortable.numEntries+1;  
                    labelmapclim = [min(M.cdata),max(M.cdata)];
                    %labelnam = colortable.struct_names(id);
                else
                    M.cdata = cat_io_FreeSurfer('read_surf_data',O.pcdata);
                end
            elseif iscell(O.pcdata) % multifile input
                if ~exist('MS','var') || numel(O.pcdata)~=numel(MS)
                    error('cat_surf_render:multisurfcdata',...
                      'Number of meshes and texture files must be equal.\n');
                end
                [pp,ff,ee] = fileparts(O.pcdata{mi});
                if strcmp(ee,'.gii')
                    M = gifti(O.pcdata{1});
                 elseif strcmp(ee,'.annot')
                  %%
                    [fsv,cdata,colortable] = cat_io_FreeSurfer('read_annotation',O.pcdata{1}); %clear fsv;
                    [sentry,id] = sort(colortable.table(:,5));
                    M.cdata = cdata; nid=1;
                    for sentryi = 1:numel(sentry)
                      ROI = round(cdata)==sentry(sentryi); 
                      if sum(ROI)>0 && ( (sentryi==numel(sentry)) || sentry(sentryi)~=sentry(sentryi+1) && ...
                        (sentryi==1 || sentry(sentryi)~=sentry(sentryi+1))), 
                        M.cdata(round(cdata)==sentry(sentryi)) = nid;  
                        labelmap(nid,:) = colortable.table(id(sentryi),1:3)/255;
                        labelnam(nid)   = colortable.struct_names(id(sentryi));
                        nid=nid+1;
                        ROIv(nid) = sum(ROI); 
                      end
                    end
                    %labelmap = colortable.table(id,1:3)/255;
                    % addition maximum element
                    M.cdata(M.cdata>colortable.numEntries)=0; %colortable.numEntries+1;  
                    labelmapclim = [min(M.cdata),max(M.cdata)];
                    %labelnam = colortable.struct_names(id);
                else
                    M.cdata = cat_io_FreeSurfer('read_surf_data',O.pcdata{1});
                end
                for mi = 2:numel(MS)
                    [pp,ff,ee] = fileparts(O.pcdata{mi});
                    if strcmp(ee,'.gii')
                        Mt = gifti(O.pcdata{mi});
                    elseif strcmp(ee,'.annot')
                      %%
                        [fsv,cdata,colortable] = cat_io_FreeSurfer('read_annotation',O.pcdata{mi}); %clear fsv;
                        [sentry,id] = sort(colortable.table(:,5));
                        Mt.cdata = cdata; 
                        for sentryi = 1:numel(sentry)
                          ROI = round(cdata)==sentry(sentryi); 
                          if sum(ROI)>0 && ( (sentryi==numel(sentry)) || sentry(sentryi)~=sentry(sentryi+1) && ...
                            (sentryi==1 || sentry(sentryi)~=sentry(sentryi+1))), 
                            Mt.cdata(round(cdata)==sentry(sentryi)) = nid;  
                            labelmap(nid,:) = colortable.table(id(sentryi),1:3)/255;
                            labelnam(nid)   = colortable.struct_names(id(sentryi));
                            nid=nid+1;
                            ROIv(nid) = sum(ROI); 
                          end
                        end
                        %labelmap = colortable.table(id,1:3)/255;
                        % addition maximum element
                        Mt.cdata(Mt.cdata>=colortable.numEntries + labelmapclim(2))=0; %colortable.numEntries+1;  
                        %labelnam = colortable.struct_names(id);
                    else
                        Mt.cdata = cat_io_FreeSurfer('read_surf_data',O.pcdata{mi});
                    end
                    M.cdata = [M.cdata;Mt.cdata];
                    labelmapclim = [min(M.cdata),max(M.cdata)];
                end
                if size(M.vertices,1)~=numel(M.cdata); 
                  warning('cat_surf_render:multisurfcdata',...
                    'Surface data error (number of vertices does not match number of surface data), remove texture.\n');
                  M = rmfield(M,'cdata');
                end
            end 
        end
        if ~isfield(M,'vertices') || ~isfield(M,'faces')
            error('cat_surf_render:nomesh','ERROR:cat_surf_render: No input mesh in ''%s''', varargin{1});
        end
        
        M = export(M,'patch');
        
        %-Figure & Axis
        %------------------------------------------------------------------
        if isfield(O,'parent')
            H.axis   = O.parent;
            H.figure = ancestor(H.axis,'figure');
            figure(H.figure); axes(H.axis);
        else
            H.figure = figure('Color',[1 1 1]);
            H.axis   = axes('Parent',H.figure);
            set(H.axis,'Visible','off');
        end
        renderer = get(H.figure,'Renderer');
        set(H.figure,'Renderer','OpenGL');
        
        if isfield(M,'facevertexcdata')
          H.cdata = M.facevertexcdata;
        else
          H.cdata = []; 
        end
        
        %-Patch
        %------------------------------------------------------------------
        P = struct('vertices',M.vertices, 'faces',M.faces);
        H.patch = patch(P,...
            'FaceColor',        [0.6 0.6 0.6],...
            'EdgeColor',        'none',...
            'FaceLighting',     'gouraud',... phong got print problems
            'SpecularStrength', 0.0,... 0.7
            'AmbientStrength',  0.4,... 0.1
            'DiffuseStrength',  0.6,... 0.7
            'BackFaceLighting', 'unlit', ... for inner light 
            'SpecularExponent', 10,...
            'Clipping',         'off',...
            'DeleteFcn',        {@myDeleteFcn, renderer},...
            'Visible',          'off',...
            'Tag',              'CATSurfRender',...
            'Parent',           H.axis);
        setappdata(H.patch,'patch',P);
        
        %-Label connected components of the mesh
        %------------------------------------------------------------------
        C = spm_mesh_label(P);
        setappdata(H.patch,'cclabel',C);
        
        %-Compute mesh curvature
        %------------------------------------------------------------------
        curv = spm_mesh_curvature(P); %$ > 0;
        setappdata(H.patch,'curvature',curv);
        
        %-Apply texture to mesh
        %------------------------------------------------------------------
        if isfield(M,'facevertexcdata')
            T = M.facevertexcdata;
        else
            T = [];
        end
        updateTexture(H,T);
        
        %-Set viewpoint, light and manipulation options
        %------------------------------------------------------------------
        axis(H.axis,'image');
        axis(H.axis,'off');
        view(H.axis,[-90 0]);
        material(H.figure,'dull');
        H.light = light('Position',[0 0 0]); %camlight; set(H.light,'Parent',H.axis);
        
        H.rotate3d = rotate3d(H.axis);
        set(H.rotate3d,'Enable','on');
        set(H.rotate3d,'ActionPostCallback',{@myPostCallback, H});
        %try
        %    setAllowAxesRotate(H.rotate3d, ...
        %        setxor(findobj(H.figure,'Type','axes'),H.axis), false);
        %end
        
        %-Store handles
        %------------------------------------------------------------------
        setappdata(H.axis,'handles',H);
        set(H.patch,'Visible','on');
        
        setappdata(H.patch,'clip',[false NaN NaN]);

        if exist('labelmap','var')
          setappdata(H.patch,'colourmap',labelmap);
          cat_surf_render('clim',H.axis,labelmapclim - [0 1]);
          
          H = cat_surf_render('ColorBar',H.axis,'on'); 
          labelnam2 = labelnam; for lni=1:numel(labelnam2),labelnam2{lni} = [' ' labelnam2{lni} ' ']; end
          ytick = labelmapclim(1):max(1,round(diff(labelmapclim)/80)):labelmapclim(2);
          set(H.colourbar,'ytick',ytick,'yticklabel',labelnam2(1:max(1,round(diff(labelmapclim)/30)):end)); 
        end
        
        %-Add context menu
        %------------------------------------------------------------------
        cat_surf_render('ContextMenu',H);
        
    %-Context Menu
    %======================================================================
    case 'contextmenu'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if ~isempty(get(H.patch,'UIContextMenu')), return; end
        
        cmenu = uicontextmenu('Callback',{@myMenuCallback, H});
        
        uimenu(cmenu, 'Label','Inflate', 'Interruptible','off', ...
            'Callback',{@myInflate, H});
        
        uimenu(cmenu, 'Label','Overlay...', 'Interruptible','off', ...
            'Callback',{@myOverlay, H});
        
        uimenu(cmenu, 'Label','Image Sections...', 'Interruptible','off', ...
            'Callback',{@myImageSections, H});
        
        uimenu(cmenu, 'Label','Change geometry...', 'Interruptible','off', ...
            'Callback',{@myChangeGeometry, H});
        
        c = uimenu(cmenu, 'Label', 'Connected Components', 'Interruptible','off');
        C = getappdata(H.patch,'cclabel');
        for i=1:length(unique(C))
            uimenu(c, 'Label',sprintf('Component %d',i), 'Checked','on', ...
                'Callback',{@myCCLabel, H});
        end
        
        uimenu(cmenu, 'Label','Rotate', 'Checked','on', 'Separator','on', ...
            'Callback',{@mySwitchRotate, H});
        
        uimenu(cmenu, 'Label','Synchronise Views', 'Visible','off', ...
            'Checked','off', 'Tag','SynchroMenu', 'Callback',{@mySynchroniseViews, H});
        
        c = uimenu(cmenu, 'Label','View');
        uimenu(c, 'Label','Go to Y-Z view (right)',  'Callback', {@myView, H, [90 0]});
        uimenu(c, 'Label','Go to Y-Z view (left)',   'Callback', {@myView, H, [-90 0]});
        uimenu(c, 'Label','Go to X-Y view (top)',    'Callback', {@myView, H, [0 90]});
        uimenu(c, 'Label','Go to X-Y view (bottom)', 'Callback', {@myView, H, [-180 -90]});
        uimenu(c, 'Label','Go to X-Z view (front)',  'Callback', {@myView, H, [-180 0]});
        uimenu(c, 'Label','Go to X-Z view (back)',   'Callback', {@myView, H, [0 0]});
        
        uimenu(cmenu, 'Label','Colorbar', 'Callback', {@myColourbar, H});
        
        c = uimenu(cmenu, 'Label','Colormap');
        clrmp = {'hot' 'jet' 'gray' 'hsv' 'bone' 'copper' 'pink' 'white' ...
            'flag' 'lines' 'colorcube' 'prism' 'cool' 'autumn' ...
             'spring' 'winter' 'summer'};
        for i=1:numel(clrmp)
            uimenu(c, 'Label', clrmp{i}, 'Callback', {@myColourmap, H});
        end
        
        c = uimenu(cmenu, 'Label','Transparency');
        uimenu(c, 'Label','0%',  'Checked','on',  'Callback', {@myTransparency, H});
        uimenu(c, 'Label','20%', 'Checked','off', 'Callback', {@myTransparency, H});
        uimenu(c, 'Label','40%', 'Checked','off', 'Callback', {@myTransparency, H});
        uimenu(c, 'Label','60%', 'Checked','off', 'Callback', {@myTransparency, H});
        uimenu(c, 'Label','80%', 'Checked','off', 'Callback', {@myTransparency, H});
        
        uimenu(cmenu, 'Label','Data Cursor', 'Callback', {@myDataCursor, H});
        
        c = uimenu(cmenu, 'Label','Background Color');
        uimenu(c, 'Label','White',     'Callback', {@myBackgroundColor, H, [1 1 1]});
        uimenu(c, 'Label','Black',     'Callback', {@myBackgroundColor, H, [0 0 0]});
        uimenu(c, 'Label','Custom...', 'Callback', {@myBackgroundColor, H, []});
        
        uimenu(cmenu, 'Label','Slider', 'Checked', 'off', 'Callback', {@myAddslider, H});

        uimenu(cmenu, 'Label','Save As...', 'Separator', 'on', ...
            'Callback', {@mySave, H});
        
        set(H.rotate3d,'enable','off');
        try set(H.rotate3d,'uicontextmenu',cmenu); end
        try set(H.patch,   'uicontextmenu',cmenu); end
        set(H.rotate3d,'enable','on');
        
        dcm_obj = datacursormode(H.figure);
        set(dcm_obj, 'Enable','off', 'SnapToDataVertex','on', ...
            'DisplayStyle','Window', 'Updatefcn',{@myDataCursorUpdate, H});
        
    %-View
    %======================================================================
    case 'view'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        myView([],[],H,varargin{2});

    %-SaveAs
    %======================================================================
    case 'saveas'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        mySavePNG(H.patch,[],H, varargin{2});

    %-Underlay
    %======================================================================
    case 'underlay'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if nargin < 3, varargin{2} = []; end

        v = varargin{2};
        if ischar(v)
          [p,n,e] = fileparts(v);
          if ~strcmp(e,'.mat') & ~strcmp(e,'.nii') & ~strcmp(e,'.gii') & ~strcmp(e,'.img') % freesurfer format
            v = cat_io_FreeSurfer('read_surf_data',v);
          else
            try spm_vol(v); catch, v = gifti(v); end;
          end
        end
        if isa(v,'gifti')
          v = v.cdata;
        else
          error('File has to be gifti-format');
        end

        setappdata(H.patch,'curvature',v);
        setappdata(H.axis,'handles',H);

    %-Overlay
    %======================================================================
    case 'overlay'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if nargin < 3, varargin{2} = []; end
        updateTexture(H,varargin{2:end});
        
    %-Slices
    %======================================================================
    case 'slices'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if nargin < 3, varargin{2} = []; end
        renderSlices(H,varargin{2:end});
    
    %-ColourBar
    %======================================================================
    case {'colourbar', 'colorbar'}
        if isempty(varargin), varargin{1} = gca; end
        if length(varargin) == 1, varargin{2} = 'on'; end
        H   = getHandles(varargin{1});
        d   = getappdata(H.patch,'data');
        col = getappdata(H.patch,'colourmap');
        if strcmpi(varargin{2},'off')
            if isfield(H,'colourbar') && ishandle(H.colourbar)
                delete(H.colourbar);
                H = rmfield(H,'colourbar');
                setappdata(H.axis,'handles',H);
            end
            return;
        end
        if isempty(d) || ~any(d(:)), varargout = {H}; return; end
        if isempty(col), col = hot(256); end
        if ~isfield(H,'colourbar') || ~ishandle(H.colourbar)
            H.colourbar = colorbar('peer',H.axis);
            set(H.colourbar,'Tag','');
            set(get(H.colourbar,'Children'),'Tag','');
        end
        c(1:size(col,1),1,1:size(col,2)) = col;
        ic = findobj(H.colourbar,'Type','image');
        clim = getappdata(H.patch, 'clim');
        if isempty(clim), clim = [false NaN NaN]; end

        % Update colorbar colors if clipping is used
        clip = getappdata(H.patch, 'clip');
        if ~isempty(clip)
            if ~isnan(clip(2)) && ~isnan(clip(3))
                ncol = length(col);
                col_step = (clim(3) - clim(2))/ncol;
                cmin = max([1,ceil((clip(2)-clim(2))/col_step)]);
                cmax = min([ncol,floor((clip(3)-clim(2))/col_step)]);
                col(cmin:cmax,:) = repmat([0.5 0.5 0.5],(cmax-cmin+1),1);
                c(1:size(col,1),1,1:size(col,2)) = col;
            end
        end
        if size(d,1) > 1
            set(ic,'CData',c(1:size(d,1),:,:));
            set(ic,'YData',[1 size(d,1)]);
            set(H.colourbar,'YLim',[1 size(d,1)]);
            set(H.colourbar,'YTickLabel',[]);
        else
            set(ic,'CData',c);
            clim = getappdata(H.patch,'clim');
            if isempty(clim), clim = [false min(d) max(d)]; end
            set(ic,'YData',clim(2:3));
            set(H.colourbar,'YLim',clim(2:3));
        end
        setappdata(H.axis,'handles',H);
        
    %-ColourMap
    %======================================================================
    case {'colourmap', 'colormap'}
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if length(varargin) == 1
            varargout = { getappdata(H.patch,'colourmap') };
            return;
        else
            setappdata(H.patch,'colourmap',varargin{2});
            d = getappdata(H.patch,'data');
            updateTexture(H,d);
        end
        
%         
%     %-ColourMap
%     %======================================================================
%     case {'labelmap'}
%         if isempty(varargin), varargin{1} = gca; end
%         H = getHandles(varargin{1});
%         if length(varargin) == 1
%             varargout = { getappdata(H.patch,'labelmap') };
%             return;
%         else
%             setappdata(H.patch,'labelmap',varargin{2});
%             d = getappdata(H.patch,'data');
%             updateTexture(H,d,getappdata(H.patch,'labelmap'),'flat');
%         end     
        
    
    %-CLim
    %======================================================================
    case 'clim'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if length(varargin) == 1
            c = getappdata(H.patch,'clim');
            if ~isempty(c), c = c(2:3); end
            varargout = { c };
            return;
        else
            if isempty(varargin{2}) || any(~isfinite(varargin{2}))
                setappdata(H.patch,'clim',[false NaN NaN]);
            else
                setappdata(H.patch,'clim',[true varargin{2}]);
            end
            d = getappdata(H.patch,'data');
            updateTexture(H,d);
        end
        
    %-CLip
    %======================================================================
    case 'clip'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if length(varargin) == 1
            c = getappdata(H.patch,'clip');
            if ~isempty(c), c = c(2:3); end
            varargout = { c };
            return;
        else
            if isempty(varargin{2}) || any(~isfinite(varargin{2}))
                setappdata(H.patch,'clip',[false NaN NaN]);
            else
                setappdata(H.patch,'clip',[true varargin{2}]);
            end
            d = getappdata(H.patch,'data');
            updateTexture(H,d);
        end
        
    %-Register
    %======================================================================
    case 'register'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        hReg = varargin{2};
        xyz  = spm_XYZreg('GetCoords',hReg);
        hs   = myCrossBar('Create',H,xyz);
        set(hs,'UserData',hReg);
        spm_XYZreg('Add2Reg',hReg,hs,@myCrossBar);
        
    %-Slider
    %======================================================================
    case 'slider'
        if isempty(varargin), varargin{1} = gca; end
        if length(varargin) == 1, varargin{2} = 'on'; end
        H = getHandles(varargin{1});
        if strcmpi(varargin{2},'off')
            if isfield(H,'slider') && ishandle(H.slider)
                delete(H.slider);
                H = rmfield(H,'slider');
                setappdata(H.axis,'handles',H);
            end
            return;
        else
            if ~isempty(H.cdata)
                AddSliders(H);
            end
        end
        setappdata(H.axis,'handles',H);

    %-Otherwise...
    %======================================================================
    otherwise
        try
            H = cat_surf_render('Disp',action,varargin{:});
        catch
            error('Unknown action.');
        end
end

varargout = {H};


%==========================================================================
function AddSliders(H)

c = getappdata(H.patch,'clim');
mn = c(2);
mx = c(3);

% allow slider a more extended range
mnx = 1.5*max([-mn mx]);

sliderPanel(...
        'Parent'  , H.figure, ...
        'Title'   , 'Overlay min', ...
        'Position', [0.01 0.01 0.2 0.17], ...
        'Backgroundcolor', [1 1 1],...
        'Min'     , -mnx, ...
        'Max'     , mnx, ...
        'Value'   , mn, ...
        'FontName', 'Verdana', ...
        'FontSize', 8, ...
        'NumFormat', '%f', ...
        'Callback', @slider_clim_min);

sliderPanel(...
        'Parent'  , H.figure, ...
        'Title'   , 'Overlay max', ...
        'Position', [0.21 0.01 0.2 0.17], ...
        'Backgroundcolor', [1 1 1],...
        'Min'     , -mnx, ...
        'Max'     , mnx, ...
        'Value'   , mx, ...
        'FontName', 'Verdana', ...
        'FontSize', 8, ...
        'NumFormat', '%f', ...
        'Callback', @slider_clim_max);

sliderPanel(...
        'Parent'  , H.figure, ...
        'Title'   , 'Clip min', ...
        'Position', [0.01 0.83 0.2 0.17], ...
        'Backgroundcolor', [1 1 1],...
        'Min'     , -mnx, ...
        'Max'     , mnx, ...
        'Value'   , mn, ...
        'FontName', 'Verdana', ...
        'FontSize', 8, ...
        'NumFormat', '%f', ...
        'Callback', @slider_clip_min);

sliderPanel(...
        'Parent'  , H.figure, ...
        'Title'   , 'Clip max', ...
        'Position', [0.21 0.83 0.2 0.17], ...
        'Backgroundcolor', [1 1 1],...
        'Min'     , -mnx, ...
        'Max'     , mnx, ...
        'Value'   , mn, ...
        'FontName', 'Verdana', ...
        'FontSize', 8, ...
        'NumFormat', '%f', ...
        'Callback', @slider_clip_max);

setappdata(H.patch,'clip',[true mn mn]);
setappdata(H.patch,'clim',[true mn mx]);
        
%==========================================================================
function O = getOptions(varargin)
O = [];
if ~nargin
    return;
elseif nargin == 1 && isstruct(varargin{1})
    for i=fieldnames(varargin{1})
        O.(lower(i{1})) = varargin{1}.(i{1});
    end
elseif mod(nargin,2) == 0
    for i=1:2:numel(varargin)
        O.(lower(varargin{i})) = varargin{i+1};
    end
else
    error('Invalid list of property/value pairs.');
end

%==========================================================================
function H = getHandles(H)
if ~nargin || isempty(H), H = gca; end
if ishandle(H) && ~isappdata(H,'handles')
    a = H; clear H;
    H.axis     = a;
    H.figure   = ancestor(H.axis,'figure');
    H.patch    = findobj(H.axis,'type','patch');
    H.light    = findobj(H.axis,'type','light');
    H.rotate3d = rotate3d(H.figure);
    setappdata(H.axis,'handles',H);
elseif ishandle(H)
    H = getappdata(H,'handles');
else
    H = getappdata(H.axis,'handles');
end

%==========================================================================
function myMenuCallback(obj,evt,H)
H = getHandles(H);

h = findobj(obj,'Label','Rotate');
if strcmpi(get(H.rotate3d,'Enable'),'on')
    set(h,'Checked','on');
else
    set(h,'Checked','off');
end

h = findobj(obj,'Label','Slider');
if isempty(H.cdata), set(h,'Enable','off'); else set(h,'Enable','on'); end

if isfield(H,'slider')
    if ishandle(H.slider)
        set(h,'Checked','on');
    else
        H = rmfield(H,'slider');
        set(h,'Checked','off');
    end
else
    set(h,'Checked','off');
end

if numel(findobj('Tag','CATSurfRender','Type','Patch')) > 1
    h = findobj(obj,'Tag','SynchroMenu');
    set(h,'Visible','on');
end

h = findobj(obj,'Label','Colorbar');
d = getappdata(H.patch,'data');
if isempty(d) || ~any(d(:)), set(h,'Enable','off'); else set(h,'Enable','on'); end

if isfield(H,'colourbar')
    if ishandle(H.colourbar)
        set(h,'Checked','on');
    else
        H = rmfield(H,'colourbar');
        set(h,'Checked','off');
    end
else
    set(h,'Checked','off');
end
setappdata(H.axis,'handles',H);

%==========================================================================
function myPostCallback(obj,evt,H)
P = findobj('Tag','CATSurfRender','Type','Patch');
if numel(P) == 1
    %camlight(H.light);
else
    for i=1:numel(P)
        H = getappdata(ancestor(P(i),'axes'),'handles');
        %camlight(H.light);
    end
end

%==========================================================================
function varargout = myCrossBar(varargin)

switch lower(varargin{1})

    case 'create'
    %----------------------------------------------------------------------
    % hMe = myCrossBar('Create',H,xyz)
    H  = varargin{2};
    xyz = varargin{3};
    hold(H.axis,'on');
    hs = plot3(xyz(1),xyz(2),xyz(3),'Marker','+','MarkerSize',60,...
        'parent',H.axis,'Color',[1 1 1],'Tag','CrossBar','ButtonDownFcn',{});
    varargout = {hs};
    
    case 'setcoords'
    %----------------------------------------------------------------------
    % [xyz,d] = myCrossBar('SetCoords',xyz,hMe)
    hMe  = varargin{3};
    xyz  = varargin{2};
    set(hMe,'XData',xyz(1));
    set(hMe,'YData',xyz(2));
    set(hMe,'ZData',xyz(3));
    varargout = {xyz,[]};
    
    otherwise
    %----------------------------------------------------------------------
    error('Unknown action string')

end

%==========================================================================
function myInflate(obj,evt,H)
spm_mesh_inflate(H.patch,Inf,1);
axis(H.axis,'image');

%==========================================================================
function myCCLabel(obj,evt,H)
C   = getappdata(H.patch,'cclabel');
F   = get(H.patch,'Faces');
ind = sscanf(get(obj,'Label'),'Component %d');
V   = get(H.patch,'FaceVertexAlphaData');
Fa  = get(H.patch,'FaceAlpha');
if ~isnumeric(Fa)
    if ~isempty(V), Fa = max(V); else Fa = 1; end
    if Fa == 0, Fa = 1; end
end
if isempty(V) || numel(V) == 1
    Ve = get(H.patch,'Vertices');
    if isempty(V) || V == 1
        V = Fa * ones(size(Ve,1),1);
    else
        V = zeros(size(Ve,1),1);
    end
end
if strcmpi(get(obj,'Checked'),'on')
    V(reshape(F(C==ind,:),[],1)) = 0;
    set(obj,'Checked','off');
else
    V(reshape(F(C==ind,:),[],1)) = Fa;
    set(obj,'Checked','on');
end
set(H.patch, 'FaceVertexAlphaData', V);
if all(V)
    set(H.patch, 'FaceAlpha', Fa);
else
    set(H.patch, 'FaceAlpha', 'interp');
end

%==========================================================================
function myTransparency(obj,evt,H)
t = 1 - sscanf(get(obj,'Label'),'%d%%') / 100;
set(H.patch,'FaceAlpha',t);
set(get(get(obj,'parent'),'children'),'Checked','off');
set(obj,'Checked','on');

%==========================================================================
function mySwitchRotate(obj,evt,H)
if strcmpi(get(H.rotate3d,'enable'),'on')
    set(H.rotate3d,'enable','off');
    set(obj,'Checked','off');
else
    set(H.rotate3d,'enable','on');
    set(obj,'Checked','on');
end

%==========================================================================
function myView(obj,evt,H,varargin)
view(H.axis,varargin{1});
axis(H.axis,'image');
%camlight(H.light);

%==========================================================================
function myColourbar(obj,evt,H)
y = {'on','off'}; toggle = @(x) y{1+strcmpi(x,'on')};
cat_surf_render('Colourbar',H,toggle(get(obj,'Checked')));

%==========================================================================
function myColourmap(obj,evt,H)
cat_surf_render('Colourmap',H,feval(get(obj,'Label'),256));

%==========================================================================
function myAddslider(obj,evt,H)
y = {'on','off'}; toggle = @(x) y{1+strcmpi(x,'on')};
cat_surf_render('Slider',H,toggle(get(obj,'Checked')));

%==========================================================================
function mySynchroniseViews(obj,evt,H)
P = findobj('Tag','CATSurfRender','Type','Patch');
v = get(H.axis,'cameraposition');
for i=1:numel(P)
    H = getappdata(ancestor(P(i),'axes'),'handles');
    set(H.axis,'cameraposition',v);
    axis(H.axis,'image');
    %camlight(H.light);
end

%==========================================================================
function myDataCursor(obj,evt,H)
dcm_obj = datacursormode(H.figure);
set(dcm_obj, 'Enable','on', 'SnapToDataVertex','on', ...
    'DisplayStyle','Window', 'Updatefcn',{@myDataCursorUpdate, H});

%==========================================================================
function txt = myDataCursorUpdate(obj,evt,H)
pos = get(evt,'Position');
txt = {['X: ',num2str(pos(1))],...
       ['Y: ',num2str(pos(2))],...
       ['Z: ',num2str(pos(3))]};
i = ismember(get(H.patch,'vertices'),pos,'rows');
txt = {['Node: ' num2str(find(i))] txt{:}};
d = getappdata(H.patch,'data');
if ~isempty(d) && any(d(:))
    if any(i), txt = {txt{:} ['T: ',num2str(d(i))]}; end
end
hMe = findobj(H.axis,'Tag','CrossBar');
if ~isempty(hMe)
    ws = warning('off');
    spm_XYZreg('SetCoords',pos,get(hMe,'UserData'));
    warning(ws);
end

%==========================================================================
function myBackgroundColor(obj,evt,H,varargin)
if isempty(varargin{1})
    c = uisetcolor(H.figure, ...
        'Pick a background color...');
    if numel(c) == 1, return; end
else
    c = varargin{1};
end
h = findobj(H.figure,'Tag','SPMMeshRenderBackground');
if isempty(h)
    set(H.figure,'Color',c);
else
    set(h,'Color',c);
end

%==========================================================================
function mySavePNG(obj,evt,H,filename)
[pth,nam,ext] = fileparts(filename);
filename = fullfile(pth,[filename '.png']);
u  = get(H.axis,'units');
set(H.axis,'units','pixels');
p  = get(H.axis,'Position');
r  = get(H.figure,'Renderer');
hc = findobj(H.figure,'Tag','SPMMeshRenderBackground');
if isempty(hc)
    c = get(H.figure,'Color');
else
    c = get(hc,'Color');
end
h = figure('Position',p+[0 0 10 10], ...
                'InvertHardcopy','off', ...
                'Color',c, ...
                'Renderer',r);
copyobj(H.axis,h);
set(H.axis,'units',u);
set(get(h,'children'),'visible','off');
%a = get(h,'children');
%set(a,'Position',get(a,'Position').*[0 0 1 1]+[10 10 0 0]);       
if isdeployed
    deployprint(h, '-dpng', '-opengl', fullfile(pth, filename));
else
    print(h, '-dpng', '-opengl', fullfile(pth, filename));
end
close(h);
set(getappdata(obj,'fig'),'renderer',r);

%==========================================================================
function mySave(obj,evt,H)
[filename, pathname, filterindex] = uiputfile({...
    '*.png' 'PNG files (*.png)';...
    '*.gii' 'GIfTI files (*.gii)'; ...
    '*.dae' 'Collada files (*.dae)';...
    '*.idtf' 'IDTF files (*.idtf)'}, 'Save as');
if ~isequal(filename,0) && ~isequal(pathname,0)
    [pth,nam,ext] = fileparts(filename);
    switch ext
        case '.gii'
            filterindex = 1;
        case '.png'
            filterindex = 2;
        case '.dae'
            filterindex = 3;
        case '.idtf'
            filterindex = 4;
        otherwise
            switch filterindex
                case 1
                    filename = [filename '.gii'];
                case 2
                    filename = [filename '.png'];
                case 3
                    filename = [filename '.dae'];
            end
    end
    switch filterindex
        case 1
            G = gifti(H.patch);
            [p,n,e] = fileparts(filename);
            [p,n,e] = fileparts(n);
            switch lower(e)
                case '.func'
                    save(gifti(getappdata(H.patch,'data')),...
                        fullfile(pathname, filename));
                case '.surf'
                    save(gifti(struct('vertices',G.vertices,'faces',G.faces)),...
                        fullfile(pathname, filename));
                case '.rgba'
                    save(gifti(G.cdata),fullfile(pathname, filename));
                otherwise
                    save(G,fullfile(pathname, filename));
            end
        case 2
            u  = get(H.axis,'units');
            set(H.axis,'units','pixels');
            p  = get(H.axis,'Position');
            r  = get(H.figure,'Renderer');
            hc = findobj(H.figure,'Tag','SPMMeshRenderBackground');
            if isempty(hc)
                c = get(H.figure,'Color');
            else
                c = get(hc,'Color');
            end
            h = figure('Position',p+[0 0 10 10], ...
                'InvertHardcopy','off', ...
                'Color',c, ...
                'Renderer',r);
            copyobj(H.axis,h);
            set(H.axis,'units',u);
            set(get(h,'children'),'visible','off');
            %a = get(h,'children');
            %set(a,'Position',get(a,'Position').*[0 0 1 1]+[10 10 0 0]);       
            if isdeployed
                deployprint(h, '-dpng', '-opengl', fullfile(pathname, filename));
            else
                print(h, '-dpng', '-opengl', fullfile(pathname, filename));
            end
            close(h);
            set(getappdata(obj,'fig'),'renderer',r);
        case 3
            save(gifti(H.patch),fullfile(pathname, filename),'collada');
        case 4
            save(gifti(H.patch),fullfile(pathname, filename),'idtf');
    end
end

%==========================================================================
function myDeleteFcn(obj,evt,renderer)
try rotate3d(get(obj,'parent'),'off'); end
set(ancestor(obj,'figure'),'Renderer',renderer);

%==========================================================================
function myOverlay(obj,evt,H)
[P, sts] = spm_select(1,'any','Select file to overlay');
if ~sts, return; end
cat_surf_render('Overlay',H,P);

%==========================================================================
function myImageSections(obj,evt,H)
[P, sts] = spm_select(1,'image','Select image to render');
if ~sts, return; end
renderSlices(H,P);

%==========================================================================
function myChangeGeometry(obj,evt,H)
[P, sts] = spm_select(1,'mesh','Select new geometry mesh');
if ~sts, return; end
G = gifti(P);
if size(H.patch.Vertices,1) ~= size(G.vertices,1)
    error('Number of vertices must match.');
end
H.patch.Vertices = G.vertices;
H.patch.Faces = G.faces;

%==========================================================================
function renderSlices(H,P,pls)
if nargin <3
    pls = 0.05:0.2:0.9;
end
N   = nifti(P);
d   = size(N.dat);
pls = round(pls.*d(3));
hold(H.axis,'on');
for i=1:numel(pls)
    [x,y,z] = ndgrid(1:d(1),1:d(2),pls(i));
    f  = N.dat(:,:,pls(i));
    x1 = N.mat(1,1)*x + N.mat(1,2)*y + N.mat(1,3)*z + N.mat(1,4);
    y1 = N.mat(2,1)*x + N.mat(2,2)*y + N.mat(2,3)*z + N.mat(2,4);
    z1 = N.mat(3,1)*x + N.mat(3,2)*y + N.mat(3,3)*z + N.mat(3,4);
    surf(x1,y1,z1, repmat(f,[1 1 3]), 'EdgeColor','none', ...
        'Clipping','off', 'Parent',H.axis);
end
hold(H.axis,'off');
axis(H.axis,'image');

%==========================================================================
function C = updateTexture(H,v,col)%$,FaceColor)

%-Get colourmap
%--------------------------------------------------------------------------
if ~exist('col','var'), col = getappdata(H.patch,'colourmap'); end
if isempty(col), col = hot(256); end
if ~exist('FaceColor','var') || isempty(FaceColor), FaceColor = 'interp'; end
setappdata(H.patch,'colourmap',col);

%-Get curvature
%--------------------------------------------------------------------------
curv = getappdata(H.patch,'curvature');

if size(curv,2) == 1
    th = 0.15;
    curv((curv<-th)) = -th;
    curv((curv>th))  =  th;
    curv = 0.5*(curv + th)/(2*th);
    curv = 0.5 + repmat(curv,1,3);
end
 
%-Project data onto surface mesh
%--------------------------------------------------------------------------
if nargin < 2, v = []; end
if ischar(v)
    [p,n,e] = fileparts(v);
    if ~strcmp(e,'.mat') & ~strcmp(e,'.nii') & ~strcmp(e,'.gii') & ~strcmp(e,'.img') % freesurfer format
      v = cat_io_FreeSurfer('read_surf_data',v);
    else
      if strcmp([n e],'SPM.mat')
        swd = pwd;
        spm_figure('GetWin','Interactive');
        [SPM,v] = spm_getSPM(struct('swd',p));
        cd(swd);
      else
        try spm_vol(v); catch, v = gifti(v); end;
      end
    end
end
if isa(v,'gifti'), v = v.cdata; end
if isa(v,'file_array'), v = v(); end
if isempty(v)
    v = zeros(size(curv))';
elseif ischar(v) || iscellstr(v) || isstruct(v)
    v = spm_mesh_project(H.patch,v);
elseif isnumeric(v) || islogical(v)
    if size(v,2) == 1
        v = v';
    end
else
    error('Unknown data type.');
end
v(isinf(v)) = NaN;

setappdata(H.patch,'data',v);

%-Create RGB representation of data according to colourmap
%--------------------------------------------------------------------------
C = zeros(size(v,2),3);
clim = getappdata(H.patch, 'clim');
if isempty(clim), clim = [false NaN NaN]; end
mi = clim(2); ma = clim(3);
if any(v(:))
    if size(col,1)>3 && size(col,1) ~= size(v,1)
        if size(v,1) == 1
            if ~clim(1), mi = min(v(:)); ma = max(v(:)); end
            C = squeeze(ind2rgb(floor(((v(:)-mi)/(ma-mi))*size(col,1)),col));
        elseif isequal(size(v),[size(curv,1) 3])
            C = v; v = v';
        else
            if ~clim(1), mi = min(v(:)); ma = max(v(:)); end
            for i=1:size(v,1)
                C = C + squeeze(ind2rgb(floor(((v(i,:)-mi)/(ma-mi))*size(col,1)),col));
            end
        end
    else
        if ~clim(1), ma = max(v(:)); end
        for i=1:size(v,1)
            C = C + v(i,:)'/ma * col(i,:);
        end
    end
end

clip = getappdata(H.patch, 'clip');
if ~isempty(clip)
    v(v>clip(2) & v<clip(3)) = NaN;
    setappdata(H.patch, 'clip', [true clip(2) clip(3)]);
end

setappdata(H.patch, 'clim', [false mi ma]);

%-Build texture by merging curvature and data
%--------------------------------------------------------------------------
C = repmat(~any(v,1),3,1)' .* curv + repmat(any(v,1),3,1)' .* C;

set(H.patch, 'FaceVertexCData',C, 'FaceColor',FaceColor);

%-Update the colourbar
%--------------------------------------------------------------------------
if isfield(H,'colourbar')
    cat_surf_render('Colourbar',H);
end

%==========================================================================
function slider_clim_min(hObject, evt)

val = get(hObject, 'Value');
H = getHandles(gcf);
c = getappdata(H.patch,'clim');
setappdata(H.patch,'clim',[true val c(3)]);
d = getappdata(H.patch,'data');
updateTexture(H,d);
H2 = getHandles(gca);
if isfield(H2,'colourbar') && ishandle(H2.colourbar)
  cat_surf_render('ColourBar',gca, 'on');
end

%==========================================================================
function slider_clim_max(hObject, evt)

val = get(hObject, 'Value');
H = getHandles(gcf);
c = getappdata(H.patch,'clim');
setappdata(H.patch,'clim',[true c(2) val]);
d = getappdata(H.patch,'data');
updateTexture(H,d);
H2 = getHandles(gca);
if isfield(H2,'colourbar') && ishandle(H2.colourbar)
  cat_surf_render('ColourBar',gca, 'on');
end

%==========================================================================
function slider_clip_min(hObject, evt)

val = get(hObject, 'Value');
H = getHandles(gcf);
c = getappdata(H.patch,'clip');
setappdata(H.patch,'clip',[true val c(3)]);
c = getappdata(H.patch,'clim');
setappdata(H.patch,'clim',[true c(2) c(3)]);
d = getappdata(H.patch,'data');
updateTexture(H,d);
H2 = getHandles(gca);
if isfield(H2,'colourbar') && ishandle(H2.colourbar)
  cat_surf_render('ColourBar',gca, 'on');
end


%==========================================================================
function slider_clip_max(hObject, evt)

val = get(hObject, 'Value');
H = getHandles(gcf);
c = getappdata(H.patch,'clip');
setappdata(H.patch,'clip',[true c(2) val]);
c = getappdata(H.patch,'clim');
setappdata(H.patch,'clim',[true c(2) c(3)]);
d = getappdata(H.patch,'data');
updateTexture(H,d);
H2 = getHandles(gca);
if isfield(H2,'colourbar') && ishandle(H2.colourbar)
  cat_surf_render('ColourBar',gca, 'on');
end