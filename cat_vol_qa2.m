function varargout = cat_vol_qa2(action,varargin)
% CAT Preprocessing T1 Quality Control
% ______________________________________________________________________
% 
% Estimation of image quality measures like noise, inhomogeneity,
% contrast, resolution, etc. and scaling for school marks. 
%
% [QAS,QAM] = cat_vol_qa2(action,varargin)
% 
%
% 1) Use GUI interface to choose segmentation and automatic setting of 
%    original and modified image (if available)
%     [QAS,QAM] = cat_vol_qa2()                = cat_vol_qa2('p0')
%
%     [QAS,QAM] = cat_vol_qa2('p0'[,opt])      - p0 class image
%     [QAS,QAM] = cat_vol_qa2('p#'[,opt])      - p1,p2,p3 class images
%     [QAS,QAM] = cat_vol_qa2('c#'[,opt])      - c1,c2,c3 class images
%     [QAS,QAM] = cat_vol_qa2('*#'[,opt])      - csf,gm,wm class images
%     [QAS,QAM] = cat_vol_qa2('p0',Pp0[,opt])           - no GUI call
%     [QAS,QAM] = cat_vol_qa2('p#',Pp1,Pp2,Pp3,[,opt])  - no GUI call
%     [QAS,QAM] = cat_vol_qa2('c#',Pc1,Pc2,Pc3,[,opt])  - no GUI call
%     [QAS,QAM] = cat_vol_qa2('c#',Pcsf,Pgm,Pwm,[,opt]) - no GUI call
%
%
% 2) Use GUI interface to choose all images like for other segmentations
%    and modalities with a similar focus of CSF, GM, and WM tissue 
%    contrast such as PD, T2, or FLASH. 
%     [QAS,QAM] = cat_vol_qa2('p0+'[,opt])     - p0 class image  
%     [QAS,QAM] = cat_vol_qa2('p#+'[,opt])     - p1,p2,p3 class images  
%     [QAS,QAM] = cat_vol_qa2('c#+'[,opt])     - c1,c2,c3 class images 
%     [QAS,QAM] = cat_vol_qa2('*#+'[,opt])     - csf,gm,wm class images
%     [QAS,QAM] = cat_vol_qa2('p0+',Pp0,Po[,Pm,opt])         - no GUI call
%     [QAS,QAM] = cat_vol_qa2('p#+',Pp1,Pp2,Pp3,Po[,Pm,opt]) - no GUI call
%     [QAS,QAM] = cat_vol_qa2('c#+',Pc1,Pc2,Pc3,Po[,Pm,opt]) - no GUI call
%
% 
% 3) Use GUI interface to choose all images. I.e. for other segmentations
%    and modalities without focus of GM-WM contrast such as DTI MTI. 
%     [ not implemented yet ]
%
%
% 4) CAT12 internal preprocessing interface 
%    (this is the processing case that is also called in all other cases)
%    [QAS,QAM] = cat_vol_qa2('cat12',Yp0,Po,Ym,res[,opt])
%
%
%   Pp0 - segmentation files (p0*.nii)
%   Po  - original files (*.nii)
%   Pm  - modified files (m*.nii)
%   Yp0 - segmentation image matrix
%   Ym  - modified image matrix
%
%   opt            = parameter structure
%   opt.verb       = verbose level  [ 0=nothing | 1=points | 2*=times ]
%   opt.redres     = resolution in mm for intensity scaling [ 4* ];
%   opt.write_csv  = final cms-file
%   opt.write_xml  = images base xml-file
%   opt.sortQATm   = sort QATm output
%     opt.orgval     = original QAM results (no marks)
%     opt.recalc     =
%     opt.avgfactor  = 
%   opt.prefix     = prefix of xml output file (default cat_*.xml) 
%
% ______________________________________________________________________
%
% Christian Gaser, Robert Dahnke
% Structural Brain Mapping Group (https://neuro-jena.github.io)
% Departments of Neurology and Psychiatry
% Jena University Hospital
% ______________________________________________________________________
%
% $Id$
% ______________________________________________________________________

%#ok<*ASGLU>

  % get current release number and version
  [ver_cat, rev_cat] = cat_version;
  ver_cat = ver_cat(4:end); % remove leading CAT

  % init output
  QAS = struct(); 
  QAR = struct(); 
  %if nargout>0, varargout = cell(1,nargout); end
  
  try
    if strcmp(action,'cat12err')
      [mrifolder, reportfolder] = cat_io_subfolders(varargin{1}.job.data,varargin{1}.job);
    elseif strcmp(action,'cat12')
      [mrifolder, reportfolder] = cat_io_subfolders(varargin{2},varargin{6}.job);
    else
      [mrifolder, reportfolder] = cat_io_subfolders(varargin{4}.catlog,varargin{6}.job);
    end
  catch
    mrifolder    = 'mri'; 
    reportfolder = 'report'; 
  end
  
  % no input and setting of default options
  action2 = action; 
  if nargin==0, action='p0'; end 
  if isstruct(action)
    if isfield(action,'model')
      if isfield(action.model,'catp0')
        Po  = action.images;
        Pp0 = action.model.catp0; 
        if numel(Po)~=numel(Pp0) && numel(Pp0)==1
          Pp0 = repmat(Pp0,numel(Po),1);
        end
        Pm  = action.images;
        action.data = Pp0;
      elseif isfield(action.model,'seg')
        %% error('no implemented yet')
        fprintf('Prepare CGW-label maps')
        mjob.images{1,1} = action.images; 
        mjob.images{2,1} = action.model.seg.cm;
        mjob.images{3,1} = action.model.seg.gm;
        mjob.images{4,1} = action.model.seg.wm;
        mjob.expression  = 'i1*0 + i2*1 + i3*2 + i4*3';  % the first one is just for the name
        mjob.prefix      = 'p0'; %
        mjob.verb        = 0; 
        cat_vol_mimcalc(mjob);

        action2 = rmfield(action,'model'); 
        action2.model.catp0 = spm_file(action.images,'prefix','p0');  
        varargout = cat_vol_qa2(action2,varargin); 
        return 

      end
    end
    if isfield(action,'data')
      Pp0 = action.data;
    end
    action = 'p0';
  end
  if nargin>1 && isstruct(varargin{end}) && isstruct(varargin{end})
    opt  = cat_check('checkinopt',varargin{end},defaults);
    nopt = 1; 
  else
    if isstruct(action2)
      opt = cat_check('checkinopt',action2.opts,defaults);
    else
      opt = defaults;
    end
    nopt = 0;
    if isfield(opt,'recalc') && opt.recalc, opt.rerun = opt.recalc; end
  end
  if contains(opt.prefix,'VERSION')
    opt.prefix = strrep( opt.prefix , 'VERSION', strrep( opt.version ,'_','')); 
  end

  % check input by action
  switch action
    case {'p0','p0+'}
    % segment image cases
      if nargin<=3 && ( ~exist('Pp0','var') || isempty(Pp0) )
        if (nargin-nopt)<2  
          Pp0 = cellstr(spm_select(inf,'image',...
            'select p0-segment image',{},pwd,'^p0.*')); 
          if isempty(Pp0{1}), return; end
        else
          Pp0 = varargin{1};
        end
        if numel(action)==2
          Po = Pp0; Pm = Pp0;
          for fi=1:numel(Pp0)
            [pp,ff,ee] = spm_fileparts(Pp0{fi});
            [ppa,ppb] = spm_fileparts(pp); 
            if strcmp(ppb,'mri'), ppo = ppa; else, ppo = pp; end 

            deri = strfind(ppo,[filesep 'derivatives' filesep 'CAT']); 
            if isempty( deri )
              Po{fi} = fullfile(ppo,[ff(3:end) ee]); 
            else
              BIDShome = fileparts(ppo(1:deri(1)));
              fsep     = strfind( ppo(deri(1) + 16:end) , filesep ) + deri(1) + 16;
              
              Po{fi} = fullfile( BIDShome, ppo(fsep(1):end) , [ff(3:end) ee] );


            end
            Pm{fi} = fullfile(pp,[opt.mprefix  ff(3:end) ee]);

            if ~exist(Pm{fi},'file'), Pm{fi}=''; end
          end
        else
          Po = cellstr(spm_select(repmat(numel(Pp0),1,2),...
            'image','select original image(s)',{},pwd,'.*')); 
          Pm = cellstr(spm_select(repmat(numel(Pp0),1,2),...
            'image','select modified image(s)',{},pwd,'.*')); 
        end

      elseif nargin<=5 && ( ~exist('Pp0','var') || isempty(Pp0) )
        Pp0 = varargin{1};
        Po  = varargin{2};
        Pm  = varargin{3};

      elseif ( ~exist('Pp0','var') || isempty(Pp0) )
        error('MATLAB:cat_vol_qa2:inputerror',...
          'Wrong number/structure of input elements!'); 
      end



    case {'p#','c#','*#','p#+','c#+','*#+'}
    % tissue class image cases with GUI

      if nargin-1<=2 % GUI 
        if (nargin-nopt)<2 
          if action(1)=='p' || action(1)=='c'
            % cat/spm case
            Pcsf = cellstr(spm_select(inf,'image',...
              'select p1-segment image',{},pwd,['^' action(1) '1.*'])); 
            if isempty(Pcsf{1}), return; end
            Pgm=Pcsf; Pwm=Pcsf;
            for fi=1:numel(Pcsf)
              [pp,ff,ee] = spm_fileparts(Pcsf{fi});

              Pgm{fi} = fullfile(pp,[action(1) '2' ff(3:end) ee]); 
              Pwm{fi} = fullfile(pp,[action(1) '3' ff(3:end) ee]); 
            end
          else 
            Pcsf = cellstr(spm_select(inf,'image',...
              'select CSF segment image(s)',{},pwd,'.*')); 
            if isempty(Pcsf{1}), return; end
          end 
          if numel(action)==2
            Pp0=Pcsf; Po=Pcsf; Pm=Pcsf;
            for fi=1:numel(Pcsf)
              [pp,ff,ee] = spm_fileparts(Pcsf{fi});
              Po{fi}  = fullfile(pp,[ff(3:end) ee]);
              Pm{fi}  = fullfile(pp,['m'  ff(3:end) ee]);
              Pp0{fi} = fullfile(pp,['p0' ff(3:end) ee]);
            end 
          else
            Po = cellstr(spm_select(repmat(numel(Pcsf),1,2),...
              'image','select original image(s)',{},pwd,'.*')); 
            Pm = cellstr(spm_select(repmat(numel(Pcsf),1,2),...
              'image','select modified image(s)',{},pwd,'.*')); 
            Pp0=Pcsf;
            for fi=1:numel(Pcsf)
              [pp,ff,ee] = spm_fileparts(Pcsf{fi});
              Pp0{fi} = fullfile(pp,['p0' ff(3:end) ee]);
            end 
          end

          % wie komm ich zum p0???
        else
          Pp0 = varargin{1};
        end

      elseif nargin==5 || nargin==6
        % other allowed cases

      else
        error('MATLAB:cat_vol_qa2:inputerror',...
          'Wrong number/structure of input elements!'); 
      end
    case 'cat12ver'


    otherwise
      error('MATLAB:cat_vol_qa2:inputerror',...
        'Wrong number/structure of input elements!'); 
  end
  if ~exist('species','var'), species='human'; end
    
  
  %
  % --------------------------------------------------------------------
  [QA,QMAfn]  = cat_stat_marks('init'); 
  if any( strcmp(opt.version,opt.versions0) )
    QMAfn( contains(QMAfn,'res_ECR'))   = [];
  end
  if ~any( strcmp(opt.version,opt.versions1) )
    QMAfn( contains(QMAfn,'res_ECRmm')) = []; 
  end
  stime       = clock;
  


  
  % Print options
  % --------------------------------------------------------------------
  %printtable = createPrintTable(QMAfn,opt.snspace)
  Cheader = {'scan'};
  Theader = sprintf(sprintf('%%%ds:',opt.snspace(1)-1),'scan');
  Tline   = sprintf('%%5d) %%%ds:',opt.snspace(1)-8);
  Tline2  = sprintf('%%5d) %%6s%%%ds:',opt.snspace(1)-14); 
  Tavg    = sprintf('%%%ds:',opt.snspace(1)-1);
  TlineE  = sprintf('%%5d) %%%ds: %%s',opt.snspace(1)-7);
  for fi=1:numel(QMAfn)
    Cheader = [Cheader QMAfn{fi}]; %#ok<AGROW>
    QAMfni  = strrep( QMAfn{fi} ,'_','');
    Theader = sprintf(sprintf('%%s%%%ds',opt.snspace(2)),Theader,...
                cat_io_strrep( QAMfni,{'contrastr';'resECRmm';'resECR'},{'CON';'ECRmm';'ECR'}) ); %(1:min(opt.snspace(2)-1,numel(QMAfn{fi}))) 
    Tline   = sprintf('%s%%%d.%df',Tline,opt.snspace(2),opt.snspace(3));
    Tline2  = sprintf('%s%%%d.%df',Tline2,opt.snspace(2),opt.snspace(3));
    Tavg    = sprintf('%s%%%d.%df',Tavg,opt.snspace(2),opt.snspace(3));
  end
  Cheader = [Cheader 'IQR']; 
  Theader = sprintf(sprintf('%%s%%%ds',opt.snspace(2)),Theader,'IQR');
  if ~any( strcmp(opt.version,opt.versions0) ) % ~any( contains(opt.version,opt.versions0) )
    Tline   = sprintf('%s%%%d.%df',Tline,opt.snspace(2),opt.snspace(3));
    Tline2  = sprintf('%s%%%d.%df',Tline2,opt.snspace(2),opt.snspace(3));
    Cheader = [Cheader 'SIQR']; 
    Theader = sprintf(sprintf('%%s%%%ds',opt.snspace(2)),Theader,'SIQR');
    Tavg    = sprintf('%s%%%d.%df',Tavg,opt.snspace(2),opt.snspace(3));
  end
  Tline   = sprintf('%s%%%d.%df%%s\n',Tline,opt.snspace(2),opt.snspace(3));
  Tline2  = sprintf('%s%%%d.%df\n',Tline2,opt.snspace(2),opt.snspace(3));
  Tavg    = sprintf('%s%%%d.%df\n',Tavg,opt.snspace(2),opt.snspace(3));
  
  
  
  
  
  % estimation part    
  switch action
    case 'cat12'
      eval(sprintf('[QAS,QAR] = %s(''cat12'',varargin{:});',opt.version));


    case {'p0','p#','c#','*#','p0+','p#+','c#+','*#+'}    
      

      % return for empty input
      if isempty(Pp0) || (isempty(Pp0{1}) && numel(Pp0)<=1) 
        cat_io_cprintf('com','No images for QA!\n'); 
        return
      end
    
      % print title
      if opt.verb>1
        fprintf('\nCAT Preprocessing T1 Quality Control (');
        cat_io_cprintf('blue',' %s',opt.version );
        cat_io_cprintf('n',' , %s ):\n',sprintf('Rev: %s',rev_cat) );
        fprintf('\n%s\n%s\n',  Theader,repmat('-',size(Theader)));  
      end

      % preare variables
      qamat   = nan(numel(Po),numel(QMAfn));
      qamatm  = nan(numel(Po),numel(QMAfn));
      mqamatm = 10.5*ones(numel(Po),1 + ~any( strcmp(opt.version,opt.versions0) ));
      QAS     = struct(); 
      QAR     = struct(); 
      
      QAR.mark2rps = @(mark) min(100,max(0,105 - mark*10)) + isnan(mark).*mark;



      % loop for multiple files
      % -------------------------------------------------------------------
      for fi = 1:numel(Pp0)
        stime1 = clock; 
        try
        
          [pp,ff,ee] = spm_fileparts( Po{fi} ); 
          sfile  = fullfile(pp,reportfolder,[opt.prefix ff '.xml']); 
          sfilee = exist( sfile ,'file'); 

          if opt.rerun == 2  ||  strcmp(opt.prefix,'tmp') || ... allways reprocess 
            (opt.rerun == 0 && cat_io_rerun(Po{fi}, sfile , 0 )) || ... load if the QC file is available and newer than the input
            (opt.rerun == 1 && ( cat_io_rerun(Po{fi}, sfile , 0 ) || ...  load if the QC file is newer than the input and function
                                 cat_io_rerun(which(opt.version), sfile , 0 ) ) ) 

            
            [Yp0,Ym,Vo] = getImages(Pp0,Po,Pm,fi); 
        
            % general function called from CAT12
            res.image     = spm_vol(Pp0{fi}); 

            [QASfi,QARfi] = cat_vol_qa2('cat12ver',Yp0,Vo,Ym,res,species,opt);
            %cat_io_xml(sfile,struct('QAS',QASfi,'QAR',QARfi));

            if sfilee
              rerun = sprintf(' updated %2.0fs',etime(clock,stime1));
            else
              rerun = sprintf(' %2.0fs',etime(clock,stime1)); % new
            end
            
          else
            try 
              rerun = ' loaded';
            
              QASfi = cat_io_xml(sfile); 
              QARfi = upate_rating(QASfi,opt.version);
    
            catch
              [Yp0,Ym,Vo] = getImages(Pp0,Po,Pm,fi); 
          
              % general function called from CAT12
              res.image     = spm_vol(Pp0{fi}); 
  
              [QASfi,QARfi] = cat_vol_qa2('cat12ver',Yp0,Vo,Ym,res,species,opt);
            
              if sfilee
                rerun = sprintf(' updated %2.0fs',etime(clock,stime1));
              else
                rerun = sprintf(' %2.0fs',etime(clock,stime1)); % new
              end
            end

          end

          try
            [QAS, QAR, qamat, qamatm, mqamatm] = updateQAstructure(QAS, QASfi, QAR, QARfi, qamat, qamatm, mqamatm, QMAfn, fi);
          catch

            [Yp0,Ym,Vo] = getImages(Pp0,Po,Pm,fi); 
        
            % general function called from CAT12
            res.image     = spm_vol(Pp0{fi}); 

            [QASfi,QARfi] = cat_vol_qa2('cat12ver',Yp0,Vo,Ym,res,species,opt);
            %cat_io_xml(sfile,struct('QAS',QASfi,'QAR',QARfi));

            if sfilee
              rerun = sprintf(' updated %2.0fs',etime(clock,stime1));
            else
              rerun = sprintf(' %2.0fs',etime(clock,stime1)); % new
            end

            [QAS, QAR, qamat, qamatm, mqamatm] = updateQAstructure(QAS, QASfi, QAR, QARfi, qamat, qamatm, mqamatm, QMAfn, fi);
          
          end

          % print result
          if opt.verb>1 
            if opt.orgval 
              cat_io_cprintf(opt.MarkColor(max(1,floor( mqamatm(fi,end)/9.5 * ...
                size(opt.MarkColor,1))),:),sprintf(Tline,fi,...
                spm_str_manip(QAS(fi).filedata.fname,['a' num2str(opt.snspace(1) - 14)]),...
                qamat(fi,:), max(1,min(9.5,mqamatm(fi,:))), rerun));
            else
              cat_io_cprintf(opt.MarkColor(max(1,floor( mqamatm(fi,end)/9.5 * ...
                size(opt.MarkColor,1))),:),sprintf(Tline,fi,...
                spm_str_manip(QAS(fi).filedata.fname,['a' num2str(opt.snspace(1) - 14)]),...
                qamatm(fi,:), max(1,min(9.5,mqamatm(fi,:))), rerun));
            end
          end
        catch e %#ok<CTCH> ... normal "catch err" does not work for MATLAB 2007a
          switch e.identifier
            case {'cat_vol_qa2:noYo','cat_vol_qa2:noYm','cat_vol_qa2:badSegmentation'}
              em = e.identifier;
            case 'cat_vol_qa2:missingVersion'
              rethrow(e);
            otherwise
              em = ['ERROR:\n' repmat(' ',1,10) e.message '\n'];
              for ei=1:numel(e.stack)
                em = sprintf('%s%s%5d: %s\n',em,repmat(' ',1,10),...
                  e.stack(ei).line(end),e.stack(ei).name);
              end  
          end

          [pp,ff] = spm_fileparts(Po{fi});
          QAS(fi).filedata.fnames = [spm_str_manip(pp,sprintf('k%d',floor( (opt.snspace(1)-19) /3) - 1)),'/',...
                               spm_str_manip(ff,sprintf('k%d',(opt.snspace(1)-19) - floor((opt.snspace(1)-14)/3)))];
          cat_io_cprintf(opt.MarkColor(end,:),sprintf(TlineE,fi,Pp0{fi},[em '\n']));
        end
      end  

      
      
      % sort by mean mark
      % -------------------------------------------------------------------
      if opt.sortQATm && numel(Po)>1
        % sort matrix
        [smqamatm,smqamatmi] = sort(mqamatm(:,end),'ascend');
        sqamatm  = qamatm(smqamatmi,:);
        sqamat   = qamat(smqamatmi,:); 

        % print matrix
        if opt.verb>0
          fprintf('%s\n',repmat('-',size(Theader))); 
          for fi = 1:numel(QAS)
            if isfield( QAS(smqamatmi(fi)), 'filedata') && isfield( QAS(smqamatmi(fi)).filedata, 'fname')
              fname = spm_str_manip( QAS(smqamatmi(fi)).filedata.fname , ['a' num2str(opt.snspace(1) - opt.snspace(2) - 14)] );
            else
              fname = 'FILENAME ERROR';
            end
            if opt.orgval 
              cat_io_cprintf(opt.MarkColor(max(1,min(size(opt.MarkColor,1),...
                round( mqamatm(smqamatmi(fi),end)/9.5 * ...
                size(opt.MarkColor,1)))),:),sprintf(...
                Tline2,fi,sprintf('(%d)',smqamatmi(fi)),...
                fname, sqamat(fi,:),max(1,min(10.5,mqamatm(smqamatmi(fi),:)))));
            else
              cat_io_cprintf(opt.MarkColor(max(1,min(size(opt.MarkColor,1),...
                round( mqamatm(smqamatmi(fi),end)/9.5 * ...
                size(opt.MarkColor,1)))),:),sprintf(...
                Tline2,fi,sprintf('(%d)',smqamatmi(fi)),...
                fname, sqamatm(fi,:),mqamatm(smqamatmi(fi),:)));
            end
          end
        end
      end
      % print the results for each scan 
      if opt.verb>1 && numel(Pp0)>1
        fprintf('%s\n',repmat('-',size(Theader)));  
        if opt.orgval 
          fprintf(Tavg,'mean', cat_stat_nanmean(qamat,1), cat_stat_nanmean(mqamatm,1));   %#ok<CTPCT>
          fprintf(Tavg,'std' , cat_stat_nanstd(qamat,1),  cat_stat_nanstd(mqamatm,1));    %#ok<CTPCT>  
        else
          fprintf(Tavg,'mean', cat_stat_nanmean(qamatm,1), cat_stat_nanmean(mqamatm,1));   %#ok<CTPCT>
          fprintf(Tavg,'std' , cat_stat_nanstd(qamatm,1),  cat_stat_nanstd(mqamatm,1));    %#ok<CTPCT>  
        end 
      end
      if opt.verb>0, fprintf('\n'); end


      
      % result tables (cell structures)
      % ----------------------------------------------------------------
      if nargout>2 && opt.write_csv
        QAT   = [Cheader(1:end-1); ... there is no mean for the original measures
                 Po               , num2cell(qamat); ...
                 'mean'           , num2cell(cat_stat_nanmean(qamat,1)); ...
                 'std'            , num2cell( cat_stat_nanstd(qamat,1,1))];
        QATm  = [Cheader; ...
                 Po               , num2cell(qamatm)          , ...
                                    num2cell(cat_stat_nanmean(qamatm,2)); ...
                 'mean'           , num2cell(cat_stat_nanmean(qamatm,1))  , ...
                                    num2cell(cat_stat_nanmean(mqamatm,1)); ...
                 'std'            , num2cell( cat_stat_nanstd(qamatm,1,1)), ...
                                    num2cell( cat_stat_nanstd(mqamatm,1))];


        % write csv results
        % --------------------------------------------------------------
        if opt.write_csv
          pp = spm_fileparts(Pp0{1});
          cat_io_csv(fullfile(pp,reportfolder,[opt.prefix num2str(numel(Vo),'%04d') ...
            'cat_vol_qa2_values.csv']),QAT);
          cat_io_csv(fullfile(pp,reportfolder,[opt.prefix num2str(numel(Vo),'%04d') ...
            'cat_vol_qa2_marks.csv']),QATm);
        end
      end 
      
      if opt.verb>0
        fprintf('Quality Control for %d subject was done in %0.0fs\n', ...
          numel(Pp0),etime(clock,stime)); fprintf('\n');
      end



    case 'cat12err'
      opt = cat_check('checkinopt',varargin{end},defaults);
      QAS = cat12err(opt);


    case 'cat12ver'
      % main processing with subversions 
      [pp,ff,ee] = spm_fileparts(varargin{2}.fname);    
      
      % Call of different versions of the QC:
      % -------------------------------------------------------------------
      % estimation of the measures for the single case by different versions. 
      % To use other older cat_vol_qa versions copy them into a path and 
      % rename the filename and the all internal use of the functionname.
      % Extend the default variable versions0 for older functions without
      % SIQR and res_ECR measure. 
      % Older versions may use different parameters - check similar
      % pepared verions. 
      % -------------------------------------------------------------------
      if isfield(opt,'version') 
        if ~exist(opt.version,'file')
          error('cat_vol_qa2:missingVersion','Selected QC version is not available! '); 
        elseif ~strcmp(opt.version,mfilename)
          switch opt.version
            case {'cat_tst_qa20160204','cat_vol_qa20180207'}
              % here the 
              vx_vol  = sqrt(sum(varargin{2}.mat(1:3,1:3).^2));
              Yp0toC  = @(Yp0,c) 1-min(1,abs(Yp0-c));
              qa.subjectmeasures.vol_TIV = sum(varargin{1}(:)>0) ./ prod(vx_vol) / 1000;
              for i = 1:3
                qa.subjectmeasures.vol_abs_CGW(i) = sum( Yp0toC(varargin{1}(:),i)) ./ prod(vx_vol) / 1000; 
                qa.subjectmeasures.vol_rel_CGW(i) = qa.subjectmeasures.vol_abs_CGW(i) ./ ...
                                                     qa.subjectmeasures.vol_TIV; 
              end
              eval(sprintf('[QAS,QAR] = %s(''cat12'',varargin{1:4},struct(),varargin{5:end-1},struct(''qa'',qa));',opt.version));
            case {'cat_vol_qa202210'}
              eval(sprintf('QAS = %s(''cat12'',varargin{:});',opt.version));
            otherwise
              eval(sprintf('[QAS,QAR] = %s(''cat12'',varargin{:});',opt.version));
          end
        end
      end

      if 1 
        QAR = upate_rating(QAS,opt.version);
      else
      % update rating
        ndef =  cat_stat_marks('default');
        switch opt.version
          case {'cat_tst_qa20160204','cat_vol_qa20180207','cat_vol_qa201901'}
            ndef.noise = [0.046797 0.397905]; 
            ndef.bias  = [0.338721 2.082731];
          case {'cat_vol_qa201901_202301'}
            ndef.noise = [0.06 0.7]; 
            ndef.bias  = [0.185013 1.213851]; 
          case {'cat_vol_qa201901_202302'}
            ndef.noise = [ 0.0336  0.2958];  
            ndef.bias  = [ 0.1932  1.2037 * 2]; 
            ndef.ECR   = [-0.1135  1.1996]; ndef.ECR   = ndef.ECR*2   + 0.1 * diff(ndef.ECR);
            ndef.ECRmm = [ 0.2632  0.8855]; ndef.ECRmm = ndef.ECRmm*2 - 0.6 * diff(ndef.ECRmm);
          case {'cat_vol_qa201901_202303'}
            ndef.noise = [ 0.0336  0.2958];  
            ndef.bias  = [ 0.1932  1.2037 * 2]; 
            ndef.ECR   = [-0.1135  1.1996]; ndef.ECR   = ndef.ECR*2   + 0.1 * diff(ndef.ECR);
            ndef.ECRmm = [ 0.2632  0.8855]; ndef.ECRmm = ndef.ECRmm*2 - 0.6 * diff(ndef.ECRmm);
          case {'cat_vol_qa202110','cat_vol_qa202110r'}
            ndef.noise = [0.054406 0.439647]; 
            ndef.bias  = [0.190741 1.209683];
          case {'cat_vol_qa','cat_vol_qar','cat_vol_qa202302'}  
            ndef.noise = [0.056985 0.460958];
            ndef.bias  = [0.187620 1.206548]; 
          case {'cat_vol_qar_p0ECR'}  
            ndef.noise = [0.056985 0.300958];
            ndef.bias  = [0.187620 1.206548]; 
          case {'cat_vol_qa202207b','cat_vol_qa202210','cat_vol_qa202301'}
            ndef.noise = [0.026350 0.203736]; 
            ndef.bias  = [0.120658 0.755107]; 
          otherwise
            error('missing scaling definition');
        end
        ndef.QS{find(cellfun('isempty',strfind(ndef.QS(:,2),'NCR'))==0,1),4} = ndef.noise;
        ndef.QS{find(cellfun('isempty',strfind(ndef.QS(:,2),'ICR'))==0,1),4} = ndef.bias;
        if isfield(ndef,'ECR'),   ndef.QS{find(cellfun('isempty',strfind(ndef.QS(:,2),'ECR'  ))==0,1),4} = ndef.ECR;   end
        if isfield(ndef,'ECRmm'), ndef.QS{find(cellfun('isempty',strfind(ndef.QS(:,2),'ECRmm'))==0,1),4} = ndef.ECRmm; end
        QAR = cat_stat_marks('eval',1,QAS,ndef);
      end

      % export 
      if opt.write_xml
        QAS.qualityratings = QAR.qualityratings;
        QAS.subjectratings = QAR.subjectratings;
        QAS.ratings_help   = QAR.help;
        
        cat_io_xml(fullfile(pp,reportfolder,[opt.prefix ff '.xml']),QAS,'write'); %struct('QAS',QAS,'QAM',QAM)
      end
    otherwise
      % catched before
  end

  if (isempty(varargin) || isstruct(varargin{1})) && exist('Pp0','var')
    varargout{1}.data = Pp0;
  else
    if nargout>1, varargout{2} = QAR; end
    if nargout>0, varargout{1} = QAS; end 
  end
end
%==========================================================================
function [QAS, QAR, qamat, qamatm, mqamatm] = updateQAstructure(QAS, QASfi, QAR, QARfi, qamat, qamatm, mqamatm, QMAfn, fi)
%

  try
    QAS = cat_io_updateStruct(QAS,QASfi,0,fi);
    QAR = cat_io_updateStruct(QAR,QARfi,0,fi);
  catch
    fprintf('ERROR-Struct');
  end
  
  % color for the differen mark cases (opt.process)
  for fni = 1:numel(QMAfn)
    try
      qamat(fi,fni)  = QAS(fi).qualitymeasures.(QMAfn{fni});
      qamatm(fi,fni) = QAR(fi).qualityratings.(QMAfn{fni});
    catch
      qamat(fi,fni)  = QASfi.qualitymeasures.(QMAfn{fni});
      qamatm(fi,fni) = QARfi.qualityratings.(QMAfn{fni});
    end
    
  end
  try
    mqamatm(fi,1) = QAR(fi).qualityratings.IQR;
  catch
    mqamatm(fi,1) = QASfi.qualityratings.IQR;
  end

  if size(mqamatm,2)==2
    try
      mqamatm(fi,2) = QAR(fi).qualityratings.SIQR;
    catch
      mqamatm(fi,2) = QARfi.qualityratings.SIQR;
    end
  end

  mqamatm(fi,:) = max(0,min(10.5, mqamatm(fi,:)));
          
end
%==========================================================================
function [Yp0,Ym,Vo] = getImages(Pp0,Po,Pm,fi)
%

%  stime = cat_io_cmd('  Any segmentation Input:','g5','',opt.verb>2); stime1 = stime;

  [pp,ff,ee] = spm_fileparts(Po{fi});
  if exist(fullfile(pp,[ff ee]),'file')
    Vo  = spm_vol(Po{fi});
  elseif exist(fullfile(pp,[ff ee '.gz']),'file')
    gunzip(fullfile(pp,[ff ee '.gz']));
    Vo  = spm_vol(Po{fi});
    delete(fullfile(pp,[ff ee '.gz'])); 
  else
    error('cat_vol_qa2:noYo','No original image.');
  end
      
  Vm  = spm_vol(Pm{fi});
  Vp0 = spm_vol(Pp0{fi});
  if ~isempty(Vm) && any(Vp0.dim ~= Vm.dim)
    [Vx,Yp0] = cat_vol_imcalc(Vp0,Vm,'i1',struct('interp',2,'verb',0));
  else
    Yp0 = single(spm_read_vols(Vp0));
  end
  Yp0(isnan(Yp0) | isinf(Yp0)) = 0; 
  if 0 %~isempty(Pm{fi}) && exist(Pm{fi},'file')
    Ym  = single(spm_read_vols(spm_vol(Pm{fi})));
    Ym(isnan(Yp0) | isinf(Yp0)) = 0; 
  elseif 1 %end
  %if ~exist(Ym,'var') || round( cat_stat_nanmean(Ym(round(Yp0)==3)) * 100) ~= 100 
    if 0
      Ym  = single(spm_read_vols(spm_vol(Po{fi})));
      Ym(isnan(Yp0) | isinf(Yp0)) = 0; 
      Yw  = Yp0>2.95 | cat_vol_morph( Yp0>2.25 , 'e'); 
      Yb  = cat_vol_approx( Ym .* Yw + Yw .* min(Ym(:)) ) - min(Ym(:)); 
      %Yb  = Yb / mean(Ym(Yw(:)));
      Ym  = Ym ./ max(eps,Yb); 
    else
      %%
      vx_vol  = sqrt(sum(Vo.mat(1:3,1:3).^2));
      Ym  = single(spm_read_vols(spm_vol(Po{fi})));
      Ym(isnan(Yp0) | isinf(Yp0)) = 0; 
      Yw  = cat_vol_morph( Yp0>2.95 , 'e',1,vx_vol)  & cat_vol_morph( Yp0>2.25 , 'e',2,vx_vol); 
      Yb  = cat_vol_approx( Ym .* Yw + Yw .* min(Ym(:)) ,2) - min(Ym(:)); 
      %Yb  = cat_vol_smooth3X(Yb,8);
      %Yb  = Yb / cat_stat_nanmedian(Ym(Yw(:)));
      Ym  = Ym ./ max(eps,Yb); 
    end
  else
    error('cat_vol_qa2:noYm','No corrected image.');
  end
  rmse = (mean(Ym(Yp0(:)>0) - Yp0(Yp0(:)>0)/3).^2).^0.5; 
  if rmse>0.2
    cat_io_cprintf('warn','Segmentation is maybe not fitting to the image (RMSE(Ym,Yp0)=%0.2f)?:\n  %s\n  %s',rmse,Pm{fi},Pp0{fi}); 
  end      
end
%==========================================================================
function QAS = cat12err(opt)
%cat12err. Create short report in case of CAT preprocessing error. 
% This report contain basic parameters used for the CAT error report
% creation in cat_io_report.

  % file information
  % -----------------------------------------------------------------------
  [pp,ff,ee]          = spm_fileparts(opt.job.channel.vols{opt.subj});
  [QAS.filedata.path,QAS.filedata.file] = ...
                        spm_fileparts(opt.job.channel.vols{opt.subj});
  QAS.filedata.fname  = opt.job.data{opt.subj};
  QAS.filedata.F      = opt.job.data{opt.subj}; 
  QAS.filedata.Fm     = fullfile(pp,mrifolder,['m'  ff ee]);
  QAS.filedata.Fp0    = fullfile(pp,mrifolder,['p0' ff ee]);
  QAS.filedata.fnames = [ 
    spm_str_manip(pp,sprintf('k%d', ...
      floor( max(opt.snspace(1)-19-ff,opt.snspace(1)-19)/3) - 1)), '/',...
    spm_str_manip(ff,sprintf('k%d',...
     (opt.snspace(1)-19) - floor((opt.snspace(1)-14)/3))), ...
     ];
  
  
  % software, parameter and job information
  % -----------------------------------------------------------------------
  [nam,rev_spm] = spm('Ver');
  QAS.software.version_spm = rev_spm;
  if strcmpi(spm_check_version,'octave')
    QAS.software.version_octave = version;  
  else
    A = ver;
    for i=1:length(A)
      if strcmp(A(i).Name,'MATLAB')
        QAS.software.version_matlab = A(i).Version; 
      end
    end
    clear A
  end

  % 1 line: Matlab, SPM12, CAT12 version number and GUI and experimental mode 
  if ispc,      OSname = 'WIN';
  elseif ismac, OSname = 'MAC';
  else,         OSname = 'LINUX';
  end
  
  QAS.software.system       = OSname;
  QAS.software.version_cat  = ver_cat;
  if ~isfield(QAS.software,'version_segment')
    QAS.software.version_segment = rev_cat;
  end
  QAS.software.revision_cat = rev_cat;
  try
    QAS.hardware.numcores = max(cat_get_defaults('extopts.nproc'),1);
  catch
    QAS.hardware.numcores = 1;
  end
  
  
  % save important preprocessing parameters 
  QAS.parameter.opts        = opt.job.opts;
  QAS.parameter.extopts     = rmfield(opt.job.extopts,...
    {'LAB','atlas','satlas','darteltpms','shootingtpms','fontsize'});
  QAS.parameter.caterr      = opt.caterr; 
  QAS.error                 = opt.caterrtxt; 
  
  % export 
  if opt.write_xml
    cat_io_xml(fullfile(pp,reportfolder,[opt.prefix ff '.xml']),QAS,'write');
  end
end
%==========================================================================
function def = defaults
%default. cat_vol_qa22 default parameters. 

  def.verb       = 2;         % verbose level  [ 0=nothing | 1=points | 2*=results ]
  def.write_csv  = 2;         % final cms-file [ 0=do not write |1=write | 2=overwrite ] 
  def.write_xml  = 1;         % images base xml-file
  def.sortQATm   = 1;         % sort QATm output
  def.orgval     = 0;         % original QAM results (no marks)
  def.avgfactor  = 2;         % ############ USED ???
  def.prefix     = 'cat_';    % prefix of QC variables
  def.mprefix    = 'm';       % prefix of the preprocessed image              ############ USED ???
  def.process    = 3;         % used image [ 0=T1 | 1=mT1 | 2=avg | 3=both ]  ############ USED ???
%  def.calc_MPC   = 0;         % ############ USED ???
%  def.calc_STC   = 0;         % ############ USED ???
%  def.calc_MJD   = 0;         % ############ USED ???
  def.repair     = 1; 
  def.method     = 'spm';     % used 
  def.snspace    = [100,7,3];
  def.nogui      = exist('XT','var');
  def.rerun      = 1;         % 0-load if exist, 1-reprocess if "necessary", 2-reprocess 
  def.verb       = 2; 
  def.version    = 'cat_vol_qa';
  def.MarkColor  = cat_io_colormaps('marks+',40); 
  def.versions0  = {'cat_tst_qa20160204','cat_vol_qa20180207'};  % no ECR
  def.versions1  = {'cat_vol_qa201901_202302','cat_vol_qa201901_202303'}; % have ECRmm
end
%==========================================================================
function QARfi = upate_rating(QASfi,version)
% update 
  ndef =  cat_stat_marks('default');
  switch version
    case {'cat_tst_qa20160204','cat_vol_qa20180207','cat_vol_qa201901'}
      ndef.noise = [0.046797 0.397905]; 
      ndef.bias  = [0.338721 2.082731];
    case {'cat_vol_qa201901_202301'}
      ndef.noise = [0.06 0.7]; 
      ndef.bias  = [0.185013 1.213851]; 
    case {'cat_vol_qa201901_202302'}
      ndef.noise = [ 0.0336  0.2958];  
      ndef.bias  = [ 0.1932  1.2037 * 2]; 
      ndef.ECR   = [-0.1135  1.1996]; ndef.ECR   = ndef.ECR*2   + 0.1 * diff(ndef.ECR);
      ndef.ECRmm = [ 0.2632  0.8855]; ndef.ECRmm = ndef.ECRmm*2 - 0.6 * diff(ndef.ECRmm);
    case {'cat_vol_qa201901_202303'}
      ndef.noise = [ 0.0336  0.2958];  
      ndef.bias  = [ 0.1932  1.2037 * 2]; 
      ndef.ECR   = [-0.1135  1.1996]; ndef.ECR   = ndef.ECR   - 0.1 + 0.1 * diff(ndef.ECR);
      ndef.ECRmm = [ 0.2632  0.8855]; ndef.ECRmm = ndef.ECRmm + 0.1 - 0.6 * diff(ndef.ECRmm);
    case {'cat_vol_qa202110','cat_vol_qa202110r'}
      ndef.noise = [0.054406 0.439647]; 
      ndef.bias  = [0.190741 1.209683];
    case {'cat_vol_qa','cat_vol_qar','cat_vol_qa202302'}  
      ndef.noise = [0.056985 0.460958];
      ndef.bias  = [0.187620 1.206548]; 
    case {'cat_vol_qar_p0ECR'}  
      ndef.noise = [0.056985 0.300958];
      ndef.bias  = [0.187620 1.206548]; 
    case {'cat_vol_qa202207b','cat_vol_qa202210','cat_vol_qa202301'}
      ndef.noise = [0.026350 0.203736]; 
      ndef.bias  = [0.120658 0.755107]; 
    otherwise
      error('missing scaling definition');
  end
  ndef.QS{find(cellfun('isempty',strfind(ndef.QS(:,2),'NCR'))==0,1),4} = ndef.noise;
  ndef.QS{find(cellfun('isempty',strfind(ndef.QS(:,2),'ICR'))==0,1),4} = ndef.bias;
  if isfield(ndef,'ECR'),   ndef.QS{find(cellfun('isempty',strfind(ndef.QS(:,2),'ECR'  ))==0,1),4} = ndef.ECR;   end
  if isfield(ndef,'ECRmm'), ndef.QS{find(cellfun('isempty',strfind(ndef.QS(:,2),'ECRmm'))==0,1),4} = ndef.ECRmm; end
  QARfi = cat_stat_marks('eval',1,QASfi,ndef);
end
