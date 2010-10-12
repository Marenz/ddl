module xf.linker.model.ILazyLinker;

public {
	import ddl.DynamicLibrary : DynamicLibrary;
}
private {
	import xf.linker.LibraryCommon;
	import xf.linker.Provider : ProviderRegistry;
}




interface ILazyLinker {
	void verifyLinkedModules();
	DynamicLibrary load(char[] source, char[] libRoot);
	DynamicLibrary load(char[] source, LibLoadOptions opts = LibLoadOptions.init);
	LibraryType getLibraryType(DynamicLibrary lib);
	void parseConfigLine(char[] line);
	void parseConfig(char[] cfg);
	void parseConfigFile(char[] path);
	void unload(char[] source);
	LibrarySource getSource(LibrarySource libRoot, LibrarySource libPath);
	LibrarySource[] getStdIncludes(LibrarySource libRel);
	ProviderRegistry providerRegistry();
}


class LibraryLoadingException : Exception {
	this(char[] msg) {
		super(msg);
	}
}
