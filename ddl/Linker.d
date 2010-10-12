/+
	Copyright (c) 2005-2007 Eric Anderton, Tomasz Stachowiak
        
	Permission is hereby granted, free of charge, to any person
	obtaining a copy of this software and associated documentation
	files (the "Software"), to deal in the Software without
	restriction, including without limitation the rights to use,
	copy, modify, merge, publish, distribute, sublicense, and/or
	sell copies of the Software, and to permit persons to whom the
	Software is furnished to do so, subject to the following
	conditions:

	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
	OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
	OTHER DEALINGS IN THE SOFTWARE.
+/
/**
	Authors: Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005,2006 Eric Anderton
*/
module ddl.Linker;

private import ddl.ExportSymbol;
private import ddl.DynamicLibrary;
private import ddl.DynamicModule;
private import ddl.Demangle;
private import ddl.LoaderRegistry;
private import ddl.DDLException;
import tango.stdc.stdio;

debug (DDL) private import ddl.Utils;



// for the phobos backtrace hack
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



struct LinkerBehavior {
	bool runModuleCtors = true;
	bool replaceStrongSymbols = false;
	bool delegate(DynamicModule mod, ExportSymbol sym, DynamicModule otherMod, ExportSymbol otherSym) shouldReplaceSymbol;
}



/**
	General-Purpose runtime linker for DDL.
*/
class Linker{
	public LinkerBehavior behavior;// bool autoRunModuleCtors = true;
	
	
	protected LoaderRegistry registry;
	/** 
		Library list for libraries used for linking.
		
		The implementation here is deliberately simple -- some would call it brain-dead.
		The developer is therefore strongly encouraged to subclass this in order to 
		develop more sophisticated linking and library management behaviors.
		
		The order of insertion into the library list is used as a priority scheme
		when attempting to link new modules into the runtime.  The first library 
		added to the linker should be the current in-situ library, should linking
		to classes and types in the current runtime be a requirement.  In any case
		the next candidates for addition to the linker should be the runtime libraries
		in no particular order.
		
		The linker will attept to link against the first library first, and so on
		down the list.
	*/
	protected DynamicLibrary[] libraries;
	
	/** 
		The linker uses an LoaderRegistry to handle internal library dependencies
		automatically, such that the developer can more easily automate linking behavior.
			
		Params:
			registry = the LoaderRegistry to use when loading binaries.
	*/
	public this(LoaderRegistry registry){
		this.registry = registry;
	}
	
	/**
		Returns: the current registry
	*/
	public LoaderRegistry getRegistry(){
		return this.registry;
	}

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
		if(m is null) return;
		if (m.flags & MIctordone) return;

		debug (DDL) debugLog("this module: {0:X8}",cast(void*)m);
		debug (DDL) debugLog("(name: {0:X8} %d)",m.name.ptr,m.name.length);		
		debug (DDL) debugLog("(ctor: {0:X8})",cast(void*)(m.ctor));
		debug (DDL) debugLog("(dtor: {0:X8})",cast(void*)(m.dtor));
		debug (DDL) debugLog("Module: {0}\n",m.name);
		
