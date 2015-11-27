function long = cat_conf_long
% Configuration file for longitudinal data
%
% Christian Gaser
% $Id$

mov = cfg_files;
mov.name = 'Longitudinal data for this subject';
mov.tag  = 'mov';
mov.filter = 'image';
mov.num  = [1 Inf];
mov.help   = {...
'These are the data of the same subject.'};
%------------------------------------------------------------------------

subj = cfg_branch;
subj.name = 'Subject';
subj.tag = 'subj';
subj.val = {mov};
subj.help = {...
'Images of the same subject.'};

%------------------------------------------------------------------------

esubjs         = cfg_repeat;
esubjs.tag     = 'esubjs';
esubjs.name    = 'Data';
esubjs.values  = {subj};
esubjs.num     = [1 Inf];
esubjs.help = {...
'Specify data for each subject.'};

%------------------------------------------------------------------------

surface        = cfg_menu;
surface.tag    = 'surface';
surface.name   = 'Surface and thickness estimation';
surface.labels = {'No','Yes'};
surface.values = {0 1};
surface.def    = @(val)cat_get_defaults('output.surface', val{:});
surface.help   = {
  'Use PBT (Dahnke et al. 2012) to estimate cortical thickness and to create the central cortical surface for left and right hemisphere. Surface reconstruction includes topology correction (Yotter et al. 2011), spherical inflation (Yotter et al.) and spherical registration.'
''
  'Please note, that surface reconstruction additionally requires about 20-60 min of computation time.'
''
};

%------------------------------------------------------------------------
modulate        = cfg_menu;
modulate.tag    = 'modulate';
modulate.name   = 'Modulated GM/WM segmentations';
modulate.labels = {'No','Yes'};
modulate.values = {0 1};
modulate.val    = {1};
modulate.help = {
'"Modulation" is to compensate for the effect of spatial normalisation. Spatial normalisation causes volume changes due to affine transformation (global scaling) and non-linear warping (local volume change). After modulation the resulting modulated images are preserved for the total amount of grey matter signal in the normalised partitions. Thus, modulated images reflect the tissue volumes before spatial normalisation. However, the user is almost always interested in removing the confound of different brain sizes and there are many ways to apply this correction. In contrast to previous VBM versions I now recommend to use total intracranial volume (TIV) as nuisance parameter in an AnCova model. '
''
'Please note that I do not use the SPM modulation where the original voxels are projected into their new location in the warped images because this method introduces aliasing artifacts. Here, I use the scaling by the Jacobian determinants to generate "modulated" data. '
''
'For longitudinal data the modulation is actually not necessary because normalization estimates for one subject are the same for all time points and thus modulation will be also the same for all time points. However, modulation might be useful if you want to compare the baseline images in a cross-sectional design in order to test whether there are any differences between the groups at the beginning of the longitudinal study. '
''
};

%------------------------------------------------------------------------
output      = cfg_branch;
output.tag  = 'output';
output.name = 'Writing options';
output.val  = {surface};
output.help = {
'Additionally to the segmentations the surfacess can be estimated and saved.'
''
};

%------------------------------------------------------------------------
extopts = cat_conf_extopts;
opts    = cat_conf_opts;
%------------------------------------------------------------------------

long = cfg_exbranch;
long.name = 'Segment longitudinal data';
long.tag  = 'long';
long.val  = {esubjs,opts,extopts,output,modulate};
long.prog = @cat_long_multi_run;
long.vout = @vout_long;
long.help = {
'This option provides customized processing of longitudinal data. Please note that this processing pipeline was optimized for processing and detecting small changes over time as response to short-time plasticity effects (e.g. due to learning and training). This pipelines will not work properly for large longitudinal changes where large parts of the brain will change over time (e.g. atropy due to Alzheimers disease or ageing). This is due to the effect that the spatial normalization parameters are estimated using a mean image of all time points and subsequently applied to all time points. If large atrophy occurs between the time points this can lead to a shift of tissue borders and might result in areas of decreased volumes over time that are surrounded by areas of increased volumes due to this shifting issues. For data with large volume changes over time I would recommend to use the cross-sectional pipeline or the longitudinal toolbox in SPM12.'
''
};

%------------------------------------------------------------------------

return;
%------------------------------------------------------------------------
 
%------------------------------------------------------------------------
function dep = vout_long(job)
for k=1:numel(job.subj)
    cdep(k)            = cfg_dep;
    cdep(k).sname      = sprintf('Segmented longitudinal data (Subj %d)',k);
    cdep(k).src_output = substruct('.','sess','()',{k},'.','files');
    cdep(k).tgt_spec   = cfg_findspec({{'filter','image','strtype','e'}});
    if k == 1
        dep = cdep;
    else
        dep = [dep cdep];
    end
end;
%------------------------------------------------------------------------
