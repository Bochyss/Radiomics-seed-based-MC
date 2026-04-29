import nibabel as nib
from scipy.stats import pearsonr
import os
import numpy as np

from brainsmash.workbench.geo import volume
from brainsmash.mapgen.eval import sampled_fit
from brainsmash.mapgen.sampled import Sampled

mc_file = '/path/to/mean_mc.nii'
fc_file = '/path/to/mean_fc.nii'

mc_data = nib.load(mc_file).get_fdata()
fc_data = nib.load(fc_file).get_fdata()

mask_file = '/path/to/mask.nii'
mask_data = nib.load(mask_file).get_fdata()

mc_masked = mc_data[mask_data > 0]
fc_masked = fc_data[mask_data > 0]

pearson_r, pearson_p_value = pearsonr(mc_masked, fc_masked)
print(f'Pearson correlation under the mask: {pearson_r:.3f}, and p value: {pearson_p_value:.3f}.')

coord_file = "/path/to/voxel_coordinates.txt"
output_dir = "/some/directory/"
os.makedirs(output_dir, exist_ok=True)

filenames = volume(coord_file, output_dir)

brain_map = "/some_path_to/brain_map.txt"

# These are three of the key parameters affecting the variogram fit
kwargs = {'ns': 500,
          'knn': 1000,
          'pv': 70
          }

# Running this command will generate a matplotlib figure
sampled_fit(brain_map, filenames['D'], filenames['index'], nsurr=10, **kwargs)

gen = Sampled(x=brain_map, D=filenames['D'], index=filenames['index'], **kwargs)
surrogate_maps = gen(n=10000)

# Computing the correlation between surrogate maps and FC
surrogate_corrs = []
for surrogate_map in surrogate_maps:
    corr, _ = pearsonr(fc_masked, surrogate_map)
    surrogate_corrs.append(corr)

# Computing the p value
p_value = np.sum(np.abs(surrogate_corrs) >= abs(pearson_r)) / len(surrogate_corrs)
print(f"p value: {p_value}")