		if (m.ctor || m.dtor)
		{
		    if (m.flags & MIctorstart)
		    {	if (skip)
			    return;
				throw new ModuleCtorError(m);				
		    }
		    
		    m.flags |= MIctorstart;
		    debug (DDL) debugLog("running imported modules ({0})...",m.importedModules.length);
		    foreach(ModuleInfo imported; m.importedModules){
			    debug (DDL) debugLog("running: [{0:X8}]",cast(void*)imported);
			    initModule(imported,0);
			    debug (DDL) debugLog("-done.");
		    }
		    debug (DDL) debugLog("running ctor [{0:X8}]",cast(void*)m.ctor);
		    if (m.ctor)
			(*m.ctor)();
			debug (DDL) debugLog("done running ctor");
		    m.flags &= ~MIctorstart;
		    m.flags |= MIctordone;
	
		    //TODO: Now that construction is done, register the destructor
		}
		else
		{
		    m.flags |= MIctordone;
		    debug (DDL) debugLog("running imported modules ({0})...",m.importedModules.length);
		    foreach(ModuleInfo imported; m.importedModules){
			    debug (DDL) debugLog("running: [{0:X8}]",cast(void*)imported);
			    initModule(imported,1);
			    debug (DDL) debugLog("-done.");
		    }
		}    
	}
	
	
	private void selfResolveAll() {
		foreach (lib; this.libraries) {
			foreach (mod; lib.getModules) {
				if (mod.isResolved) continue;
				
				foreach (ref sym; mod.getSymbols) {
					if (SymbolType.Weak == sym.type) {
						sym.type = SymbolType.Strong;
					}
				}

				mod.resolveFixups();
			}
		}
	}
	
	
	public void checkResolved(DynamicLibrary lib, void delegate(DynamicModule, ExportSymbolPtr) errHandler = null) {
		foreach (mod; lib.getModules) {
			if (mod.isResolved) continue;
			
			foreach (ref sym; mod.getSymbols) {
				if (SymbolType.Unresolved == sym.type) {
					if (errHandler !is null) {
						errHandler(mod, &sym);
					} else {
						char[] ext = sym.isExternal ? "external" : "local";
						throw new DDLException("cannot resolve symbol: [{0:X}] {1} {2} {3}"\n, cast(uint)sym.address, sym.getTypeName(), ext, sym.name);
					}
				}
			}
		}
	}
	
	
	public void runModuleCtors(ModuleSet moduleSet) {
		foreach(item; moduleSet.items) {
			if (item.mod.isResolved) {
				//Trace.formatln("running {0} init at [{1:X,8}]", item.moduleInfo.name, cast(void*)item.moduleInfo);
				this.initModule(item.moduleInfo, 0);
			}
		}
	}
	
	
	struct ModuleSetItem {
		DynamicModule	mod;
		ModuleInfo		moduleInfo;
	}
	
	struct ModuleSet {
		ModuleSetItem[]	items;
		byte[char[]]			symbols;
	}
	
	//alias ModuleSetItem[char[]] ModuleSet;
	
	public void link(DynamicLibrary curLib, DynamicModule mod, inout ModuleSet moduleSet, bool canSelfResolve, int callDepth = 0) {
		if (mod.isLinking) {
			return;
		}
		mod.isLinking = true;
		
		byte[DynamicModule] depPrinted;
		
		//printf("Linking module %.*s"\n, mod.getName);

		auto modSymbols = mod.getSymbols();
		symbolIter: foreach (ref sym; modSymbols) {
			// outsource all symbols when commented out
			// this is equivalent to ignoring multiple symbol definitions and choosing the 'first' one
			// should probably be driven by some flexible linking mechanism
			
			if (SymbolType.Strong == sym.type && (!behavior.replaceStrongSymbols/+ || callDepth > 0+/)) {
				continue;
			}

			//printf("Examining %.*s symbol %.*s in %.*s"\n, sym.getTypeName, sym.name, mod.getName);
			
			foreach (lib; this.libraries) {
				if (lib is curLib && SymbolType.Unresolved != sym.type) {
					//Stdout.formatln("{} ({}) -> self", mod.getName, sym.name);
					break;
				}
				
				auto otherMod = lib.getModuleForSymbol(sym.name);
				if (otherMod is null || otherMod is mod) {
					continue;
				}

				{
					auto otherSym = lib.getSymbol(sym.name);
					if (behavior.replaceStrongSymbols) {
						if (SymbolType.Unresolved == otherSym.type) {
							continue;
						}

						if (otherSym.type <= sym.type && lib is curLib) {
							break;
						}
					} else {
						if (otherSym.type <= sym.type) {
							continue;
						}
					}
				}
				
				//Stdout.formatln("{} ({}) -> {}", mod.getName, sym.name, otherMod.getName);

				if (!otherMod.isResolved) {
					if (!(otherMod in depPrinted)) {
						depPrinted[otherMod] = 0;
					}
					this.link(lib, otherMod, moduleSet, true, callDepth+1);
				}
				
				auto otherSym = lib.getSymbol(sym.name);//otherMod.getSymbol(sym.name);
				
				//if (SymbolType.Unresolved != otherSym.type) {
				if (
					SymbolType.Strong == otherSym.type
					|| (SymbolType.Weak == otherSym.type && SymbolType.Unresolved == sym.type)
				) {
					if (behavior.shouldReplaceSymbol is null || behavior.shouldReplaceSymbol(mod, sym, otherMod, *otherSym)) {
						/+printf("Binding %.*s symbol %.*s :: %.*s to %.*s symbol %.*s :: %.*s"\n,
							sym.getTypeName, mod.getName, sym.name,
							otherSym.getTypeName, otherMod.getName, otherSym.name);+/
						sym.address = otherSym.address;
						//sym.type = otherSym.type;//SymbolType.Strong;
						sym.type = SymbolType.Strong;
						sym.isExternal = true;
						continue symbolIter;
					}
				}
			}

			/+if (sym.type == SymbolType.Weak && canSelfResolve) {
				sym.type = SymbolType.Strong;
			}+/
		}

		mod.resolveFixups();
		//mod.isLinking = false;
		
		version (Stacktrace){
			foreach (li; mod.getSymbolLineNumbers) {
				auto sym = mod.getSymbol(li.symbolName);
				if (sym !is null && sym.address !is null && li.lineNumber != 0) {
					char[1024] foo;
					foo[0 .. sym.name.length] = sym.name;
					foo[sym.name.length] = 0;

					void* addr = sym.address + li.baseOffset;
					regist_cb(foo.ptr, addr);
					//printf("symbol %x %.*s line: %d\n", addr, sym.name, li.lineNumber);
					addDebugLineInfo__(cast(uint)addr, li.lineNumber, (mod.getName ~ \0).ptr);
				}
				/+if (sym.address !is null) {
					printf("symbol %x %.*s line: %d\n", sym.address, sym.name, sym.lineNumber);
					char[1024] foo;
					foo[0 .. sym.name.length] = sym.name;
					foo[sym.name.length] = 0;
					
					regist_cb(foo.ptr, sym.address);
					addDebugLineInfo__(cast(uint)sym.address, sym.lineNumber, (mod.getName ~ \0).ptr);
				}+/
			}
		}
		
		foreach (ref sym; modSymbols) {
			// symbol must be defined and be local only
			if (sym.address is null || sym.isExternal) {
				continue;
			}
			
			char[] suffix = `__ModuleInfoZ`;
			if (sym.name.length > suffix.length && sym.name[$ - suffix.length .. $] == suffix) {
				if (sym.name in moduleSet.symbols) {
					continue;
				}
				
				// The sole fact that this module has a ctor doesn't mean that we want to use it
				// it might've already been called, but it's in the host, and this lib is not the host lib
				// Thus, we search for this symbol globally again
				
				foreach (lib; this.libraries) {
					auto sym2 = lib.getSymbol(sym.name);
					if (sym2 is null || sym2.address is null || sym2.isExternal || SymbolType.Unresolved == sym2.type) {
						continue;
					}
					
					auto mod2 = lib.getModuleForSymbol(sym.name);
					if (mod2 is mod) {
						continue;
					}
					
					//Stdout.formatln("Taking the static ctor symbol {} from {}", sym.name, mod2.getName);
					sym = *sym2;
				}
				
				debug (DDL) debugLog("Found moduleinfo for {0} at [{1:X8}] {2}", mod.getName, sym.address, sym.name);
				//printf("Found moduleinfo for %.*s at %d %.*s"\n, mod.getName, sym.address, sym.name);
				
				moduleSet.symbols[sym.name] = 0;
				moduleSet.items ~= ModuleSetItem(mod, cast(ModuleInfo)(sym.address));
			}
		}
	}
	
	
	private void finishLinking() {
		foreach (lib; this.libraries) {
			foreach (mod; lib.getModules) {
				mod.isLinking = false;
			}
		}
	}
	
	
	/*
		This implementation has problems with circular dependencies across modules. I've replaced
		it with one that doesn't do strict checking of SymbolType and isResolved.
		To account for the change, I had to include a function to check the status of the linking.
		
		checkResolved(lib) will by default check if every symbol in the lib is Strong and throw an exception.
		It can be given a handler to do more fancy unresolved symbol handling.
		
		- h3r3tic, 2008-04-21
	*/
	
		
	/**
		Links a module against the linker's internal cross-reference.
		
		This implementation performs a long search of modules, then discrete symbols in the
		cross-reference.
		
		The parameter canSelfResolve is passed as 'true' for registraion variants of link 
		routines.
		
		moduleSet a set of modules that need initalization following the link pass.
	*/
	/+public void link(DynamicModule mod, inout ModuleSet moduleSet, bool canSelfResolve){
		uint i;
		
		//protect against infinite recursion here by returning early
		//by this, we count on the module being resolved further up the call stack
		if(mod.isLinking) return;
		
		mod.isLinking = true;
		
		if (canSelfResolve) printf("(Can self-resolve) ");
		debug (DDL) debugLog("Linking module: {0}",mod.getName);
		printf("Linking module %.*s"\n, mod.getName);
		
		auto moduleSymbols = mod.getSymbols();
		printf("Number of symbols: %d"\n, moduleSymbols.length);
		
		for(i=0; i<moduleSymbols.length; i++){
			auto symbol = &(moduleSymbols[i]);
			printf("Pre-examining %.*s symbol %.*s in %.*s"\n, symbol.getTypeName, symbol.name, mod.getName);
		}

		for(i=0; i<moduleSymbols.length; i++){
			auto symbol = &(moduleSymbols[i]);
			
			printf("Examining %.*s symbol %.*s in %.*s"\n, symbol.getTypeName, symbol.name, mod.getName);
			
			// ensure we're only linking weak and unresolved symbols
			if(symbol.type == SymbolType.Strong) continue;
			
			// resolve a dependency from out of the registry
			debug (DDL) debugLog("searching %d registered libs",this.libraries.length);
			foreach(lib; this.libraries){
				auto libMod = lib.getModuleForSymbol(symbol.name);
				if(libMod && libMod !is mod){
					if(!libMod.isResolved()){
						this.link(libMod,moduleSet,true);
					}
					auto otherSymbol = libMod.getSymbol(symbol.name);
					if(otherSymbol.type == SymbolType.Strong){
						debug (DDL) debugLog("[Linker] found {0} at {1:8X}",otherSymbol.name,otherSymbol.address);
						symbol.address = otherSymbol.address;
						symbol.type = SymbolType.Strong;
						symbol.isExternal = true; // set extern status for externally resolved weak symbols
						debug (DDL) debugLog("linked symbol");
						goto nextSymbol;
					}
					debug (DDL) debugLog("found in {}", libMod.getName);
					debug (DDL) debugLog("symbol is not strong ({0} -> {1:X})",symbol.getTypeName,symbol.address);
				} else if (libMod && libMod is mod) {
					debug (DDL) debugLog("found in the current module ({})", mod.getName);
					debug (DDL) debugLog("symbol is not strong ({0} -> {1:X})",symbol.getTypeName,symbol.address);
				}
			}
			// attempt to self-resolve where needed
			if(symbol.type == SymbolType.Weak && canSelfResolve){
				symbol.type = SymbolType.Strong;
			}
			else if(symbol.type != SymbolType.Strong){
				char[] ext = symbol.isExternal ? "external" : "local";
				char[] self = canSelfResolve ? "can Self Resolve" : "cannot Self Resolve";
				bool isWeak = symbol.type == SymbolType.Weak;
				throw new DDLException("cannot resolve symbol: ({0}) [{1:8X}] {2} {3} {4}" ~ (isWeak ? " the symbol is weak" : "") ~ \n,self,cast(uint)symbol.address,symbol.getTypeName(),ext,symbol.name);
			}
			
			nextSymbol:
			{} // satisfy compiler
		}
				
		mod.resolveFixups();
		mod.isLinking = false;
		
		if(!mod.isResolved()){
			throw new LinkModuleException(mod);
		}
		
		debug (DDL) debugLog("mod is resolved: {0}",mod.toString());

		auto allSymbols = mod.getSymbols();
		foreach (symbol; allSymbols) {
			version(Stacktrace){
				if (symbol.address !is null) {
					//printf("symbol %.*s line: %d\n", symbol.name, symbol.lineNumber);
					regist_cb((symbol.name ~ \0).ptr, symbol.address);
					addDebugLineInfo__(cast(uint)symbol.address, symbol.lineNumber, mod.getName);
				}
			}

			// symbol must be defined and be local only
			if (symbol.address is null || symbol.isExternal) continue;
			char[] suffix = `__ModuleInfoZ`;
			if (symbol.name.length > suffix.length && symbol.name[$ - suffix.length .. $] == suffix) {
				debug (DDL) debugLog("Found moduleinfo for {0} at [{1:8X}] {2}",mod.getName,symbol.address,symbol.name);
				moduleSet[symbol.name] = cast(ModuleInfo)(symbol.address);
			}
		}
	}+/
	
	/**
		Links a library against the linker's internal cross-reference.
		
		There is a subtle difference between linking a lib and linking a lib that has been
		added to the cross-reference.  If every module in the lib is merely dependent upon
		modules that exist in the cross-reference already, then just calling link will do 
		the task.  Otherwise, the lib should be added to the cross-reference first, before
		proceeding with the actual link.
		
		Weak symbol resolution, mostly D templates, will not ocurr for the library passed
		in, unless it is already registered.  The reason behind this restriction is to
		ensure that all libraries that are linked by a given linker, reference the same
		set of common weak symbols.
				
		Examples:
		---
		DynamicLibrary lib;
		Linker linker;
		
		linker.register(lib); // add to xref first
		linker.link(lib); // link in the library and its aggregate modules
		---
	*/
	public ModuleSet link(DynamicLibrary lib){
		ModuleSet moduleSet;
		
		// determine registration status
		bool canSelfResolve = this.isRegistered(lib);
		
		// link
		foreach(DynamicModule mod; lib.getModules) {
			this.link(lib, mod, moduleSet, canSelfResolve);
		}

		selfResolveAll();
		finishLinking();
		
		/+// init - run whatever initalizers are pending
		foreach(mod,moduleInfo; moduleSet){
			debug (DDL) debugLog("running {0} init at [{1:8X}]",mod,cast(void*)moduleInfo);
			this.initModule(moduleInfo,0);
		}
	//	_moduleCtor2(moduleSet.values,0);
	+/
	
		if (behavior.runModuleCtors) {
			runModuleCtors(moduleSet);
		}
	
		return moduleSet;
	}
	
	/**
		Loads a library for the filename. 
		
		If the attrStdVersion parameter is supplied this is matched against the "std.version" 
		attribute in the supplied library.  If the attribute doesn't exist, and or the
		attrStdVersion attribute is omitted or set to "", then the library is loaded anyway.
		Otherwise, should attrStdVersion not match the "std.version" attribute, the method
		throws an exception.		
		
		Params:
		filename = the filename of the library to load
		attrStdVersion = (optional) value to match to attribute "std.version" in the loaded library.
	*/
	public DynamicLibrary load(char[] filename,char[] attrStdVersion = ""){
		DynamicLibrary result = registry.load(filename,attrStdVersion);
		return result;
	}
	
	/**
		Registers a library with the linker to be used during link operations.
	*/
	public void register(DynamicLibrary lib){
		assert (lib !is null);
		debug (DDL) foreach(DynamicModule mod; lib.getModules){
			debugLog("[Linker.register]: {0}",mod.getName);
		}
		libraries ~= lib;
	}
		
	
	/** 
		Loads a DDL library and registers it with this linker.
		
		Returns: the DynamicLibrary that corresponds to filename
		Params:
			filename = the file name of the library to load
	*/
	public DynamicLibrary loadAndRegister(char[] filename,char[] attrStdVersion = ""){
		DynamicLibrary result = registry.load(filename,attrStdVersion);
		register(result);
		return result;
	}
	
	/** 
		Loads a DDL library and links it against all registered libraries.
		
		Returns: the DynamicLibrary that corresponds to filename
		Params:
			filename = the file name of the library to load
	*/
	public DynamicLibrary loadAndLink(char[] filename,char[] attrStdVersion = ""){
		DynamicLibrary result = registry.load(filename,attrStdVersion);
		link(result);
		return result;
	}
	
	/** 
		Loads a DDL library, links it against all registered libraries, and registers it.
		
		Returns: the DynamicLibrary that corresponds to filename
		Params:
			filename = the file name of the library to load
	*/
	public DynamicLibrary loadLinkAndRegister(char[] filename,char[] attrStdVersion = ""){
		DynamicLibrary result = registry.load(filename,attrStdVersion);
		link(result);
		register(result);
		return result;
	}

	/**
	 * Warning, this is experimental only!
	 * Params:
	 *     filename = 
	 *     attrStdVersion = 
	 * Returns:
	 */
	public DynamicLibrary loadRegisterAndLink(char[] filename,char[] attrStdVersion = ""){
		DynamicLibrary result = registry.load(filename,attrStdVersion);
		register(result);
		link(result);
		return result;
	}
	
	/**
		Returns true if the library provided is registered with this linker.
	*/
	public bool isRegistered(DynamicLibrary lib){
		foreach(registeredLib; this.libraries){
			if(registeredLib == lib) return true; 
		}
		return false;
	}
}
