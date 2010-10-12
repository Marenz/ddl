module xf.linker.testLazy;

private {
	import common;
	import xf.linker.DefaultLinker;
	import xf.linker.FileUtils : fileModifiedTime;
	import xf.omg.core.LinearAlgebra;
	import xf.dog.Dog;

	import tango.io.Stdout;
	import tango.core.Memory;
}



const vec2i windowSize = {x:640, y:480};
const vec2i textureSize = {x:128, y:128};


Plugin loadPlugin(DynamicLibrary dynamicLib) {
	Plugin plugin;
	foreach (cl; dynamicLib.getSubclasses!(Plugin)) {
		Stdout.formatln("trying to create an instance of plugin: ", cl.name);
		if (!cl.isAbstract) {
			plugin = cl.newObject(windowSize.x, windowSize.y, textureSize.x, textureSize.y);
			Stdout.formatln("created a new plugin instance: {}", (cast(Object)plugin).classinfo.name);
			break;
		} else {
			Stdout.formatln("skipping abstract plugin: {}", cl.name);
		}
	}
	return plugin;
}


void main() {
	auto					linker = createDefaultLinker(`testLazy.link`);
	DynamicLibrary	dynamicLib;
	Plugin				plugin;
	
	scope context = GLWindow();
	context
		.title(`OMG Demo`)
		.width(windowSize.x)
		.height(windowSize.y)
	.create();	

	void loadPlugin() {
		dynamicLib = linker.load("plugin.d", "plugin");
		plugin = .loadPlugin(dynamicLib);	
		assert (plugin !is null);
		dynamicLib.makePrivate();
		use(context) in &plugin.init;
	}

	loadPlugin;
	
	ulong lastFileMod = fileModifiedTime(`plugin/plugin.d`);
	while (context.created) {
		ulong curFileMod = lastFileMod;
		try curFileMod = fileModifiedTime(`plugin/plugin.d`); catch {}
		
		if (curFileMod != lastFileMod) {
			lastFileMod = curFileMod;
			
			use(context) in (GL gl) {
				plugin.cleanup(gl);
			};
			//delete plugin;
			linker.unload("plugin.d");
			//dynamicLib.unload;
			plugin = null;
			dynamicLib = null;
			
			GC.collect();		// if shit happens, detect it early
			
			loadPlugin;
		} else {		
			use(context) in (GL gl) {
				plugin.draw(gl);
			};
			
			context.update.show();
		}
	}
	
	Stdout.formatln("Exiting");
}
