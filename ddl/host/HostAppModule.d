/+
	Copyright (c) 2008 Tomasz Stachowiak
	
	Based on flectioned.d written by Thomas Kühne, Copyright (C) 2006-2007
        
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

module ddl.host.HostAppModule;


version (Windows) {	
} else {
	static assert (false, "not supported");
}


private {
	extern(C) extern void* _except_list;
	extern(Windows) extern void _d_throw(void*);
}


private {
	import ddl.host.HostAppLibrary;
	
	import ddl.DynamicModule;
	import ddl.ExportSymbol;
	
	import tango.sys.win32.UserGdi;
	import tango.stdc.stringz;
	import tango.stdc.stdio;


	alias Exception SymbolException;


	extern(Windows){

		enum{
			MAX_MODULE_NAME32 = 255,
			TH32CS_SNAPMODULE = 0x00000008,
		}

		static if(!is(MODULEENTRY32))
			struct MODULEENTRY32 {
				DWORD  dwSize;
				DWORD  th32ModuleID;
				DWORD  th32ProcessID;
				DWORD  GlblcntUsage;
				DWORD  ProccntUsage;
				BYTE  *modBaseAddr;
				DWORD  modBaseSize;
				HMODULE hModule;
				char   szModule[MAX_MODULE_NAME32 + 1];
				char   szExePath[MAX_PATH];
			}
		
		static if(!is(typeof(Module32First)))
			BOOL Module32First(HANDLE, MODULEENTRY32*);

		static if(!is(typeof(Module32Next)))
			BOOL Module32Next(HANDLE, MODULEENTRY32*);
		
		static if(!is(typeof(CreateToolhelp32Snapshot)))
			HANDLE CreateToolhelp32Snapshot(DWORD,DWORD);

		private{
			// defining them at function level causes the wrong CallConvention
			extern(Windows) BOOL function(HANDLE, PCSTR, BOOL) sym_initialize;
			extern(Windows) DWORD function(HANDLE, HANDLE, PCSTR, PCSTR, DWORD, DWORD) sym_load_module;
			extern(Windows) BOOL function(HANDLE, DWORD, void*, void*) sym_enumerate_symbols;
		}


		int add_symbol(LPSTR name, ULONG addr, ULONG size, PVOID){
			//printf("%s"\n, name);
			ExportSymbol sym;
			sym.isExternal = false;
			sym.type = SymbolType.Strong;
			sym.address = cast(void*)addr;
			sym.name = fromStringz(name).dup;
			HostAppModule.addSymbol(sym);
			return true;
		}


		void find_symbols(){
			HANDLE proc;
			HANDLE snapshot;
			DWORD base;
			MODULEENTRY32 module_entry;
			char buffer[4096];

			HMODULE imagehlp;

			// create snapshot	
			proc = GetCurrentProcess();

			snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, 0);
			if(!snapshot){
				throw new SymbolException("failed: CreateToolHelp32Snapshot");
			}
			
			// init debugger helpers _after_ creating the snapshot
			imagehlp = LoadLibraryA("imagehlp.dll");
			if(!imagehlp){
				throw new SymbolException("failed to load imagehlp.dll");
			}
			scope(exit){
				FreeLibrary(imagehlp);
				sym_initialize = null;
				sym_load_module = null;
				sym_enumerate_symbols = null;
			}

			// init imagehlp.dll helpers
			sym_initialize = cast(typeof(sym_initialize)) GetProcAddress(imagehlp, "SymInitialize");
			if(!sym_initialize){
				throw new SymbolException("failed to get SymInitialize");
			}

			sym_load_module = cast(typeof(sym_load_module)) GetProcAddress(imagehlp, "SymLoadModule");
			if(!sym_load_module){
				throw new SymbolException("failed to get SymLoadModule");
			}
			sym_enumerate_symbols = cast(typeof(sym_enumerate_symbols)) GetProcAddress(imagehlp, "SymEnumerateSymbols");
			if(!sym_enumerate_symbols){
				throw new SymbolException("failed to get SymEnumerateSymbols");
			}

			if(!sym_initialize(proc, null, false)){
				throw new SymbolException("failed: SymInitialize");
			}

			// try to get the symbols of all MODULEs
			module_entry.dwSize = module_entry.sizeof;
			if(!Module32First(snapshot, &module_entry)){
				throw new SymbolException("failed: Module32First");
			}

			do {
				if (GetModuleFileNameA(module_entry.hModule, buffer.ptr, buffer.length)){
					base = sym_load_module(proc, HANDLE.init, buffer.ptr, null, 0, 0);
					if (base){
						sym_enumerate_symbols(proc, base, &add_symbol, null);
					}
				}
			} while(Module32Next(snapshot, &module_entry));
			
			addExtraSymbols();
		}
		
		
		void addExtraSymbols() {
			HostAppModule.addSymbol(ExportSymbol(false, SymbolType.Strong, &_except_list, "__except_list"));
			HostAppModule.addSymbol(ExportSymbol(false, SymbolType.Strong, &_d_throw, "__d_throw@4"));
		}
	}
}


class HostAppModule : DynamicModule {
	this() {
		synchronized (this.classinfo) {
			if (!_initialized) {
				_initialized = true;
				find_symbols();
			}
		}
	}
	
	
	override char[] getName() {
		return null;
	}


	override ExportSymbol[] getSymbols() {
		return _symbols;
	}


	override ExportSymbolPtr getSymbol(char[] name) {
		uint* idx = null;
		
		if (name.length > 1 && '_' == name[0]) {
			idx = name[1..$] in _symbolMap;
		}
		
		if (idx is null) {
			idx = name in _symbolMap;
		}

		if (idx is null) {
			return &ExportSymbol.NONE;
		} else {
			return &_symbols[*idx];
		}
	}
	
	
	override void resolveFixups() {
	}
	
	
	override bool isResolved() {
		return true;
	}
	

	private {
		static void addSymbol(ExportSymbol sym) {
			_symbolMap[sym.name] = _symbols.length;
			_symbols ~= sym;
		}


		static bool					_initialized;
		static ExportSymbol[]	_symbols;
		static uint[char[]]		_symbolMap;
	}
}

