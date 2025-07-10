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
