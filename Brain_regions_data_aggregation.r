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
