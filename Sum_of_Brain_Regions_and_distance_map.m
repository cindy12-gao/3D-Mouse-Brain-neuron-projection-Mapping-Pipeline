clear all
clc

%% 1. Read atlas data annotation.tiff
[fileNameAtlas, filePathAtlas] = uigetfile('.tif', 'Select Atlas File');
if isequal(fileNameAtlas, 0)
    error('No atlas file selected.');
end
atlasInfo = imfinfo([filePathAtlas fileNameAtlas]);
mAtlas = atlasInfo(1).Height;
nAtlas = atlasInfo(1).Width;
numberAtlas = length(atlasInfo);

atlas = zeros(mAtlas, nAtlas, numberAtlas, 'uint32'); % Assume 32-bit atlas image
h = waitbar(0, 'Loading Atlas...');
for i = 1:numberAtlas
    atlas(:, :, i) = imread([filePathAtlas fileNameAtlas], i);
    if ~rem(i, 20)
        waitbar(i / numberAtlas);
    end
end
close(h);

%% 2. Read binary_signal channel data (pure signal, without background)
[fileNameSignal, filePathSignal] = uigetfile('.tif', 'Select Binary Signal File');
if isequal(fileNameSignal, 0)
    error('No binary signal file selected.');
end
infoSignal = imfinfo([filePathSignal fileNameSignal]);
mSignal = infoSignal(1).Height;
nSignal = infoSignal(1).Width;
numberSignal = length(infoSignal);
bitDepthSignal = infoSignal(1).BitDepth;

% Initialize main data variable
signal_pure = zeros(mSignal, nSignal, numberSignal, 'double');

if bitDepthSignal == 24
    % RGB image
    signal_pure = zeros(mSignal, nSignal, 3, numberSignal, 'uint8');
    h = waitbar(0, 'Loading Binary Signal...');
    for i = 1:numberSignal
        signal_pure(:, :, :, i) = imread([filePathSignal fileNameSignal], i);
        if ~rem(i, 20)
            waitbar(i / numberSignal);
        end
    end
    % Extract only green channel
    signal_pure = reshape(signal_pure(:, :, 2, :), mSignal, nSignal, numberSignal);
    close(h);
else
    % Grayscale image
    h = waitbar(0, 'Loading Binary Signal...');
    for i = 1:numberSignal
        signal_pure(:, :, i) = imread([filePathSignal fileNameSignal], i);
        if ~rem(i, 20)
            waitbar(i / numberSignal);
        end
    end
    close(h);
end

%% 3. Read distance map data
[fileNameDistance, filePathDistance] = uigetfile('.tif', 'Select Distance Map File');
if isequal(fileNameDistance, 0)
    error('No distance map file selected.');
end
distanceInfo = imfinfo([filePathDistance fileNameDistance]);
mDistance = distanceInfo(1).Height;
nDistance = distanceInfo(1).Width;
numberDistance = length(distanceInfo);

distance_map = zeros(mDistance, nDistance, numberDistance, 'uint16'); % Assume 16-bit distance map
h = waitbar(0, 'Loading Distance Map...');
for i = 1:numberDistance
    distance_map(:, :, i) = imread([filePathDistance fileNameDistance], i);
    if ~rem(i, 20)
        waitbar(i / numberDistance);
    end
end
close(h);

%% 4. Process brain regions based on atlas
structures = readtable('structures.csv'); % Assume structures table is CSV file
structruesID = table2array(structures(:, 2));
structruesName = table2array(structures(:, 1));
structruesNumber = length(structruesID);

% Initialize variables
binary_tempt = zeros(size(atlas)); % Store binarized data for current region
Intensity_tempt = zeros(size(atlas));
volume = zeros(structruesNumber, 1); % Volume of each brain region
density_signal = zeros(structruesNumber, 1); % Signal density of each region
mean_intensity_signal = zeros(structruesNumber, 1); % Mean signal intensity of each region

