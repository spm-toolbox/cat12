% ---------------------------------------------------------------------
% Test batch "Segment Data" for VBM, SBM, and RBM preprocessing of 
% cat_tst_cattest.
% ---------------------------------------------------------------------
% Robert Dahnke
% $Id$

if ~exist('files_human','var')
  files_human = {'<UNDEFINED>'};
  exp = cat_get_defaults('extopts.expertgui'); 
elseif isempty(files_human)
  return;
end

% batch
% -- opts --------------------------------------------------------------
matlabbatch{1}.spm.tools.cat.estwrite.data                       = files_human;
matlabbatch{1}.spm.tools.cat.estwrite.nproc                      = 0;
matlabbatch{1}.spm.tools.cat.estwrite.opts.tpm                   = { fullfile( spm('dir') , 'tpm' , 'TPM.nii' ) };
matlabbatch{1}.spm.tools.cat.estwrite.opts.affreg                = 'mni';
if exp>0 % EXPERT
  matlabbatch{1}.spm.tools.cat.estwrite.opts.ngaus               = [3 3 2 3 4 2];
  matlabbatch{1}.spm.tools.cat.estwrite.opts.biasreg             = 0.001;
  matlabbatch{1}.spm.tools.cat.estwrite.opts.biasfwhm            = 60;
  matlabbatch{1}.spm.tools.cat.estwrite.opts.warpreg             = [0 0.001 0.5 0.05 0.2];
  matlabbatch{1}.spm.tools.cat.estwrite.opts.samp                = 3;
end
% -- extopts -----------------------------------------------------------
matlabbatch{1}.spm.tools.cat.estwrite.extopts.LASstr             = 0.5;       
matlabbatch{1}.spm.tools.cat.estwrite.extopts.gcutstr            = 0.5;       
matlabbatch{1}.spm.tools.cat.estwrite.extopts.cleanupstr         = 0.5;       
matlabbatch{1}.spm.tools.cat.estwrite.extopts.darteltpm          = { fullfile( spm('dir') , 'toolbox' , 'cat12' , 'templates_1.50mm' , 'Template_1_IXI555_MNI152.nii' ) };
matlabbatch{1}.spm.tools.cat.estwrite.extopts.vox                = 1.5;
if exp>0 % EXPERT
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.APP              = 1;        
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.sanlm            = 1;       % noise filter
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.NCstr            = Inf;     % noise filter strength 
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.WMHCstr          = 0.5;     
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.WMHC             = 1;       
  %matlabbatch{1}.spm.tools.cat.estwrite.extopts.restypes.best    = [1 0.3];  
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.ignoreErrors     = 1;        
end
if exp>1 % DEVELOPER
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.BVCstr           = 0;       
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.cat12atlas       = { fullfile( spm('dir') , 'toolbox' , 'cat12' , 'templates_1.50mm' , 'cat.nii' ) };
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.brainmask        = { fullfile( spm('dir') , 'toolbox' , 'FieldMap' , 'brainmask.nii' ) };
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.T1               = { fullfile( spm('dir') , 'toolbox' , 'FieldMap' ,  'T1.nii' ) };
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.pbtres           = 0.5;
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.lazy             = 0;
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.debug            = 1;         
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.verb             = 2;         
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.tca              = 1; 
  matlabbatch{1}.spm.tools.cat.estwrite.extopts.mrf              = 1;  
end
% -- output ------------------------------------------------------------
matlabbatch{1}.spm.tools.cat.estwrite.output.ROI                 = 1;  % RBM preprocessing
matlabbatch{1}.spm.tools.cat.estwrite.output.surface             = 1;  % SBM preprocessing
% GM
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.native           = 1;
if exp>0, matlabbatch{1}.spm.tools.cat.estwrite.output.GM.warped = 1; end
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.mod              = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.dartel           = 1;
% WM
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.native           = 1;
if exp>0, matlabbatch{1}.spm.tools.cat.estwrite.output.WM.warped = 1; end
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.mod              = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.dartel           = 1;
% CSF
if exp>0 % EXPERT
  matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.native        = 1;
  matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.warped        = 0;
  matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.mod           = 0;
  matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.dartel        = 0;
  % WMH (for WMHC>0)
  matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.native        = 1;
  matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.warped        = 0;
  matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.mod           = 0;
  matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.dartel        = 0;
  % label map
  matlabbatch{1}.spm.tools.cat.estwrite.output.label.native      = 1;
  matlabbatch{1}.spm.tools.cat.estwrite.output.label.warped      = 1;
  matlabbatch{1}.spm.tools.cat.estwrite.output.label.dartel      = 1;
  % global intensity normalized
  matlabbatch{1}.spm.tools.cat.estwrite.output.bias.native       = 1;
  matlabbatch{1}.spm.tools.cat.estwrite.output.bias.warped       = 1;
  matlabbatch{1}.spm.tools.cat.estwrite.output.bias.dartel       = 1;
  % local intensity normalized
  matlabbatch{1}.spm.tools.cat.estwrite.output.las.native        = 1;
  matlabbatch{1}.spm.tools.cat.estwrite.output.las.warped        = 1;
  matlabbatch{1}.spm.tools.cat.estwrite.output.las.dartel        = 1;
end
if exp>1 % DEVELOPER
  % TPMC (for TPM creation, e.g., to create an animal template)
  matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.native       = 1;
  matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.warped       = 0;
  matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.mod          = 0;
  matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.dartel       = 0;
  % atlas maps (for atlas creation, e.g., in an animal tempate)
  matlabbatch{1}.spm.tools.cat.estwrite.output.atlas.native      = 1;
  matlabbatch{1}.spm.tools.cat.estwrite.output.atlas.warped      = 0;
  matlabbatch{1}.spm.tools.cat.estwrite.output.atlas.dartel      = 0;
end
% jacobian
matlabbatch{1}.spm.tools.cat.estwrite.output.jacobian.warped   = 1;
% deformation 
matlabbatch{1}.spm.tools.cat.estwrite.output.warps             = [1 1];