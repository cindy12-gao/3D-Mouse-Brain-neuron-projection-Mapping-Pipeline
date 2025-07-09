# 3D Mouse Brain neuron projection Mapping Pipeline

This repository contains a pipeline for processing and analyzing neuron projection of 3D mouse brain or half brain, including signal extraction, registration, and quantitative analysis.

## Pipeline Overview

1. **Initial Processing (Imaris)**
   - Crop images to remove non-brain regions
   - Downsample in Imaris (resample to X=5000 pixels while maintaining X/Y ratio)

2. **Blood Vessel Removal (for iDISCO+ Samples with Blood-vessel Noise) (Imaris)**
   1. Pre-processing:
      - Threshold cutoff (~5000)
      - Gaussian Filter
      - Median Filter (5×5×5)
      - Baseline subtraction (~3000)
   2. Create surface to cover blood vessels
   3. Apply mask (set interior values to 0) to raw signal channel
      
3. **Mirror and Stitch (for Half-brain Samples) (Imaris and Imaris Stitcher)**
   1. Free rotate and align the half brain
   2. Crop along the midline of the brain
   3. Flip it over, and stitch it with the half brain before flipping

4. **Orientation Adjustment (Imaris)**
   - Free rotate to coronal direction

5. **Reference Channel Enhancement (Optionally) (Imaris)**
   - Pre-process reference channel (folder C0) with:
     - Median filter
     - Threshold cutoff
     - Histogram equalization (using surface tool)

6. **File Export (Imaris)**
   - Save as TIFF
   - For multi-channel exports: separate each channel into individual folders
     - Folder C0: Raw signal channel
     - Folder C1: Reference channel

7. **Pixel Classifier Training (Qupath)**
   1. Import 3 images from each sample of the same group into QuPath
   2. Train pixel classifier with:
      - Classifier: Random trees
      - Resolution: full
      - Features:
        - Scales: 0.5
        - Gaussian and Laplacian of Gaussian
        - Local normalization (local mean subtraction only, scale 5)
   3. Save classifier file
      - Demo files: `"./Demo/Qupath_demo/pixel_classifiers"`

8. **Signal Prediction (Qupath)**
   - Import raw signal channel TIFFs into QuPath project (~5k images)
     - Demo files: `"./Demo/Qupath_demo/C0"` (1320 images)
   - Load trained pixel classifier
     - Demo: put the classifier folder `./Demo/Qupath_demo/pixel_classifiers` into the `classifiers` folder of the qupath project folder
   - Save predicted binary images (16-bit, ~2 days/whole brain; recommended: running 2 to 3 QuPath programs simultaneously)
  ```groovy
  // Get current image data
def imageData = getCurrentImageData()
def server = imageData.getServer()
def filename = server.getMetadata().getName()

// Load the trained pixel classifier
def classifier = loadPixelClassifier('trained pixel classifier')

// Create prediction server
def predictionServer = PixelClassifierTools.createPixelClassificationServer(imageData, classifier)

// Set output directory
def outputDir = buildFilePath(OUTPUT_DIR, 'export')
mkdirs(outputDir)

// Set output file path
def outputPath = buildFilePath(outputDir, filename.replace('.tif', '_prediction_16bit.tif'))

// Set downsampling ratio (1.0 means no downsampling)
double downsample = 1.0

// Create region request
def request = RegionRequest.createInstance(predictionServer, downsample)

// Get prediction result as BufferedImage
def img = predictionServer.readBufferedImage(request)

// Convert prediction result to 16-bit
def width = img.getWidth()
def height = img.getHeight()
def newImg = new BufferedImage(width, height, BufferedImage.TYPE_USHORT_GRAY)

for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
        int value = img.getRaster().getSample(x, y, 0) // Get pixel value
        int newValue = value * 256                     // Map 8-bit to 16-bit
        newImg.getRaster().setSample(x, y, 0, newValue)
    }
}

// Save as 16-bit image
writeImage(newImg, outputPath)

print "Prediction result saved as 16-bit: " + outputPath
```


8. **Signal Extraction (ImageJ)**
   - Convert binary images to 0/1 values (divide by 256)
     ```javascript
     // ImageJ Macro
     inputDir = INPUT_DIR;
     outputDir = OUTPUT_DIR;
     setBatchMode(true);
     list = getFileList(inputDir);
     for (i=0; i<list.length; i++) {
     open(inputDir + list[i]);
     run("Divide...", "value=256");
     saveAs("Tiff", outputDir + list[i]);
     close();
     }
     setBatchMode(false);
     ```

   - Multiply raw images with binary images to extract pure signal (binary_signal channel) using Image Calculator
   - *Note:* Recommends workstation with ≥360GB RAM (depends on dataset size)

