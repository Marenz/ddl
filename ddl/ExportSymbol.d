/+
	Copyright (c) 2005 Eric Anderton
	
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
	Copyright: 2005 Eric Anderton
*/
module ddl.ExportSymbol;

import ddl.DDLException;

/*
	Determines the resolution status of the symbol
**/
enum SymbolType: ubyte{
	Unresolved = 0, // undefined
	Weak, // defined but can be overriden by another defintion during a linker pass
	Strong, // defined and can be linked against
}

/**
	Defines a symbol within a DynamicModule.
*/
struct ExportSymbol{
	/**
		Determines if the symbol is external to it's containing module.
		
		Local symbols are defined within the memory space controlled by the symbol's module.  If
		a symbol is not local, it considered to be External, meaning that this symbol is merely
		a reference to another symbol.
	*/
	public bool isExternal;
	public bool isLinking;
	public bool isLinked;
	
	/**
		The type of the symbol.
	*/	
	public SymbolType type;
	/** 
		The address of the symbol.
		
		In some very rare cases, this may be a null value.  It is reccomended that the developer test
		against ExportSymbol.init if they wish to determine if an ExportSymbol has been set/defined.
	*/
	
	public void* address;
	/** 
		The name of the symbol.
		
		Invariably, this string will contain the "mangled" name that the compiler generates for
		the symbol.  For D Modules, this will contain a properly mangled D symbol, per the D ABI.
		
		C symbols are usually exported as an underscore followed by the identifier as it reads in
		the source-code.  For C++, ASM and other languages, the results are much more varied and are usually
		compiler dependent.  It is not reccomended to code against these types of symbols literally
		if it can be at all avoided.
	*/
	public char[] name;

	/** 
		Returns the resolution status of this symbol.
		
	**/
	bool isResolved(){
		return type == SymbolType.Strong;
	}

	/**
	        Can be used as an empty symbol, e.g. 
	            return ExportSymbol.NONE;
	*/
	static const ExportSymbol NONE;
	
	/**
		Returns a friendly name for the type of symbol, based on it's 'type' member.
	*/
	char[] getTypeName(){
		switch(type){
		case SymbolType.Strong: return "strong";
		case SymbolType.Weak: return "weak";
		case SymbolType.Unresolved: return "unresolved";
		default:
			return "unknown";
		}
	}
}

alias ExportSymbol* ExportSymbolPtr;