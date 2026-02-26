import os


def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return template, outtype, annotation_classes


def infotodict(seqinfo):
    """Heuristic evaluator for determining which runs belong where

    allowed template fields - follow python string module:

    item: index within category
    subject: participant id
    seqitem: run number during scanning
    subindex: sub index within group
    """

    t1 = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_T1w')
    t2 = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_T2w')
   
    func_image=create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-image_run-{item:01d}_bold')
    func_rest=create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_bold')
    func_retrans = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-retrans_run-{item:01d}_bold')
    
   # fmaps=create_key('sub-{subject}/{session}/fmaps/sub-{subject}_{session}_acq-{item:01d}_dir-PA_epi')
    fmaps=create_key('sub-{subject}/{session}/fmaps/sub-{subject}_{session}_acq-{item:01d}_epi')
    
    DWI=create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_acq-DSI_dwi')
    
    info = {
            t1: [], t2: [], DWI: [],
            func_image: [], func_rest: [], func_retrans: [],
            fmaps: []
           }
    
    
    for s in seqinfo:
        """
        The namedtuple `s` contains the following fields:

        * total_files_till_now
        * example_dcm_file
        * series_id
        * dcm_dir_name
        * unspecified2
        * unspecified3
        * dim1
        * dim2
        * dim3
        * dim4
        * TR
        * TE
        * protocol_name
        * is_motion_corrected
        * is_derived
        * patient_id
        * study_description
        * referring_physician_name
        * series_description
        * image_type
        """
        
        #if (s.dim1 == 256) and (s.dim2 == 192) and ('MPRAGE_TI1100_ipat2' in s.series_id):
        if ('MPRAGE_TI1100_ipat2' in s.series_id):
            info[t1].append(s.series_id)
            
        if ((s.dim4 == 395) and ('BOLD_IMAGE' in s.series_description)):
            info[func_image].append(s.series_id)
        
        if ('RETRANS' in s.series_description):
            info[func_retrans].append(s.series_id)
            
        if ('DSI' in s.series_description):
            info[DWI].append(s.series_id)
            
        if ('T2_1mm_SPACE' in s.series_id):
            info[t2].append(s.series_id)
        
        if ('resting' in s.series_description):
            info[func_rest].append(s.series_id)
        
        if ('map' in s.series_description):
            info[fmaps].append(s.series_id)
            
    return info
