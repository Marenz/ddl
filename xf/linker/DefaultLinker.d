module xf.linker.DefaultLinker;

private {
	import xf.core.Registry;
	
	import xf.linker.model.ILazyLinker;
	import xf.linker.Provider;
	
	import xf.linker.provider.Obj;
	import xf.linker.provider.D;
	
	import xf.linker.Compiler;
}
public {
	import ddl.DynamicLibrary : DynamicLibrary;
}

alias xf.linker.model.ILazyLinker.LibLoadOptions LibLoadOptions;



ILazyLinker createDefaultLinker(char[] cfgFile = null, void delegate(Compiler) compilerCfg = null) {
	auto linker = create!(ILazyLinker)();
	if (cfgFile !is null) {
		linker.parseConfigFile(cfgFile);
	}	
	with (linker.providerRegistry) {
		register(new ObjProvider);
		auto dprov = new DProvider;
		if (compilerCfg) {
			compilerCfg(dprov.compiler);
		}
		register(dprov);
	}
	return linker;
}


ILazyLinker createDefaultLinkerCfgString(char[] cfg, void delegate(Compiler) compilerCfg = null) {
	auto linker = create!(ILazyLinker)();
	linker.parseConfig(cfg);
	with (linker.providerRegistry) {
		register(new ObjProvider);
		auto dprov = new DProvider;
		if (compilerCfg) {
			compilerCfg(dprov.compiler);
		}
		register(dprov);
	}
	return linker;
}
