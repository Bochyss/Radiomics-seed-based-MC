function gretna_preprocessing_longitudinal_Segmentation_CAT12(Data_path, File_filter, Para)

%==========================================================================
% This function is used to perform tissue segmentation of longitudinal
% images (typically structural MRI images) with the CAT12 toolbox. The
% longitudinal images can be organized in two ways: subjects mode and
% timepoints mode. It should be noted that if you have a varying number of
% time points for each sujbject, you must use the subjects mode. Suppose
% you have N subjects who are scanned M times, then the subjects mode means
% that the images should be organized like:                        
%                           xxx\sub1
%                                   \sub1_timepoint1.nii
%                                   \sub1_timepoint2.nii
%                                   ......
%                                   \sub1_timepointM.nii
%                           xxx\sub2
%                                   \sub2_timepoint1.nii
%                                   \sub2_timepoint2.nii
%                                   ......
%                                   \sub2_timepointM.nii
%
%                           ......
%
%                           xxx\subN
%                                   \subN_timepoint1.nii
%                                   \subN_timepoint2.nii
%                                   ......
%                                   \subN_timepointM.nii
%
% and the timepoints mode means that the images should be organized like:
%                     xxx\timepoint1
%                                   \timepoint1_sub1.nii
%                                   \timepoint1_sub2.nii
%                                   ......
%                                   \timepoint1_subN.nii
%                     xxx\timepoint2
%                                   \timepoint2_sub1.nii
%                                   \timepoint2_sub2.nii
%                                   ......
%                                   \timepoint2_subN.nii
%
%                     ......
%
%                     xxx\timepointM
%                                   \timepointM_sub1.nii
%                                   \timepointM_sub2.nii
%                                   ......
%                                   \timepointM_subN.nii
%
% Syntax: function gretna_preprocessing_longitudinal_Segmentation_CAT12(Data_path, File_filter, Para)
%
% Inputs:
%         Data_path:
%                   The directory & filename of a .txt file that contains
%                   the directory of those files to be processed (can be
%                   obtained by gretna_gen_data_path.m).
%       File_filter:
%                   The prefix of those files to be processed.
%   Para (optional):
%           Para.Segment.Nthreads:
%                   The number of threads for parallel calculation.
%           Para.Segment.SubjectsOrder:
%                   'Subjects':   One folder per subject.
%                   'Timepoints': One folder per timepoint.
%           Para.Segment.Regularisation:
%                   'European':   Affine regularisation using European
%                                 template.
%                   'East Asian': Affine regularisation using East Asian
%                                 template.
%           Para.Segment.Registration:
%                   'Shooting': Spatial shooting registration
%                               (Ashburner, 2008).
%                   'Dartel':   Spatial dartel registration
%                               (Ashburner, 2011).
%           Para.Segment.longmodel:
%                   'Small changes': Detcting changes such as plasticity
%                                    and learning.
%                   'Large changes': Detcting changes such as ageing and
%                                    development.
%           Para.Segment.Type:
%                   'yes': VBM with surface and thickness estimation.
%                   'no':  VBM without surface and thickness estimation.
%           Para.Segment.TPM_path:
%                   The TPM used to initial spm segment. It is ok to use
%                   SPM default for very old/young brains. Nevertheless,
%                   for children data, it is recommended to use
%                   customized TPMs created with the Template-O-Matic
%                   toolbox.
% 
% Ningkai WAng,IBRR, SCNU, Guangzhou, 2020/09/20, ningkai.wang.1993@gmail.com
% Jinhui WANG, IBRR, SCNU, Guangzhou, 2020/09/14, jinhui.wang.1982@gmail.com
%==========================================================================

%% spm_input
warndlg(['\color[rgb]{1,0,0} The option ''Subjects Order'' is VERY IMPORTANT.'...
    'Please make sure that your choice matches your data organization mode!'],'Warning',...
    struct('WindowStyle','modal','Interpreter','tex'));

