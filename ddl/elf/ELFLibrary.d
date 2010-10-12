/+
    Copyright (c) 2005-2007 Lars Ivar Igesund, Eric Anderton

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
    Authors: Lars Ivar Igesund
    License: BSD Derivative (see source for details)
    Copyright: 2005-2006 Lars Ivar Igesund
*/
module ddl.elf.ELFLibrary;

private import ddl.DynamicLibrary;
private import ddl.DynamicModule;
private import ddl.ExportSymbol;
private import ddl.Attributes;
private import ddl.Utils;
private import ddl.FileBuffer;

private import ddl.elf.ELFHeaders;
private import ddl.elf.ELFModule;
private import ddl.elf.ELFPrinter;

//private import tango.io.Exception;
//private import tango.io.model.IBuffer;
//private import tango.io.model.IConduit;

/**
    An implementation of the abstract class DynamicLibrary for use 
    with libraries of ELF (Executable and Linkable Format) object
    files. 
*/
class ELFLibrary : DynamicLibrary
{
	DynamicModule[] modules;
	DynamicModule[char[]] crossReference; // modules by symbol name
	ExportSymbolPtr[char[]] dictionary; // symbols by symbol name
	Attributes attributes;

	public this()
	{
		debug (DDL) debugLog("NEW ELF LIB NEW ELF LIB NEW ELF LIB NEW ELF LIB ");
		attributes["elf.filename"] = "<unknown>";
	}

	public this(FileBuffer file)
	{
		debug (DDL) debugLog("NEW ELF LIB NEW ELF LIB NEW ELF LIB NEW ELF LIB ");
		attributes["elf.filename"] = file.getPath.toString();
		load(file);
	}

	public char[] getType()
	{
		return "ELFLIB";
	}

	public Attributes getAttributes()
	{
		return attributes;
	}

	package void setAttributes(Attributes other)
	{
		other.copyInto(this.attributes);
	}

	package void setAttribute(char[] key,char[] value)
	{
		this.attributes[key] = value;
	}

	public ExportSymbolPtr getSymbol(char[] name)
	{
		ExportSymbolPtr* sym = name in dictionary;
		debug (DDL) debugLog("loading symbol: {}", name);

		/*
		ubyte[] table = cast(ubyte[])(*sym).address[0 .. 40];
		foreach (onebl; table) {
			debugLog ("{:x2} ", onebl);
		}
		*/
		if(sym) return *sym;
		else    return &ExportSymbol.NONE;
	}

	public DynamicModule[] getModules()
	{
		return this.modules;
	}

	public DynamicModule getModuleForSymbol(char[] name)
	{
		debug (DDL) debugLog("[ELFLIB] looking for " ~ name);
		DynamicModule* mod = name in crossReference;
		debug (DDL) debugLog("[ELFLIB] Result: {:X8}",mod);
		if(mod) return *mod;
		return null;
	}

	public ubyte[] getResource(char[] name)
	{
		return (ubyte[]).init;
	}

	package void addModule(ELFModule mod)
	{
		this.modules ~= mod;
		auto symbols = mod.getSymbols();

		debug (DDL) debugLog("printing crossreference, there seems to be a problem with that:");
		foreach(dupa; crossReference)
			debug (DDL) debugLog("got {} in CR", dupa);

		debug (DDL) debugLog("loading module: {} [symbols count: {}]", mod.getName, symbols.length);
		for(uint i=0; i<symbols.length; i++){
			ExportSymbolPtr exp = &(symbols[i]);
			if(exp.name in crossReference){
				debug (DDL) debugLog("[    in xref] type: {} sym: {}", exp.type, exp.name);
				switch(exp.type){
				case SymbolType.Weak: // replace extern only
					if(dictionary[exp.name].type == SymbolType.Unresolved){
						crossReference[exp.name] = mod;
						dictionary[exp.name] = exp;
					}
					break;
				case SymbolType.Strong: // always overwrite
					crossReference[exp.name] = mod;
					dictionary[exp.name] = exp;
					break;
				default:
					// do nothing
				}

			} else {
				debug (DDL) debugLog("[not in xref] type: {} sym: {}", exp.type, exp.name);

				crossReference[exp.name] = mod;
				dictionary[exp.name] = exp;
			}
		}
	}

	protected void load(FileBuffer data)
	{
		//TODO
	}

	public char[] toString(){
		char[] result;

		foreach(mod; modules){
			result ~= mod.toString();
		}
		return result;
	}
}
