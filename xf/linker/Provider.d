module xf.linker.Provider;

private {
	import ddl.DynamicLibrary;
	import xf.linker.LibraryCommon;
}



abstract class Provider {
	abstract DynamicLibrary	getLib(LinkerSettings ls, LibLoadOptions opts, char[] path, void delegate(char[]) depIter);
	abstract bool					canProvideLib(char[] path);
	abstract char[]				providerName();
	
	
	DynamicLibrary getLib(LinkerSettings ls, char[] path, void delegate(char[]) depIter) {
		return getLib(ls, LibLoadOptions("."), path, depIter);
	}
	
	
	protected {
		ProviderRegistry registry;
	}
}



class ProviderRegistry {
	Provider[]	providers;
	
	
	void register(Provider p) {
		providers ~= p;
		p.registry = this;
	}
	
	
	Provider getProvider(char[] path) {
		foreach (p; providers) {
			if (p.canProvideLib(path)) {
				return p;
			}
		}
		
		return null;
	}
}
