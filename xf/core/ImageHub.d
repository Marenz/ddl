module xf.core.ImageHub;

private {
	import xf.image.Loader;
	import xf.image.CachedLoader;
	import xf.image.DevilLoader;
}

public import xf.image.Image;

static this() {
	ImageHub.imageHub=new ImageHub;
	ImageHub.imageHub.initialize;
}

class ImageHub {
	private static ImageHub imageHub;
	private Loader	imageLoader;
	
	static Loader opCall() {
		return imageHub.imageLoader;
	}
	
	private void initialize() {
		imageLoader = new CachedLoader(new DevilLoader);
	}
}