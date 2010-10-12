module xf.linker.LazyLinker;

public {
	import xf.linker.model.ILazyLinker;
}
private {
	import xf.core.Registry;
	import xf.linker.Provider;
	import xf.linker.LibraryCommon;
	import xf.linker.ConfigUtils;
	debug import ddl.Utils;
	import ddl.DynamicModule;
	import ddl.ExportSymbol;
	import ddl.Attributes;
	import ddl.DDLException;
	import tango.text.convert.Format : Format;
	import tango.text.Util : splitLines, trim;
	import Path = tango.io.Path;
	import tango.io.FileSystem : FileSystem;
	import tango.io.device.File : FileConduit = File;
	import tango.io.stream.Lines : LineIterator = Lines;
	import tango.sys.Environment;
	
	import tango.util.log.Trace;

	// the Tango HashMap doesn't seem to lose references so nicely :o
	version = LazyLinkerBuiltinContainers;

	version (LazyLinkerBuiltinContainers) {
	} else {
		import tango.util.container.HashMap;
		import tango.util.container.Container;
	}
}

alias xf.linker.LibraryCommon.LibLoadOptions LibLoadOptions;




struct ModuleSetItem {
	DynamicModule	mod;
	ModuleInfo		moduleInfo;
}


struct ModuleSet {
	ModuleSetItem[]	items;
	byte[char[]]			symbols;
}


class LinkGroup {
	DynamicLibrary[]	libs;
	
	char[] toString() {
		char[] res;
		foreach (l; libs) {
			if (auto lazyLib = cast(LazyLibrary)l) {
				res ~= lazyLib.source ~ " ";
			} else {
				foreach (mod; l.getModules) {
					res ~= mod.getName ~ " ";
				}
			}
		}
		return res;
	}
}


struct LibTypeSettings {
	LibraryType[][3]	linkOrder;
	LinkGroup				linkGroup;
	LinkGroup[char[]]	selfGroups;
	bool						replaceStrongSymbols = false;
}



version (TangoTrace3) extern(C) {
	typedef void* ModuleDebugInfo;
	ModuleDebugInfo ModuleDebugInfo_new();
	void ModuleDebugInfo_addDebugInfo(ModuleDebugInfo minfo, size_t addr, char* file, char* func, ushort line);
	char* ModuleDebugInfo_bufferString(ModuleDebugInfo minfo, char[] str);
	void GlobalDebugInfo_addDebugInfo(ModuleDebugInfo minfo);
	void GlobalDebugInfo_removeDebugInfo(ModuleDebugInfo minfo);
}


	class LinkingContext {
		void scheduleLinking(DynamicModule mod, LinkGroup[][] linkOrder) {
			if (mod.isResolved) {
				return;
			}
			
			if (!(mod in schedSet)) {
				scheduled ~= SchedItem(mod, linkOrder);
				schedSet[mod] = scheduled.length - 1;
			}
		}
		
		bool isScheduled(DynamicModule mod) {
			return (mod in schedSet) !is null;
		}
		
		struct SchedItem {
			DynamicModule	mod;
			LinkGroup[][]	linkOrder;
		}
		
		SchedItem[]				scheduled;
		int[DynamicModule]	schedSet;
		
		ModuleSet					moduleSet;
	}


class LazyLinker : ILazyLinker {
	mixin (Implements("ILazyLinker"));	
	mixin MModuleInitSupport;
	
	

	
	
	void verifyLinkedModules() {
		int[void*][char[]] symCnts;
		
		foreach (mod, libType; moduleType) {
			if (!mod.isLinking) {
				continue;
			}
			
			foreach (ref sym; mod.getSymbols) {
				assert (sym.isLinked);
				++symCnts[sym.name][sym.address];
			}
		}
		
		bool bork = false;
		foreach (sym, grp; symCnts) {
			int cnt = grp.keys.length;
			if (cnt > 1) {
				bork = true;
				version (LinkerSpam) Trace.formatln("{} sources for {} : {}", cnt, sym, grp.keys);
			}
		}
		if (bork) assert (false);
	}
	

