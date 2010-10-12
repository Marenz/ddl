/+
	Copyright (c) 2005-2007  J Duncan, Eric Anderton
        
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
	COFF Library class (.lib file)

	Authors: J Duncan, Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005, 2006 J Duncan, Eric Anderton
*/

module ddl.coff.COFFLibrary;

private import ddl.coff.COFFModule;

private import ddl.ExportSymbol;
private import ddl.DynamicLibrary;
private import ddl.DynamicModule;
private import ddl.Utils;
private import ddl.Attributes;

// coff library class
class COFFLibrary : DynamicLibrary
{
	// dynamic library data
	COFFModule[] 			modules;
	DynamicModule[char[]] 	crossReference; // modules by symbol name	
	ExportSymbol[char[]] 	dictionary;

	// .lib data
	bool 					valid;
	char[] 					libraryName;
	char[] 					longnames;
//	COFFObject[]			objects;
	Attributes				attributes;
	
	public this(char[] filename){
//!		attributes["coff.filename"] = filename();
	}
	
	public char[] getType(){
		return("COFF");
	}
		
	public Attributes getAttributes(){
		return attributes;
	}
	
	package void setAttributes(Attributes other){
		other.copyInto(this.attributes);
	}
	
	package void setAttribute(char[] key,char[] value){
		this.attributes[key] = value;
	}
		
	public ExportSymbol[] getExports(){
		return dictionary.values;
	}	

	public ExportSymbol getExport(char[] name)
	{
		ExportSymbol *sym = name in dictionary;
		if(sym) return *sym;
		throw new Exception("Symbol " ~ name ~ " not found in library " ~ attributes["coff.filename"] ~ ".");
	}

	public DynamicModule[] getModules()
	{
		return this.modules;
	}
	
	public DynamicModule getModuleForExport(char[] name){
		debug (DDL) debugLog("looking for " ~ name);
		DynamicModule* mod = name in crossReference;
		debug (DDL) debugLog("Result: %0.8X",mod);
		if(mod) return *mod;
		return null;
	}
	
	public ubyte[] getResource(char[] name){
		return (ubyte[]).init;
	}

	// add .obj module to library
	package void addModule(COFFModule mod)
	{
		this.modules ~= mod;
		foreach(ExportSymbol exp; mod.getExports()){
			dictionary[exp.name] = exp;
			crossReference[exp.name] = mod;
		}
	}
	
	public char[] toString(){
		char[] result = "";
		foreach(mod; modules){
			result ~= mod.toString();
		}
		return result;
	}

    // DynaicLibrary override
	public DynamicModule getModuleForSymbol(char[] name)
    {
        return null;
    }

	public override ExportSymbolPtr getSymbol(char[] name)
    {
        return &ExportSymbol.NONE;
    }

}



