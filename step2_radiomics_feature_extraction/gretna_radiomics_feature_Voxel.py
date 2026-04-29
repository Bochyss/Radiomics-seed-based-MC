import multiprocessing
import os
import sys

import SimpleITK as sitk
from radiomics import featureextractor

def resample(Path_mask,output_filepath):
    im = sitk.ReadImage(Path_mask)
    map = sitk.ReadImage(output_filepath)

    rif = sitk.ResampleImageFilter()
    rif.SetReferenceImage(im)
    rif.SetInterpolator(sitk.sitkNearestNeighbor)

    map_res = rif.Execute(map)
    sitk.WriteImage(map_res, output_filepath)


def process_image(image_dir, sub_id, file_filter, Path_mask, Output_path, params_path):
    sub_directory_path = os.path.join(Output_path, sub_id)
    nii_files = [f for f in os.listdir(image_dir) if file_filter in f]
    if nii_files:
        for image in range(0, len(nii_files)):
            nii_filename = nii_files[image]
            nii_filename_without_ext = os.path.splitext(nii_filename)[0]
            image_directory_path = os.path.join(sub_directory_path, nii_filename_without_ext)
            os.makedirs(image_directory_path, exist_ok=True)
            nii_file = os.path.join(image_dir, nii_filename)

            extractor = featureextractor.RadiomicsFeatureExtractor(params_path)

            result = extractor.execute(nii_file, Path_mask, voxelBased=True)
            
            for key, val in result.items():
                if isinstance(val, sitk.Image):  # Feature map
                    output_filepath = os.path.join(str(image_directory_path), key + '.nii')
                    
                    sitk.WriteImage(val, output_filepath, True)

                    resample(Path_mask, output_filepath)
                    print("Stored feature %s in %s" % (key, output_filepath))
                else:  # Diagnostic information
                    print("\t%s: %s" % (key, val))

            print(f'Completed subject {sub_id}')
    else:
        print(f'Nii file not found in {sub_id}')

def generate_subject_dictionary(sub_dict, dirs, prefix_path='', group_info=''):
    if not dirs:
        return

    common_root = os.path.commonpath(dirs)
    first_name = [os.path.relpath(dir, common_root).split(os.sep)[0] for dir in dirs]
    if len(set(first_name)) == len(first_name):
        for dir in dirs:
            key = os.path.join(prefix_path, dir)
            value = os.path.join(group_info, os.path.relpath(dir, common_root).split(os.sep)[0])
            sub_dict[key] = value
    else:
        group_dict = {}
        for group in set(first_name):
            group_dict[group] = []
        for dir in dirs:
            group_name = os.path.relpath(dir, common_root).split(os.sep)[0]
            rest = os.path.relpath(dir, common_root).split(os.sep)[1:]
            if rest:
                group_dict[group_name].append(os.path.join(*rest))
            else:
                key = os.path.join(prefix_path, dir)
                sub_dict[key] = group_name
        for group in set(first_name):
            prefix = os.path.join(prefix_path, common_root, group)
            group_path = os.path.join(group_info, group)
            generate_subject_dictionary(sub_dict, group_dict[group], prefix, group_path)

if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: python script.py Data_path File_filter Path_mask Output_path batch_size (optional)")
    else:
        Data_path = sys.argv[1]
        File_filter = sys.argv[2]
        Path_mask = sys.argv[3]
        Output_path = sys.argv[4]
        num_workers = multiprocessing.cpu_count()
        
        if len(sys.argv) >= 6:
            try:
                batch_size = int(sys.argv[5])
            except ValueError:
                print("batch_size must be an integer")
                sys.exit(1)
        else:
            batch_size = 1 

        if not os.path.exists(Output_path):
            os.makedirs(Output_path)

        BASE_DIR = os.path.dirname(os.path.abspath(__file__))
        params_path = os.path.join(BASE_DIR, "gretna_radiomics_feature_Voxel_parameter_setting.yaml")

        with open(Data_path, 'r') as f:
            all_dirs = [line.strip() for line in f if line.strip()]
            batches = [
                all_dirs[i:i + batch_size]
                for i in range(0, len(all_dirs), batch_size)
            ]

            sub_dict = {}
            generate_subject_dictionary(sub_dict, all_dirs)

            for i, group_dirs in enumerate(batches):
                with multiprocessing.Pool(min(batch_size, num_workers)) as pool:
                    pool.starmap(
                        process_image,
                        [
                            (image, 
                             sub_dict[image], 
                             File_filter, 
                             Path_mask, 
                             Output_path,
                             params_path
                             ) 
                             for image in group_dirs
                             ]
                    )
    