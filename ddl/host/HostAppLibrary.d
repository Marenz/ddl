/+
	Copyright (c) 2008 Tomasz Stachowiak
	
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

module ddl.host.HostAppLibrary;

private {
	import ddl.host.HostAppModule;
	import ddl.DynamicLibrary;
	import ddl.DynamicModule;
	import ddl.ExportSymbol;
	import ddl.Attributes;
}


class HostAppLibrary : DynamicLibrary {
	override ExportSymbolPtr getSymbol(char[] name) {
		return hostAppModule.getSymbol(name);
	}
	

	override DynamicModule[] getModules() {
		return [hostAppModule];
	}
	

	override char[] getType() {
		return "host";
	}
	

	override Attributes getAttributes() {
		return null;
	}


	override DynamicModule getModuleForSymbol(char[] name) {
		return hostAppModule.getSymbol(name) !is null ? hostAppModule : null;
	}
	

	override ubyte[] getResource(char[] name) {
		return null;
	}
	
	
	this() {
		hostAppModule = new HostAppModule;
	}
	
	
	private {
		HostAppModule hostAppModule;
	}
}