	DynamicLibrary load(char[] source, char[] libRoot) {
		LibLoadOptions opts;
		opts.root = libRoot;
		return load(source, opts);
	}

	
	DynamicLibrary load(char[] source, LibLoadOptions opts = LibLoadOptions.init) {
		if (auto lib = source in allLibraries) {
			return *lib;
		} else {
			opts.includes ~= getStdIncludes(opts.root);

			auto lib = new LazyLibrary;
			allLibraries[source] = lib;
			lib.linker = this;
			lib.source = source;
			lib.options = opts;
			lib.type = getLibraryType(lib);
			
			version (LinkerSpam) Trace.formatln("library {} type: {}", lib.source, lib.type);
			version (LinkerSpam) Trace.formatln("library {} self-group: {}", lib.source, lib.options.root);
			
			auto ts = getLibTypeSettings(lib.type);
			ts.linkGroup.libs ~= lib;

			if (auto grp = lib.options.root in ts.selfGroups) {
				grp.libs ~= lib;
			} else {
				auto grp = new LinkGroup;
				grp.libs ~= lib;
				ts.selfGroups[lib.options.root] = grp;
			}
			
			lib.linkOrder = getLinkOrder(lib);
			
			return lib;
		}
	}
	
	
	LibTypeSettings* getLibTypeSettings(char[] type) {
		assert (type != "self");
		if (auto grp = type in libTypeSettings) {
			return grp;
		} else {
			libTypeSettings[type] = LibTypeSettings.init;
			auto res = type in libTypeSettings;
			res.linkGroup = new LinkGroup;
			return res;
		}
	}
	
	
	LibraryType getLibraryType(DynamicLibrary lib_) {
		if (auto lib = cast(LazyLibrary)lib_) {
			auto source = getSource(lib.options.root, lib.source);
			auto res = typeMatcher.matchType(source);
			//Trace.formatln("source {} -> type {}", source, res);
			return res;
		} else {
			throw new Exception("The supplied library was not loaded by LazyLinker");
		}
	}
	
	
	void parseConfigLine(char[] line) {
		line = line.dup;
		
		char[][] getWordList() {
			char[][] list;
			while (line.length > 0) {
				list ~= cutOffWord(&line);
			}
			return list;
		}
		
		char[] cmd = cutOffWord(&line);
		switch (cmd) {
			case "type":
				typeMatcher.parseConfigLine(line);
				break;
			case "order":
				LibraryType type = cutOffWord(&line);
				getLibTypeSettings(type).linkOrder[] = getWordList;
				break;
			case "order-unresolved":
				LibraryType type = cutOffWord(&line);
				getLibTypeSettings(type).linkOrder[SymbolType.Unresolved] = getWordList;
				break;
			case "order-weak":
				LibraryType type = cutOffWord(&line);
				getLibTypeSettings(type).linkOrder[SymbolType.Weak] = getWordList;
				break;
			case "order-strong":
				LibraryType type = cutOffWord(&line);
				getLibTypeSettings(type).linkOrder[SymbolType.Strong] = getWordList;
				break;
			case "replace-strong":
				auto kind = cutOffWord(&line);
				auto name = cutOffWord(&line);
				switch (kind) {
					case "type":
						getLibTypeSettings(name).replaceStrongSymbols = true;
						break;
				}
				break;
			case "load":
				auto source = cutOffWord(&line);
				auto root = cutOffWord(&line);
				version (LinkerSpam) Trace.formatln("load({}, {})", source, root);
				assert (0 == line.length);
				// TODO: includes
				this.load(source, LibLoadOptions(root));
				break;
			case "std-include":
				this.stdIncludes = getWordList;
				break;
			default:
				throw new Exception("Unknown LazyLinker config option: '" ~ cmd ~ "'");
		}
	}
	
	
	void parseConfig(char[] cfg) {
		foreach (line; splitLines(cfg)) {
			line = trim(line);
			if (line.length > 0) {
				parseConfigLine(line);
			}
		}
	}
	