if nargin == 2
    Para.Segment.Nthreads       = spm_input('Number of Threads',                 1, 'e', [], 1);
    Para.Segment.subOrder       = spm_input('Subjects Order',                    2, 'Subjects|Timepoints');
    Para.Segment.Regularisation = spm_input('Affine Regularisation',             3, 'European|East Asian');
    Para.Segment.Registration   = spm_input('Spatial Registration',              4, 'Shooting|Dartel');
    Para.Segment.longmodel      = spm_input('Detecting Model',                   5, 'Small changes|Large changes');
    Para.Segment.Type           = spm_input('Whether Surface and CT Estimation', 6, 'yes|no');
    Para.Segment.TPM            = spm_input('TPM',                               7, 'SPM Default|Study Specific');
    
    if strcmp(Para.Segment.TPM, 'SPM Default')
        if exist('spm','file') == 2
            spm_dir = which('spm');
            [pathstr, ~, ~] = fileparts(spm_dir);
            Para.Segment.TPM_path = fullfile(pathstr, 'tpm', 'TPM.nii');
        else
            error('Cannot find SPM toolbox in Matlab search path of your computer!!')
        end
    else
        Para.Segment.TPM_path = spm_input('Enter TPM Path', 8, 's');
    end
end
close


%% update batch parameters
load gretna_Segmentation_long_CAT12.mat
batch_segment = matlabbatch;

batch_segment{1}.spm.tools.cat.long.nproc = Para.Segment.Nthreads;

if exist('cat12','file') == 2
    cat_dir = which('cat12');
    [pathstr, ~, ~] = fileparts(cat_dir);
    
    % affine regularisation
    switch lower(Para.Segment.Regularisation)
    case 'european'
        batch_segment{1}.spm.tools.cat.long.opts.affreg = 'mni';
    case 'east asian'
        batch_segment{1}.spm.tools.cat.long.opts.affreg = 'eastern';
    end

    % spatial registration
    switch lower(Para.Segment.Registration)
    case 'shooting'
        batch_segment{1}.spm.tools.cat.long.extopts.registration.shooting.shootingtpm{1} = ...
            fullfile(pathstr, 'templates_volumes', 'Template_0_IXI555_MNI152_GS.nii');
    case 'dartel'
        batch_segment{1}.spm.tools.cat.long.extopts.registration.dartel.darteltpm{1} = ...
            fullfile(pathstr, 'templates_volumes', 'Template_1_IXI555_MNI152.nii');
    end
else
    error('Cannot find CAT toolbox in Matlab search path of your computer!!')
end

% detecting model
switch lower(Para.Segment.longmodel)
    case {'small changes', 1}
        batch_segment{1}.spm.tools.cat.long.longmodel = 1;
    case {'large changes', 2}
        batch_segment{1}.spm.tools.cat.long.longmodel = 2;
end

% surface estimation
if strcmpi(Para.Segment.Type, 'yes')
    batch_segment{1}.spm.tools.cat.long.output.surface = 1;
else
    batch_segment{1}.spm.tools.cat.long.output.surface = 0;
end

% TPM
batch_segment{1}.spm.tools.cat.long.opts.tpm{1} = Para.Segment.TPM_path;


%% Update batch data
fid         = fopen(Data_path);
Dir_data    = textscan(fid, '%s');
fclose(fid);

Num_folders = size(Dir_data{1},1);
Sour_all    = cell(Num_folders,1);

for isub = 1:Num_folders
    cd([Dir_data{1}{isub}])
    Sour_ind = spm_select('ExtList', pwd, ['^' File_filter '.*' filesep '.nii$'],inf);
    
    if isempty(Sour_ind)
        Sour_ind = spm_select('ExtList', pwd, ['^' File_filter '.*' filesep '.img$'],inf);
    end
    
    [Num_img, ~]     = size(Sour_ind);
    Sour_all{isub,1} = cellstr(cat(1,[repmat(Dir_data{1}{isub},Num_img,1) repmat(filesep,Num_img,1) Sour_ind]));
end

switch lower(Para.Segment.subOrder)
    case 'subjects'
        batch_segment{1}.spm.tools.cat.long.datalong.subjects   = Sour_all;
    case 'timepoints'
        batch_segment{1}.spm.tools.cat.long.datalong.timepoints = Sour_all;
end


%% Run batch
spm_jobman('run',batch_segment);

return