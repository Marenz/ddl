module xf.linker.provider.Obj;

private {
	import xf.linker.Provider;
	import xf.linker.TextUtils;
	import xf.linker.LibraryCommon;
	import ddl.DynamicLibrary;
	import ddl.DefaultRegistry;
	import ddl.LoaderRegistry;
	
	import tango.util.log.Trace;
}



class ObjProvider : Provider {
	this() {
		loaderRegistry = new DefaultRegistry;
	}
	
	
	override DynamicLibrary getLib(LinkerSettings ls, LibLoadOptions opts, char[] path, void delegate(char[]) depIter) {
		char[] src = getSource(opts.root, path);
		version (LinkerSpam) Trace.formatln("Loading lib from '{}'", src);
		auto res = loaderRegistry.load(src, "");
		if (res !is null) {
			version (LinkerSpam) Trace.formatln("Lib loaded");
		} else {
			version (LinkerSpam) Trace.formatln("Lib not loaded. Got null.");
		}
		return res;
	}
	

	override bool canProvideLib(char[] path) {
		return path.endsWith(".obj") || path.endsWith(".lib") || path.endsWith(".map");
	}


	override char[] providerName() {
		return "obj";
	}

	
	LoaderRegistry	loaderRegistry;
}
