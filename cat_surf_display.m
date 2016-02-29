function varargout = cat_surf_display(varargin)
% ______________________________________________________________________
% Function to display surfaces. Wrapper to cat_surf_render.
%
% [Psdata] = cat_surf_display(job)
% 
% job.data      .. [rl]h.* surfaces 
% job.colormap  .. colormap
% job.caxis     .. range of the colormap
% job.multisurf .. load both sides, if possible  
% job.usefsaverage .. use average surface (for resampled data only)
%                  (default = 0)
% job.view      .. view 
%                   l=left, r=right
%                   a=anterior, p=posterior
%                   s=superior, i=inferior
% job.verb      .. SPM command window report (default = 1)
% job.readsurf  .. get full surface informtion by loading the image
%                  (default = 1; see cat_surf_info)
%
% job.imgprint.do   .. print image (default = 0)
% job.imgprint.type .. render image type (default = png)
% job.dpi           .. print resolution of the image (default = 600 dpi)
%
% Examples: 
%  - Open both hemispheres of one subject S01:
%   cat_surf_display(struct('data','lh.thickness.S01.gii','multisurf',1))
%  - Use another scaling of the intensities
%   cat_surf_display(struct('caxis',[0 10]))
% ______________________________________________________________________
% Robert Dahnke
% $Id$

  SVNid = '$Rev$';
  if nargout>0, varargout{1}{1} = []; end   

  if nargin>0
    if isstruct(varargin{1})
      job = varargin{1};
      if ~isfield(job,'data')
        job.data = spm_select([1 24],'any','Select surface','','','[lr]h.*');
        job.imgprint.do    = 0;
        job.imgprint.close = 0;  
      end
    else
      job.data = varargin{1};
    end
  else
    job.data = spm_select([1 24],'any','Select surface','','','[lr]h.*');
    job.imgprint.do    = 0;
    job.imgprint.close = 0;  
  end
  if isempty(job.data), return; end
  job.data = cellstr(job.data);
  
  % scaling options for textures
  def.colormap = '';
  def.fsaverage    = {
    fullfile(spm('dir'),'toolbox','cat12','templates_surfaces','lh.central.freesurfer.gii');  
    fullfile(spm('dir'),'toolbox','cat12','templates_surfaces','lh.inflated.freesurfer.gii');  
    fullfile(spm('dir'),'toolbox','cat12','templates_surfaces','lh.central.Template_T1_IXI555_MNI152.gii');  
    };
  def.usefsaverage = 0; 
  def.caxis    = []; % default/auto, range
  
  % print options ... just a quick output > cat_surf_print as final function 
  def.imgprint.type  = 'png';
  def.imgprint.dpi   = 600;
  def.imgprint.fdpi  = @(x) ['-r' num2str(x)];
  def.imgprint.ftype = @(x) ['-d' num2str(x)];
  def.imgprint.do    = 0;
  def.imgprint.close = 0;
  def.imgprint.dir   = '';
  
  % multi-surface output for one subject 
  def.multisurf = 0; % 0 - no; 1 - both hemispheres;
  def.verb      = 1;
  def.readsurf  = 1;  % readsurf=1 for individual average surface (e.g. appes); readsurf=0 for group average surface 
  
  job = cat_io_checkinopt(job,def);
  
  %% ... need futher development 
  sinfo = cat_surf_info(job.data,job.readsurf);  
  if job.verb
    spm('FnBanner',mfilename,SVNid); 
  end
  for i=1:numel(job.data)
    if job.usefsaverage
      sinfo(i).Pmesh = cat_surf_rename(job.fsaverage{job.usefsaverage},'side',sinfo(i).side); 
    end
    
    % load multiple surfaces
    if job.multisurf
      if strcmp(sinfo(i).side,'rh'), oside = 'lh'; else oside = 'rh'; end
      Pmesh = [sinfo(i).Pmesh cat_surf_rename(sinfo(i).Pmesh,'side',oside)];
      Pdata = [sinfo(i).Pdata cat_surf_rename(sinfo(i).Pdata,'side',oside)]; 
      for im=numel(Pmesh):-1:1
        if ~exist(Pmesh{im},'file'), Pmesh(im) = []; end
        if ~exist(Pdata{im},'file'), Pdata(im) = []; end
      end
      if numel(Pmesh)==1; Pmesh=char(Pmesh); end
      if numel(Pdata)==1; Pdata=char(Pdata); end
    else
      Pmesh = sinfo(i).Pmesh;
      Pdata = sinfo(i).Pdata; 
    end
    
    try
      if job.verb
        fprintf('Display %s\n',spm_file(job.data{i},'link','cat_surf_display(''%s'')'));
      end
      
      if ~all(strcmp(Pmesh,Pdata)) && ~isempty(Pdata) 
        % only gifti surface without texture
        if isfield(job,'parent')
          h = cat_surf_render('disp',Pmesh,'Pcdata',Pdata,'parent',job.parent);
        else
          h = cat_surf_render('disp',Pmesh,'Pcdata',Pdata);
        end  
      else
        % only gifti surface without texture
        if isfield(job,'ah')
          h = cat_surf_render(Pmesh,'parent',job.parent);
        else
          h = cat_surf_render(Pmesh);
        end
      end
      if sinfo(i).label, continue; end
      
      %% textur handling
      set(h.figure,'MenuBar','none','Toolbar','none','Name',spm_file(job.data{i},'short60'),'NumberTitle','off');
      cat_surf_render('ColourBar',h.axis,'on');
      if ~job.multisurf && strcmp(sinfo(i).side,'rh'), view(h.axis,[90 0]); end
      
      
      % temporary colormap
      if any(strcmpi({'neuromorphometrics','lpba40','ibsr','hammers','mori','aal'},sinfo(i).dataname))
        %%
        switch lower(sinfo(i).dataname)
          case 'neuromorphometrics', rngid=3; 
          case 'lpba40',             rngid=12; 
          case 'ibsr',               rngid=1; 
          case 'hammers',            rngid=5;  
          case 'mori',               rngid=3; 
          case 'aal',                rngid=11; 
          otherwise,                 rngid=1; 
        end
        
        sideids = ceil(max(h.cdata(:))/2)*2;  
        rng('default'); rng(rngid);  
        cmap = colorcube(ceil((sideids/2) * 8/7)); % greater to avoid grays
        cmap(ceil(sideids/2):end,:)=[]; % remove grays
        cmap(sum(cmap,2)<0.3,:) = min(1,max(0.1,cmap(sum(cmap,2)<0.3,:)+0.2)); % not to dark
        cmap = cmap(randperm(size(cmap,1)),:); % random 
        cmap = reshape(repmat(cmap',2,1),3,size(cmap,1)*2)'; 
       
        cat_surf_render('ColourMap',h.axis,cmap);
        
        %%
        continue
      else
        if isempty(job.colormap)
          cat_surf_render('ColourMap',h.axis,jet(256)); 
        else
          cat_surf_render('ColourMap',h.axis,eval(job.colormap));
        end
      end
      
      % scaling
      if isempty(job.caxis)
        switch sinfo(i).texture
          case {'defects','sphere'}
            % no texture
          case {'central'}
            % default curvature
            set(h.patch,'AmbientStrength',0.2,'DiffuseStrength',0.8,'SpecularStrength',0.1)
          case ''
            % no texture name
            if ~isempty(h.cdata)
              clim = iscaling(h.cdata);
              if clim(1)<0
                clim = [-max(abs(clim)) max(abs(clim))];
                cat_surf_render('ColourMap',h.axis,cat_io_colormaps('BWR',128)); 
              else
                cat_surf_render('ColourMap',h.axis,cat_io_colormaps('hotinv',128)); 
              end
              cat_surf_render('clim',h.axis,clim);
            end
          otherwise
            %%
            ranges = {
              ... name single group
              'thickness'         [0.5  5.0]  [0.5  5.0]
              'gyruswidthWM'      [0.5  8.0]  [1.0  7.0]
              'gyruswidth'        [1.0 12.0]  [1.5 11.0]
              'fractaldimension'  [0.0  4.0]  [1.0  4.0]
              'sulcuswidth'       [0.0  3.0]  [0.0  3.0]
              'gyrification'      [ 15   35]  [ 15   35]
              'sqrtsulc'          [0.0  1.5]  [0.0  1.5]
              'WMdepth'           [1.0  6.0]  [1.0  5.0]
              'GWMdepth'          [1.5 10.0]  [1.5  9.0]
              'CSFdepth'          [0.5  2.0]  [0.5  2.0]
              'depthWM'           [0.0  4.0]  [0.0  3.0]
              'depthWMg'          [0.0  1.0]  [0.0  0.5]
              'depthGWM'          [0.5  5.0]  [2.5  6.0]
              'depthCSF'          [0.5  2.0]  [0.5  2.0]  
            };

            texturei = find(cellfun('isempty',strfind(ranges(:,1),sinfo(i).texture))==0,1,'first');

            if ~isempty(texturei)
              cat_surf_render('clim',h.axis,ranges{texturei,3});
            else
              clim = iscaling(h.cdata);  
              cat_surf_render('clim',h.axis,round(clim));
            end
        end     
      else
        cat_surf_render('clim',h.axis,job.caxis);
      end
    catch %#ok<CTCH>
      if ~exist('h','var')
        try
          cat_io_cprintf('err',sprintf('Texture error. Display surface only.'));
          h = cat_surf_render(job.data{i});
        catch %#ok<CTCH>
          cat_io_cprintf('err',sprintf('ERROR: Can''t display surface %s\n',job.data{i})); 
        end
      end
      continue
    end
    
    
    
    
    %% view
    viewname = '';
    if isfield(job,'view')
      switch lower(job.view)
        case {'r','right'},                 view([  90   0]); viewname = '.r';
        case {'l','left'},                  view([ -90   0]); viewname = '.l';
        case {'t','s','top','superior'},    view([   0  90]); viewname = '.s';
        case {'b','i','bottom','inferior'}, view([-180 -90]); viewname = '.i'; 
        case {'f','a','front','anterior'},  view([-180   0]); viewname = '.a';
        case {'p','back','posterior'},      view([   0   0]); viewname = '.p';
        otherwise
          if isnumeric(job.view) && size(job.view)==2
            view(job.view); viewname = sprintf('.%04dx%04d',mod(job.view,360));
          else
            error('Unknown view.\n')
          end
      end
    end    
    
    
    
    
    %% print
    if job.imgprint.do 
      %%
      if isempty(job.imgprint.dir), ppp = sinfo(i).pp; else  ppp=job.imgprint.dir;  end
      if ~exist(ppp,'dir'), mkdir(ppp); end
      pfname = fullfile(ppp,sprintf('%s%s.%s',sinfo(i).ff,viewname,job.imgprint.type));
      print(h.figure , def.imgprint.ftype(job.imgprint.type) , job.imgprint.fdpi(job.imgprint.dpi) , pfname ); 
      
      if job.imgprint.close
        close(h.figure);
      end
    end
    
    if nargout>0
      varargout{1}{i} = h;
    end   
  end
end
function clim = iscaling(cdata,plim)
%%
  ASD = min(0.02,max(eps,0.05*std(cdata))/max(abs(cdata))); 
  if ~exist('plim','var'), plim = [ASD 1-ASD]; end 

  bcdata  = [min(cdata) max(cdata)]; 
  range   = bcdata(1):diff(bcdata)/1000:bcdata(2);
  hst     = hist(cdata,range);
  clim(1) = range(max(1,find(cumsum(hst)/sum(hst)>plim(1),1,'first')));
  clim(2) = range(min([numel(range),find(cumsum(hst)/sum(hst)>plim(2),1,'first')]));
end


