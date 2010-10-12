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
	Windows PE-COFF Object module class

	Authors: J Duncan, Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005, 2006 J Duncan, Eric Anderton
*/

module ddl.coff.COFFModule;

private import ddl.ExportSymbol;
private import ddl.DynamicModule;
private import ddl.FileBuffer;
private import ddl.Utils;

private import ddl.coff.COFFObject;
private import ddl.coff.COFFBinary;

private import tango.io.model.IReader;

// coff object class
class COFFModule : DynamicModule
{
	char[] 					moduleName;
	char[][char[]] 			dependencies;
	ExportSymbol[char[]] 	exports;
	COFFObject 				binary;

	this(FileBuffer file){
		binary = new COFFObject();
		binary.load(file);
		syncronizeSymbols();
	}
	
	public char[] getName(){
		return this.moduleName;
	}

	public char[][] getDependencies(){
		return cast(char[][])dependencies;
	}
	
	public void resolveDependencies(ExportSymbol[] exports){
		foreach(ExportSymbol sym; exports){
			//if(sym.name in dependencies){
				debug (DDL) printf("Resolving: %s = %0.8X\n",sym.name,sym.address);
				binary.fixDependency(sym.name,sym.address);
			//}
		}
//!		binary.resolveFixups();
		syncronizeSymbols();
	}
	
	public void resolveDependency(char[] name,void* address){
		binary.fixDependency(name,address);
//!		binary.resolveFixups();
		syncronizeSymbols();
	}
	
	public ExportSymbol[] getExports(){
		return exports.values;
	}
	
	public ExportSymbol getExport(char[] name){
		if(name in exports)	return exports[name];
		else return ExportSymbol.NONE;
	}
	
<<<<<<< .mine
	public bool isResolved(){
//!		return binary.isResolved();
        return true;
=======
	public bit isResolved(){
//!		return binary.isResolved();
        return true;
>>>>>>> .r278
	}
		
	protected void syncronizeSymbols(){
		this.dependencies = (char[][char[]]).init;
		this.moduleName = binary.getName();
		
		debug (DDL) debugLog("binary: %s",binary.toString());
				
		foreach(ExternalSymbol ext; binary.getExterns()){
			if(!ext.isResolved){
//!				dependencies ~= ext.name;
			}
		}
		
		foreach(char[] name,PublicSymbol pub; binary.getPublics()){
			ExportSymbol exp;
			exp.name = pub.name;
			exp.address = pub.address;
			this.exports[pub.name] = exp;
		}
	}
	
	public char[] toString(){
		return binary.toString();
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

    // DynamicModule override
	public void resolveFixups()
    {
    }
	public ExportSymbol[] getSymbols()
    {
        return null;
    }

}
