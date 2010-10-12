module xf.linker.provider.D;

private {
	import ddl.DynamicLibrary;
	import xf.linker.TextUtils;
	import xf.linker.FileUtils;
	import xf.linker.DepScan;
	import xf.linker.Provider;
	import xf.linker.LibraryCommon;
	import xf.linker.Compiler;
	import xf.linker.ProcessUtils;
	import Path = tango.io.Path;
	import tango.io.FilePath : FilePath;
	import tango.io.device.File : File;
	import tango.util.log.Trace;
	import tango.text.Util : textJoin = join, splitLines;
}



class DProvider : Provider {
	override DynamicLibrary getLib(LinkerSettings ls, LibLoadOptions opts, char[] path, void delegate(char[]) depIter) {
		auto root = getSource(ls.appRoot, opts.root);
		auto fullPath = getSource(root, path);
		
		BudSettings bs;
		bs.dmdPath = getSource(ls.appRoot, "bin");
		bs.paths = opts.includes;
		bs.exclusions = ["tango", "std"];
		
		auto depPath = getSource(ls.appRoot, getSource(depCacheDir, (toCacheName(getSource(opts.root, path), ".dep"))));
		
		// TODO: make this configurable
		//assert (FilePath(fullPath).exists, fullPath);
		
		
		if (/++/FilePath(fullPath).exists && /++/(!FilePath(depPath).exists || fileModifiedTime(depPath) < fileModifiedTime(fullPath))) {
			char[][] depsToSave;
			
			findDependencies(root, path, bs, false, (char[] mod, char[] dep) {
				if (Path.parse(dep).isAbsolute) {
					dep = dep.getSourceRelativeFrom(root);
				}
				if (dep.endsWith(".di")) {
					return;
				}
				
				dep = dep.dup;
				depsToSave ~= dep;
				version (LinkerSpam) Trace.formatln("{} -> {} ({})", mod, dep, getSource(root, dep));
				depIter(dep);
			});
			
			FilePath(FilePath(depPath).folder).create;
			File.set(depPath, cast(char[])depsToSave.textJoin("\n"));
		} else {
			foreach (dep; splitLines(cast(char[])File.get(depPath))) {
				if (dep.length > 0) {
					version (LinkerSpam) Trace.formatln("{} -> {} ({})", "<cached>", dep, getSource(root, dep));
					depIter(dep);
				}
			}
		}
		
		return compileModule(ls, opts, depIter, root, path, toCacheName(getSource(opts.root, path), ".obj"));
	}
	
	
	DynamicLibrary compileModule(
			LinkerSettings ls, LibLoadOptions opts, void delegate(char[]) depIter,
			char[] root, char[] path, char[] objName
	) {
		char[] appRelObjPath = getSource(objCacheDir, objName);
		char[] objPath = getSource(ls.appRoot, appRelObjPath);
		char[] srcPath = getSource(root, path);

		this.compiler.options.importPaths = opts.includes;
		this.compiler.dmdPath = getSource(ls.appRoot, "bin");
		
		auto srcFilePath = FilePath(srcPath);
		auto objFilePath = FilePath(getSource(ls.appRoot, appRelObjPath));

		// TODO: make this configurable
		//assert (srcFilePath.exists);
		
		ulong objModified;
		ulong srcModified;
		
		if (/++/srcFilePath.exists && /++/
			(!objFilePath.exists || (objModified = fileModifiedTime(objFilePath.toString)) < (srcModified = fileModifiedTime(srcPath)))
		) {
			/+version (LinkerSpam) +/Trace.formatln("Compiling '{}'", srcPath);
			compiler.compile(root, path, objPath);
		} else {
			version (LinkerSpam) Trace.formatln(".obj file ({}) up to date (src: {}), skipping compilation (obj: {}  src: {})", objFilePath.toString, srcPath, objModified, srcModified);
		}
		
		finishCommands;
		if (!objFilePath.exists) {
			Trace.formatln("Compilation failed for {}", srcPath);
			return null;
		}
		
		auto prov = registry.getProvider(objPath);
		assert (prov !is this);
		if (prov is null) {
			return null;
		} else {
			return prov.getLib(ls, LibLoadOptions.init, appRelObjPath, depIter);
		}
	}
	
	
	protected char[] toCacheName(char[] path, char[] ext) {
		path = path.dup;
		path = Path.replace(path, '.', '_');
		path = Path.replace(path, '/', '!');
		path ~= ext;
		return path;
	}
	
	
	override bool canProvideLib(char[] path) {
		return path.endsWith(".d");
	}
	
	
	override char[] providerName() {
		return "d";
	}
	
	
	this() {
		this.compiler = new Compiler;
	}
	
	
	const char[]	objCacheDir	= "_objCache";
	const char[]	depCacheDir	= "_depCache";
	Compiler		compiler;
}
