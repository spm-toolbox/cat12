function cat_stat_ROI(p)
%cat_stat_ROI to save mean values inside ROI for many subjects
%
%_______________________________________________________________________
% Christian Gaser
% $Id$

n_data = length(p.roi_xml);

% first divide data into volume and surface data because they have to be handled separately
i_vol = 0; i_surf = 0; roi_vol = {}; roi_surf = {};
for i=1:n_data        
  if ~isempty(strfind(p.roi_xml{i},'catROI_'))
    i_vol = i_vol + 1;
    roi_vol{i_vol,1} = p.roi_xml{i};
  elseif ~isempty(strfind(p.roi_xml{i},'catROIs_'))
    i_surf = i_surf + 1;
    roi_surf{i_surf,1} = p.roi_xml{i};
  end
end

save_ROI(p,roi_vol);
save_ROI(p,roi_surf);

%_______________________________________________________________________
function save_ROI(p,roi)
% save mean values inside ROI

% ROI measures to search for
ROI_measures = char('Vgm','Vwm','Vcsf','mean_thickness','mean_fractaldimension','mean_amc','mean_gyrification','mean_sqrtsulc');
n_ROI_measures = size(ROI_measures,1);

[path, roi_name, ext] = fileparts(p.calcroi_name);

n_data = length(roi);

for i=1:n_data        
  xml = convert(xmltree(deblank(roi{i})));

  if ~isfield(xml,'ROI')
    error('XML file contains no ROI information.');
  end

  % remove leading catROI*_ part from name
  [path2, ID] = fileparts(roi{i});
  ind = strfind(ID,'_');
  ID = ID(ind(1)+1:end);

  atlases = fieldnames(xml.ROI);
  n_atlases = numel(atlases);
  
  for j=1:n_atlases
    measures = fieldnames(xml.ROI.(atlases{j}));
    if ~isfield(xml.ROI.(atlases{j}),'tr')
      n_measures = numel(measures);
      if ~isfield(xml.ROI.(atlases{j}).(measures{1}),'tr')
        error('Missing mandatory tr-field in XML file.');
      end
    else n_measures = 1; end
    
    for m=1:n_measures
      
      tr = xml.ROI.(atlases{j}).(measures{m}).tr;
      n_ROIs = numel(tr) - 1; % ignore header
      hdr = tr{1}.td;
    
      for k=1:numel(hdr)
        for l=1:n_ROI_measures

          % check for field with ROI names
          if strcmp(hdr{k},'ROIappr') || strcmp(hdr{k},'ROIabbr') || strcmp(hdr{k},'lROIname') || strcmp(hdr{k},'rROIname')
            name_index = k;
          end

          % look for pre-defined ROI measures
          if strcmp(hdr{k},deblank(ROI_measures(l,:)))
        
            % create filename with information about atlas and measures and print ROI name
            if (i==1) 
              out_name = fullfile(path,[ roi_name '_' deblank(atlases{j}) '_' hdr{k} '.csv']);
              fid{j,k,m} = fopen(out_name,'w');
              
              if fid{j,k,m} < 0
                error(sprintf('Writing error for file %s\nCheck that you have writing permissions.',out_name));
              end
              
              fprintf('Save values in %s\n',out_name);

              fprintf(fid{j,k,m},'Name\t');
              for r=1:n_ROIs
                fprintf(fid{j,k,m},'%s\t',char(tr{r+1}.td(name_index)));
              end
            end

            % print ROI values
            fprintf(fid{j,k,m},'\n%s\t',ID);
            for r=1:n_ROIs
              fprintf(fid{j,k,m},'%s\t',char(tr{r+1}.td(k)));
            end
          
            % close files after last dataset
            if (i==n_data)
              fclose(fid{j,k,m});
            end
                              
          end        
        end
      end
    end
  end
end