9. **Registration (Brainglobe)**
   1. Download atlas
   ```
   brainglobe install -a allen-mouse_10um
   ```
   2. Register using:
      - Binary-signal channel as channel_0
        - Demo files: `./Demo/Qupath_demo/Binary_signal`
      - Raw signal channel as channel_1 (optionally)
        - Demo files: `./Demo/Qupath_demo/C1`
      - Reference channel as background
        - Demo files: `./Demo/Qupath_demo/C0`
     ```python
   brainmapper -s PATH_to_Binary_signal_channel PATH_to_Raw_signal_channel_C0 -b PATH_to_Reference_channel_C1 -o PATH_to_output_directory -v 1 1 1 --orientation asr --atlas allen_mouse_10um --no-detection
     ```
      - Atlas: allen_mouse_10um
      - Voxel size: `-v`
        - If the voxel size of your data is `1x2x3` (XYZ), use `3 2 1` (ZYX)
      - Orientation: `--orientation`
        - In coronal section, if your data start from olfactory bulb with dorsal up, use `asr`
        - In coronal section, if your data start from olfactory bulb with ventral up, use `ail`
        - In coronal section, if your data start from cerebellum with dorsal up, use `psl`
        - In coronal section, if your data start from cerebellum with ventral up, use `pir`
     

   3. Output files:
  ```bash
/Registration/
├── downsampled_standard_channel_0.tiff  # Registered binary_signal channel
└── downsampled_standard_channel_1.tiff  # Registered raw signal channel (optionally)
```
   5. Locate atlas files in Brainglobe environment or find the files in `./Demo/MATLAB_files`
      - Path: `C:/User/.brainglobe/allen_mouse_10um_v1.2`
      - Files: `annotation.tiff` and `structure.csv`
      - Copy to MATLAB working directory

11. **Distance Map Creation for Radial Signal Profiling (ImageJ)**
    1. Open `annotation.tiff` (~4.5GB)
    2. Apply logarithmic intensity scaling
    3. Convert to 16-bit
    4. Threshold (select all regions >1)
    5. Fill holes
    6. Create distance map of standard brain
       - `Distance_map.tif`

12. **Quantification Analysis (MATLAB)**
    1. Run script: `./Demo/Script/Sum_of_Brain_Regions_and_distance_map.m`
    2. Input files:
       - Atlas: `annotation.tiff`
       - Binary_signal channel data: `downsampled_standard_channel_0.tiff`
       - Distance map: `Distance_map.tif`
       - `structure.csv` (automatically read from current folder)
    3. Output files:
       - `output_atlas.xlsx` //Quantification of signal intensity and signal density in annotated brain regions (unfinished)
       - `output_distance_map.xlsx` //Radial signal profiling results

12. **Quantification data aggregation (R studio)**
    - Input `output_atlas.xlsx` file and aggregate quantification data in brain regions by structure_id_path
  ```r
#r
library(dplyr)
library(readr)
library(tidyr)
library(readxl)

#Load Allen CCFv3 structure tree file
CCFv3_tree <- read_csv("./Demo/R_demo/Allen_CCFv3_structure_tree.csv") 


# Specify the full path to the folder containing the output files
folder_path <- "./Demo/R_demo/Example/MATLAB_output_sum"

# List all .xlsx files in the folder (the MATLAB output files "output_atlas.xlsx")
xlsx_files <- list.files(path = folder_path, pattern = "\\.xlsx$", full.names = TRUE)

# Read all .xlsx files into a list of data frames
data_list <- lapply(xlsx_files, read_excel)

# Combine the data frames by "atlas_area" columns
combined_data<- Reduce(function(x, y) merge(x, y, by = "atlas_area", all = TRUE), data_list)

# reframe the data
reframed_combined_data <- combined_data %>%
  reframe(acronym = atlas_area,
          volume = volume,
          mean_intensity_signal = mean_intensity_signal,
          signal_density = density_signal)

LINCS_tree <- reframed_combined_data %>%
  left_join(CCFv3_tree %>% select(id, name, acronym, st_level, depth, parent_structure_id, structure_id_path), by = "acronym")

# Merge Allen CCFv3 structure tree with LINCS_tree
merged_data <- CCFv3_tree %>%
  left_join(LINCS_tree, by = "id")

# Parse structure_id_path
merged_data <- merged_data %>%
  mutate(level_ids = strsplit(structure_id_path.x, "/")) %>%
  unnest(level_ids) %>%
  filter(level_ids != "") %>%
  group_by(id) %>%
  mutate(level = row_number()) %>%
  ungroup()

# Aggregate data at each level
aggregated_data <- merged_data %>%
  group_by(level_ids) %>%
  summarize(total_volume = sum(volume, na.rm = TRUE),
            mean_intensity_signal = mean(mean_intensity_signal, na.rm = TRUE),
            signal_density = mean(signal_density, na.rm = TRUE)) %>%
  ungroup()

# Map level_ids to region names
CCFv3_tree$id <- as.character(CCFv3_tree$id)
aggregated_data2 <- aggregated_data %>%
  left_join(CCFv3_tree %>% select(id, name, acronym, st_level, depth, parent_structure_id, structure_id_path), by = c("level_ids" = "id"))

# Remove rows where vomume are NA
cleaned_data <- aggregated_data2 %>% filter(total_volume != 0)

# Export results
write.csv(cleaned_data, "summary_tree_aggregated.csv", row.names = FALSE)
```

## Requirements

- Imaris (v10.1.0)
- Imaris Stitcher (v10.1.0)
- QuPath (v0.5.1)
- ImageJ (v1.54f)
- Python (v3.10.15)
- Brainglobe (v1.3.1)
- MATLAB (R2020a)
- R (v4.4.2)
- RStudio (v2024.12.1)
- High-performance workstation (≥360GB RAM recommended)

## Notes

- Processing times vary significantly by dataset size
- The binary image multiplication step is particularly memory-intensive
- Atlas files must be properly located for registration and analysis

## References
- [Brainglobe Documentation](https://brainglobe.info)
- [QuPath Pixel Classification](https://qupath.readthedocs.io/en/0.5/docs/tutorials/pixel_classification.html#pixel-classification)