	void parseConfigFile(char[] path) {
		scope conduit = new FileConduit(path, FileConduit.ReadExisting);
		foreach (line; new LineIterator!(char)(conduit)) {
			line = trim(line);
			if (line.length > 0) {
				parseConfigLine(line);
			}
		}
		conduit.close;
	}
	
	
	private T _aaRemove(T, X)(ref T aa, X key) {
		//T newAA;
		version (LazyLinkerBuiltinContainers) {
			aa.remove(key);
		} else {
			aa.removeKey(key);
		}
		/+foreach (k, v; aa) {
			assert (k !is key);
			newAA[k] = v;
		}
		return newAA;+/
		return aa;
	}
	
	
	void unload(char[] source) {
		if (auto lib_ = source in allLibraries) {
			auto lib = *lib_;
			assert (lib !is null);
			
			// remove the lib without changing lib order
			void remove(ref DynamicLibrary[] libs) {
				foreach (i, l; libs) {
					if (l is lib) {
						for (; i+1 < libs.length; ++i) {
							libs[i] = libs[i+1];
						}
						libs[$-1] = null;
						libs = libs[0..$-1];
						break;
					}
				}
			}
			
			foreach (t, ref lts; libTypeSettings) {
				remove(lts.linkGroup.libs);
				foreach (x, ref g; lts.selfGroups) {
					remove(g.libs);
				}
			}
			
			//allLibraries.remove(source);
			_aaRemove(allLibraries, source);
			
			foreach (mod; lib.getModules) {
				/+moduleLinkOrder.remove(mod);
				moduleType.remove(mod);+/
				_aaRemove(moduleLinkOrder, mod);
				_aaRemove(moduleType, mod);

				version (TangoTrace3) {
					auto mdi = dynamicModuleDebugInfo[mod];
					GlobalDebugInfo_removeDebugInfo(mdi);
					_aaRemove(dynamicModuleDebugInfo, mod);
				}
			}
		} else {
			throw new Exception("Library not loaded: '" ~ source ~ "'");
		}
	}

	
	protected void linkLazyLibrary(LazyLibrary lib) {
		assert (!insideLinkAll);
		
		findRealLibrary(lib);
		scope ctx = new LinkingContext;
		foreach (mod; lib.realLib.getModules) {
			ctx.scheduleLinking(mod, lib.linkOrder);
		}
		linkAll(ctx);
		lib.realLinked = true;
		replaceLazyLib(lib);
	}
	
	
	bool insideLinkAll = false;
	protected void linkAll(LinkingContext ctx) {
		assert (!insideLinkAll);
		
		insideLinkAll = true;
		scope (exit) insideLinkAll = false;
		
		for (int i = 0; i < ctx.scheduled.length; ++i) {
			auto item = ctx.scheduled[i];
			auto mod = item.mod;
			auto order = item.linkOrder;
			//Trace.formatln("linking module {}", mod.getName);
			link(ctx, mod, order);
		}
		Trace.formatln("running runModuleCtors");	
		runModuleCtors(ctx.moduleSet);
	}
	
	
	protected void selfResolve(DynamicModule mod) {
		if (mod.isResolved) return;
		
		foreach (ref sym; mod.getSymbols) {
			if (SymbolType.Weak == sym.type) {
				sym.type = SymbolType.Strong;
			} else if (SymbolType.Unresolved == sym.type) {
				char[] ext = sym.isExternal ? "external" : "local";
				char[] error = Format("cannot resolve symbol: [{0:X}] {1} {2} {3} in module {4}"\n, cast(uint)sym.address, sym.getTypeName(), ext, sym.name, mod.getName);
				throw new DDLException(error);
			}
		}
		
		mod.resolveFixups();
	}
	
	
	protected void replaceLazyLib(LazyLibrary lib) {
		assert (lib.realLib !is null && lib.realLinked);
		
		void replace(ref DynamicLibrary l) {
			if (l is lib) {
				l = lib.realLib;
			}
		}

		foreach (path, ref l; allLibraries) {
			replace(l);
		}
		
		auto settings = getLibTypeSettings(lib.type);
		foreach (ref l; settings.selfGroups[lib.options.root].libs) {
			replace(l);
		}
		foreach (ref l; settings.linkGroup.libs) {
			replace(l);
		}
	}
	
		
	protected void findRealLibrary(LazyLibrary lib) {
		if (lib.realLib !is null) {
			return;
		}
		
		auto fullSource = this.getSource(lib.options.root, lib.source);
		
		auto prov = _providerRegistry.getProvider(fullSource);
		if (prov is null) {
			throw new Exception(`No linking provider found for path: '` ~ fullSource ~ `'`);
		}
		
		auto realLib = prov.getLib(this.settings, lib.options, lib.source, (char[] src) {
			if (".." == src[0..2]) {
				LibLoadOptions opts;
				opts.root = ".";
				foreach (inc; lib.options.includes) {
					auto incPath = .getSource(lib.options.root, inc);
					if (incPath.length > 0) {
						opts.includes ~= incPath;
					}
				}
				//Trace.formatln("misc lib includes: {}", opts.includes);
				this.load(.getSource(lib.options.root, src), opts);
			} else {
				this.load(src, lib.options);
			}
		});
		
		if (realLib is null) {
			throw new LibraryLoadingException(Format(`Could not load library from root:'{}', path:'{}'`, lib.options.root, lib.source));
		}
		
		lib.realLib = realLib;

		foreach (mod; lib.realLib.getModules) {
			moduleLinkOrder[mod] = lib.linkOrder;
			moduleType[mod] = lib.type;
		}
		
		version (LinkerSpam) Trace.formatln("library {} loaded", lib.source);
	}
	
	
	protected void link(LinkingContext ctx, ExportSymbolPtr sym, DynamicModule mod, LinkGroup[][] linkOrder/+, bool canSelfResolve+/) {
		if (sym.isLinked || sym.isLinking) {
			return;
		}

		version (LinkerSpam) Trace.formatln("linking {} symbol {} from module {}({})", sym.getTypeName, sym.name, mod.getName, moduleType[mod]);
		version (LinkerSpam) Trace.formatln("link order for symbol: {}", linkOrder[sym.type]);
		
		if (SymbolType.Strong == sym.type/+ && !shouldReplaceStrongSymbols(mod)+/) {
			version (LinkerSpam) Trace.formatln("already strong");
			sym.isLinking = false;
			sym.isLinked = true;
			return;
		}
		
		/+if (canSelfResolve && sym.type != SymbolType.Unresolved) {
			Trace.formatln("self-resolving {} symbol {} from module {}", sym.getTypeName, sym.name, mod.getName);
			sym.isLinking = false;
			sym.isLinked = true;
			return;
		}+/
		
		sym.isLinking = true;
		scope (exit) {
			sym.isLinking = false;
			sym.isLinked = true;
/+			
			if (sym.type != SymbolType.Unresolved) {
				sym.type = SymbolType.Strong;
			}+/
		}
		
		foreach (linkGroup; linkOrder[sym.type]) {
			foreach (lib; linkGroup.libs) {
				//bool ownTypeFound = false;
				
				if (lazyGetSymbolFromLib(ctx, lib, sym.name, sym, (ref DynamicModule otherMod, ref ExportSymbol otherSym, bool otherModLinking) {
					version (LinkerSpam) Trace.formatln("\tsymbol found in module {}", otherMod.getName);
					
					/+if (sym.type > otherSym.type) {
						Trace.formatln("\tour sym is better!");
						return false;
					}
					
					if (sym.type >= otherSym.type && sym.type != SymbolType.Unresolved && !otherModLinking) {
						Trace.formatln("\tnot pulling another lib in");
						ownTypeFound = true;
						return false;
					}
					
					if (SymbolType.Strong == sym.type && moduleType[mod] is moduleType[otherMod]) {
						Trace.formatln("\tthe symbol is strong and we're not replacing it");
						ownTypeFound = true;
						return false;
					}+/

					if (shouldReplaceSymbol(mod, sym, otherMod, &otherSym)) {
						version (LinkerSpam) Trace.formatln("taking symbol {} from module {}({}) for module {}({}) ( {} -> {} )", sym.name, otherMod.getName, moduleType[otherMod], mod.getName, moduleType[mod], sym.getTypeName, otherSym.getTypeName);
						assert (!sym.isLinked);
						sym.address = otherSym.address;
						sym.type = otherSym.type;
						sym.isExternal = true;
						return true;
					}
					
					return false;		// we don't like the symbol, linking of the other lib is not requied
				})) {
					version (LinkerSpam) Trace.formatln("Happy with the symbol");
					return;				// symbol found
				}
				
				/+if (ownTypeFound) {
					Trace.formatln("Happy with the strong symbol");
					return;				// strong symbol, this one should not be replaced
				}+/
			}
		}
		
		version (LinkerSpam) Trace.formatln("Keeping the old symbol");
	}
	
	
	protected bool shouldReplaceSymbol(DynamicModule mod1, ExportSymbolPtr sym1, DynamicModule mod2, ExportSymbolPtr sym2) {
		return sym2.type != SymbolType.Unresolved && sym2.type >= sym1.type && (
			sym2.address !is null
			|| sym2.name == "__nullext"
			|| sym2.name == "__except_list"
		);
		
		/+if (sym2 is sym1 && sym1.type != SymbolType.Unresolved) {
			return true;
		}

		if (shouldReplaceStrongSymbols(mod1)) {
			return SymbolType.Strong == sym2.type || sym2.type > sym1.type;
		} else {
			return sym2.type > sym1.type;
		}+/
	}
	
	
	protected bool shouldReplaceStrongSymbols(DynamicModule mod) {
		return getLibTypeSettings(moduleType[mod]).replaceStrongSymbols;
	}
	
	
	protected void addModuleCtor(LinkingContext ctx, ExportSymbolPtr sym, DynamicModule mod) {
		// symbol must be defined and be local only
		if (sym.address is null || sym.isExternal) {
			return;
		}
		
		char[] suffix = `__ModuleInfoZ`;
		if (sym.name.length > suffix.length && sym.name[$ - suffix.length .. $] == suffix) {
			if (sym.name in ctx.moduleSet.symbols) {
				return;
			}
			
			auto order = moduleLinkOrder[mod];
			groupIter: foreach (group; order[sym.type]) {
				foreach (lib; group.libs) {
					ExportSymbolPtr	sym2 = null;
					DynamicModule		mod2;

					lazyGetSymbolFromLib(ctx, lib, sym.name, sym, (ref DynamicModule otherMod, ref ExportSymbol otherSym, bool otherModLinking) {
						if (otherSym.address is null || otherSym.isExternal || SymbolType.Unresolved == otherSym.type) {
							return false;
						}
						sym2 = &otherSym;
						mod2 = otherMod;
						return true;
					});
					
					if (sym2 !is null && mod2 !is mod && sym2.address !is sym.address) {
						//throw new DDLException("Duplicate module info found: {}", sym.name);
						//*sym = *sym2;
						
						Trace.formatln("LazyLinker warning: Duplicate module info found: {}", sym.name);
					}
					
					if (mod2 is mod) {
						break groupIter;
					}
				}
			}
			
			debug debugLog("Found moduleinfo for {0} at [{}] {2}", mod.getName, sym.address, sym.name);
			
			ctx.moduleSet.symbols[sym.name] = 0;
			ctx.moduleSet.items ~= ModuleSetItem(mod, cast(ModuleInfo)(sym.address));
		}
	}
	
	
	protected void link(LinkingContext ctx, DynamicModule mod, LinkGroup[][] linkOrder) {
		if (mod.isLinking) {
			return;
		} else {
			mod.isLinking = true;
		}
		
		version (LinkerSpam) Trace.formatln("Linking module {}", mod.getName);
		
		auto modSymbols = mod.getSymbols();

		foreach (ref sym; modSymbols) {
			if (sym.isLinked) {
				if (SymbolType.Unresolved == sym.type || null == sym.address) {
					sym.isLinked = false;
				}
			}
		}

		foreach (ref sym; modSymbols) {
			link(ctx, &sym, mod, linkOrder/+, false+/);
		}
		
		/+foreach (ref sym; modSymbols) {
			/+if (!sym.isLinked) {
				if (sym.type != SymbolType.Unresolved) {
					sym.isLinked = true;
				}
			}+/
			sym.isLinking = false;
		}+/
		
		foreach (ref sym; modSymbols) {
			addModuleCtor(ctx, &sym, mod);
		}
		
		selfResolve(mod);
		registerDebugInfo(mod);
	}
	
	
	protected void registerDebugInfo(DynamicModule mod) {
		version (TangoTrace3) {
			auto mdi = ModuleDebugInfo_new();
			char* modName = ModuleDebugInfo_bufferString(mdi, mod.getName);

			foreach (li; mod.getSymbolLineNumbers) {
				auto sym = mod.getSymbol(li.symbolName);
				if (sym !is null && sym.address !is null && li.lineNumber != 0) {
					size_t addr = cast(size_t)(sym.address + li.baseOffset);
					ModuleDebugInfo_addDebugInfo(mdi, addr, modName, ModuleDebugInfo_bufferString(mdi, sym.name), li.lineNumber);
				}
			}
			
			dynamicModuleDebugInfo[mod] = mdi;
			GlobalDebugInfo_addDebugInfo(mdi);
		}
	}
	
	
	protected bool lazyGetSymbolFromLib(
			LinkingContext ctx,
			DynamicLibrary lib,
			char[] name,
			ExportSymbolPtr targetSym,
			bool delegate(ref DynamicModule, ref ExportSymbol, bool moduleLinking) handler)
	{
		LinkGroup[][]		linkOrder;
		DynamicModule		otherMod;
		ExportSymbolPtr	otherSym;
		DynamicLibrary		origLib = lib;
		bool						moduleLinking = false;
		
		if (auto lazyLib = cast(LazyLibrary)lib) {
			if (lazyLib.realLib is null) {
				version (LinkerSpam) Trace.formatln("{} symbol {} caused lib {}({}) to be loaded", targetSym.getTypeName, name, lazyLib.source, lazyLib.type);
			}
			findRealLibrary(lazyLib);
			lib = lazyLib.realLib;

			otherMod = lib.getModuleForSymbol(name);
			if (otherMod is null) {
				return false;
			}
			
			otherSym = lib.getSymbol(name);
			linkOrder = lazyLib.linkOrder;
			moduleLinking = otherMod.isLinking || ctx.isScheduled(otherMod);
		} else {
			otherMod = lib.getModuleForSymbol(name);
			if (otherMod is null) {
				return false;
			}
			
			otherSym = lib.getSymbol(name);
			linkOrder = moduleLinkOrder[otherMod];
			moduleLinking = otherMod.isLinking;
		}
		
		version (LinkerSpam) Trace.formatln("Found in {}", otherMod.getName);		
		
		if (otherSym is targetSym && targetSym.type != SymbolType.Unresolved && targetSym.address !is null) {
			version (LinkerSpam) Trace.formatln("Self-resolving symbol {} in module {} ; addr={}", targetSym.name, otherMod.getName, targetSym.address);
			return true;
		}

		if (otherSym.isLinking) {
			version (LinkerSpam) Trace.formatln("Already linking {} in module {}", otherSym.getTypeName, otherMod.getName);
			//if ("_D5mintl5deque8__assertFiZv" == targetSym.name && "...ext.mintl.deque.d" == otherMod.getName && SymbolType.Unresolved == targetSym.type) assert (false);
			return false;
		}

		//bool wasStrong = SymbolType.Strong == otherSym.type;
		this.link(ctx, otherSym, otherMod, linkOrder/+, true+/);
		
		if (handler(otherMod, *otherSym, moduleLinking)) {
			//if (wasStrong) {
				/+if (auto lazyLib = cast(LazyLibrary)origLib) {
					Trace.formatln("{} symbol {} caused lib {} to be linked", targetSym.getTypeName, name, lazyLib.source);
				}+/
				if (!moduleLinking) {
					ctx.scheduleLinking(otherMod, linkOrder);
				}
			//}
			return true;
		} else {
			/+if (!otherMod.isLinking) {
				otherSym.isLinked = false;
			}+/
			return false;
		}
	}
	
	
	protected LinkGroup[][] getLinkOrder(LazyLibrary lib) {
		assert (lib.type in libTypeSettings, lib.type);
		LinkGroup[][] result_;
		
		auto options = getLibTypeSettings(lib.type);
		auto order_ = options.linkOrder[];

		version (LinkerSpam) Trace.formatln("link order for {}({}) : {}", lib.source, lib.type, order_);
		
		foreach (symt, ref order; order_) {
			LinkGroup[] result;
			
			foreach (o; order) {
				if ("self" == o) {
					assert (lib.options.root in options.selfGroups, lib.options.root);
					result ~= options.selfGroups[lib.options.root];
				} else {
					result ~= getLibTypeSettings(o).linkGroup;
				}
			}
			
			result_ ~= result;
		}
		
		return result_;
	}
	
	
	LibrarySource getSource(LibrarySource libRoot, LibrarySource libPath) {
		return .getSource(this.settings.appRoot, .getSource(libRoot, libPath));
	}
		
	
	this() {
		_providerRegistry = new ProviderRegistry;
		
		version (LazyLinkerBuiltinContainers) {
		} else {
			libTypeSettings		= new typeof(libTypeSettings);
			allLibraries			= new typeof(allLibraries);
			moduleLinkOrder	= new typeof(moduleLinkOrder);
			moduleType			= new typeof(moduleType);
		}

		typeMatcher = new LibraryTypeMatcher;
		settings.appRoot = Path.standard(Environment.directory);
		if (settings.appRoot.length > 0 && '/' == settings.appRoot[$-1]) {
			settings.appRoot = settings.appRoot[0 .. $-1];
		}
	}
	
	
	LibrarySource[] getStdIncludes(LibrarySource libRel) {
		if (0 == stdIncludes.length) {
			return null;
		}
		
		auto libRoot = .getSource(settings.appRoot, libRel);
		auto appRoot = settings.appRoot;
		
		auto lib2app = appRoot.getSourceRelativeFrom(libRoot);
		
		LibrarySource[] res;
		foreach (inc; stdIncludes) {
			res ~= .getSource(lib2app, inc);
			version (LinkerSpam) Trace.formatln("{} -> {}  (dir={})", inc, .getSource(lib2app, inc), libRel);
		}
		
		return res;
	}
	
	
	ProviderRegistry providerRegistry() {
		return _providerRegistry;
	}
	
	
	public {
		ProviderRegistry						_providerRegistry;
		LinkerSettings							settings;
		LibrarySource[]							stdIncludes;
	}
	