for i = 1:structruesNumber
    ID = structruesID(i); % Current region ID
    currentArea = find(atlas == ID); % Get voxel positions for current region
    if ~any(currentArea) % Skip if region is empty
        continue;
    end

    % Process binarized data and signal intensity
    binary_tempt(:) = 0; % Reset binarized data
    Intensity_tempt(:) = 0; % Reset intensity data
    binary_tempt(currentArea) = 1; % Mark current region
    Intensity_tempt(currentArea) = signal_pure(currentArea); % Extract region's signal intensity

    % Calculate statistics
    volume(i) = length(currentArea); % Region volume
    
    % Signal density (percentage of non-zero voxels)
    density_signal(i) = length(find(Intensity_tempt>0)) / volume(i); 
    
    % Calculate mean signal intensity (excluding zero values)
    sum_signal = sum(Intensity_tempt(:)); % Total signal intensity
    nonzero_voxels = length(find(Intensity_tempt > 0)); % Count of non-zero voxels
    if nonzero_voxels > 0
        mean_intensity_signal(i) = sum_signal / nonzero_voxels;
    else
        mean_intensity_signal(i) = 0; % Set to 0 if no signal
    end
end

% Extract valid regions (with volume > 0)
valid_IDnumber = find(volume > 0); 

% Organize output data
NAME = structruesName(valid_IDnumber); % Region names
VOLUME = volume(valid_IDnumber); % Volumes
DENSITY = density_signal(valid_IDnumber); % Signal densities
MEAN_INTENSITY = mean_intensity_signal(valid_IDnumber); % Mean intensities

% Create output table
outputTable = table(NAME, VOLUME, DENSITY, MEAN_INTENSITY, ...
    'VariableNames', {'atlas_area', 'volume', 'density_signal', 'mean_intensity_signal'});

% Write to Excel file
outputFileName = 'output_standard—filter2_190313.xlsx'; 
writetable(outputTable, outputFileName); 
disp(['Brain region results saved to ' outputFileName]);

%% 5. Process depth data based on distance map
startValue = 1;   % Start value
endValue = 255;   % End value
numSteps = 25;    % Number of depth bins
stepValues = linspace(startValue, endValue, numSteps);

% Initialize variables
volume_distance = zeros(numSteps-1, 1); % Volume per depth bin
density_signal_distance = zeros(numSteps-1, 1); % Signal density per depth bin
mean_intensity_signal_distance = zeros(numSteps-1, 1); % Mean intensity per depth bin

for i = 1:length(stepValues)-1
    % Create depth mask for current bin
    depth_mask = (distance_map > stepValues(i)) & (distance_map <= stepValues(i+1));
    
    % Extract signal data in current depth bin
    signal_depth = signal_pure(depth_mask); 

    % Calculate volume and signal density
    volume_distance(i) = nnz(depth_mask); % Number of voxels in bin
    density_signal_distance(i) = nnz(signal_depth) / volume_distance(i); % Signal density

    % Calculate mean signal intensity (excluding zero values)
    non_zero_signals = signal_depth(signal_depth > 0);
    if ~isempty(non_zero_signals)
        mean_intensity_signal_distance(i) = mean(non_zero_signals);
    else
        mean_intensity_signal_distance(i) = 0; % Set to 0 if no signal
    end
end

% Create depth range labels
depth_ranges = cell(numSteps-1, 1);
for i = 1:length(stepValues)-1
    depth_ranges{i} = sprintf('%d-%d', stepValues(i), stepValues(i+1));
end

% Create output table for depth data
outputTable_distance = table(depth_ranges, volume_distance, density_signal_distance, ...
    mean_intensity_signal_distance, ...
    'VariableNames', {'Depth_Range', 'Volume', 'Density', 'Mean_Intensity'});

% Write to Excel file
distanceOutputFile = 'output_distance_map-edit.xlsx';
writetable(outputTable_distance, distanceOutputFile);
disp(['Distance map results saved to ' distanceOutputFile]);