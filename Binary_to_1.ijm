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