	protected {
		LibraryTypeMatcher					typeMatcher;

		version (LazyLinkerBuiltinContainers) {
			LibTypeSettings[LibraryType]		libTypeSettings;
			DynamicLibrary[LibrarySource]	allLibraries;
			LinkGroup[][][DynamicModule]	moduleLinkOrder;
			LibraryType[DynamicModule]		moduleType;
			version (TangoTrace3) {
				ModuleDebugInfo[DynamicModule]	dynamicModuleDebugInfo;
			}
		} else {
			HashMap!(LibraryType, LibTypeSettings)		libTypeSettings;
			HashMap!(LibrarySource, DynamicLibrary)	allLibraries;
			HashMap!(DynamicModule, LinkGroup[][])	moduleLinkOrder;
			HashMap!(DynamicModule, LibraryType)		moduleType;
			version (TangoTrace3) {
				HashMap!(DynamicModule, ModuleDebugInfo)	dynamicModuleDebugInfo;
			}
		}
	}
}


final class LazyLibrary : DynamicLibrary {
	public override ExportSymbolPtr getSymbol(char[] name) {
		//Trace.formatln("LazyLibrary.getSymbol");
		if (!realLinked) linkRealLib;
		return realLib.getSymbol(name);
	}
	
	public override DynamicModule[] getModules() {
		//Trace.formatln("LazyLibrary.getModules");
		if (!realLinked) linkRealLib;
		return realLib.getModules;
	}
	
	public override char[] getType() {
		if (!realLinked) return "LAZY";
		else return realLib.getType;
	}
	
	public override Attributes getAttributes() {
		//Trace.formatln("LazyLibrary.getAttributes");
		if (!realLinked) linkRealLib;
		return realLib.getAttributes;
	}

	public override DynamicModule getModuleForSymbol(char[] name) {
		//Trace.formatln("LazyLibrary.getModuleForSymbol");
		if (!realLinked) linkRealLib;
		return realLib.getModuleForSymbol(name);
	}

	public override ubyte[] getResource(char[] name) {
		//Trace.formatln("LazyLibrary.getResource");
		if (!realLinked) linkRealLib;
		return realLib.getResource(name);
	}
		
	public override void makePrivate() {
		if (realLinked) {
			realLib.makePrivate;
		}
	}


	public {
		LibrarySource	source;
		LibLoadOptions	options;
	}
	
	private {
		void linkRealLib() {
			linker.linkLazyLibrary(this);
			assert (realLinked);
			assert (realLib !is null);
		}
		
		
		LazyLinker			linker;
		LibraryType		type;
		DynamicLibrary	realLib;
		LinkGroup[][]	linkOrder;
		bool					realLinked;
		int					scheduledForLinking = -1;
	}
}



template MModuleInitSupport() {
	// borrowed from Phobos
	private enum
	{   MIctorstart = 1,  // we've started constructing it
	    MIctordone = 2,	  // finished construction
	    MIstandalone = 4, // module ctor does not depend on other module
				          // ctors being done first
	};

	/**
		Initalizes a ModuleInfo instance from a DynamicModule.
		
		From here on the provided library 
	*/
	protected void initModule(ModuleInfo m, int skip){
		debug debugLog("in init");
		if(m is null) return;

		debug debugLog ("m is {}",cast(void*)m);

		if(cast(void*)m == cast(void*) 0x14)
			return; 
//			m=(cast(void*) 0x80d6854);

		debug debugLog ("m is {}",m.name);
		
		if (m.flags & MIctordone) return;

		debug debugLog("this module: {0:X8}",cast(void*)m);
		debug debugLog("(name: {0:X8} %d)",m.name.ptr,m.name.length);		
		debug debugLog("(ctor: {0:X8})",cast(void*)(m.ctor));
		debug debugLog("(dtor: {0:X8})",cast(void*)(m.dtor));
		debug debugLog("Module: {0}\n",m.name);
		
		if (m.ctor || m.dtor)
		{
		    if (m.flags & MIctorstart)
		    {	if (skip)
			    return;
				throw new ModuleCtorError(m);				
		    }
		    
		    m.flags |= MIctorstart;
		    debug debugLog("{} running imported modules ({0})...",m.name,m.importedModules.length);
		    foreach(ModuleInfo imported; m.importedModules){
			    debug debugLog("-running: [{0:X8}]",cast(void*)imported);
			    initModule(imported,0);
			    debug debugLog("-done.");
		    }
		    version (LinkerSpam) Trace.formatln("running ctor [{0:X8}] for {}",cast(void*)m.ctor, m.name);
		    if (m.ctor)
			(*m.ctor)();
			version (LinkerSpam) Trace.formatln("done running ctor");
		    m.flags &= ~MIctorstart;
		    m.flags |= MIctordone;
	
		    //TODO: Now that construction is done, register the destructor
		}
		else
		{
		    m.flags |= MIctordone;
		    debug debugLog("{},running imported modules ({})...",m.name,m.importedModules.length);
		    foreach(ModuleInfo imported; m.importedModules){
			    debug debugLog("running: [{0:X8}]",cast(void*)imported);
			    initModule(imported,1);
			    debug debugLog("-done.");
		    }
		}    
	}
	
	
	public void runModuleCtors(ModuleSet moduleSet) {
//		Trace.formatln("runModuleCtors {}",moduleSet.items.length);
		foreach_reverse (item; moduleSet.items) {
			if (item.mod.isResolved) {
				//Trace.formatln("running {0} init at [{1:X,8}]", item.moduleInfo.name, cast(void*)item.moduleInfo);
				this.initModule(item.moduleInfo, 0);
			}
		}
	}
}



version(Stacktrace){
	extern(C) extern void regist_cb(char* name, void* fp);
	extern(C) extern void addDebugLineInfo__(uint addr, ushort line, char* file);
}
/**
	Exception class used exclusively by the Linker.
	
	LinkModuleException are generated when the linker cannot resolve a module during the linking process.
*/
class LinkModuleException : Exception{
	DynamicModule mod;
	
	/**
		Module that prompted the link exception.
	*/
	DynamicModule reason(){
		return this.mod;
	}
	
	/**
		Constructor.
		
		Params:
			reason = the module that prompts the exception
	*/
	public this(DynamicModule reason){
		super("LinkModuleException: cannot resolve '" ~ reason.getName ~ "'\n" ~ reason.toString());
		this.mod = reason;
	}
}


class ModuleCtorError : Exception{
	ModuleInfo mod;
	
	/**
		Module that prompted the link exception.
	*/
	ModuleInfo reason(){
		return this.mod;
	}
	
	/**
		Constructor.
		
		Params:
			reason = the module that prompts the exception
	*/
	public this(ModuleInfo reason){
		super("ModuleCtorError: cannot init '" ~ reason.name ~ "'\n");
		this.mod = reason;
	}
}

