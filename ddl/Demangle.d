/+
	Copyright (c) 2005-2006 Eric Anderton
	        
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
	Provides support for parsing and decoding D's name mangling syntax. 
	Wraps std.demangle from phobos.
	
	Authors: Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005-2006 Eric Anderton
*/
module ddl.Demangle;

//private import etc.demangle;
import tango.core.tools.Demangler;

debug (DDL) private import ddl.Utils;

/**
	The type of symbol that is represented by a given mangled name.
	
	Any ordinary type of symbol that doesn't match a D symbol, or a D special symbol
	is merely of type 'PublicSymbol'.
*/
enum DemangleType{
	PublicSymbol,
	PublicDSymbol,
	ModuleInfo
}


/**
	Parses a mangled D symbol and returns the equivalent D code to match the symbol.
	
	Params:
		symbol = The mangled D symbol.
		
	Returns:
		A D code representation of the symbol.
*/
public char[] demangleSymbol(char[] symbol)
{
	return demangler.demangle(symbol);
}

bool startsWith(char[] value,char[] test){
	return value.length >= test.length && value[0..test.length] == test;
}

bool endsWith(char[] value,char[] test){
	return value.length >= test.length && value[$-test.length .. $] == test;
}

/**
	Parses a mangled D symbol and returns its DemangleType.
	
	Params:
		symbol = The mangled D symbol.
		
	Returns:
		The DemangleType for the symbol.
*/
public DemangleType getDemangleType(char[] symbol){
	if (symbol.endsWith("__ModuleInfoZ")) {
		return DemangleType.ModuleInfo;
	}
	else if(symbol.startsWith("_D")){
		return DemangleType.PublicDSymbol;
	}
	// no particular type, default the symbol to a 'public'
	return DemangleType.PublicSymbol;
}

/**
	 Decomposes mangled D namespaces into an array of names.
	 
	 The array of namespaces is called a "namespace chain".
	 
	 Params:
	 	mangled: (inout) a mangled D namespace.
	 
	 Return: Returns a namespace chain that is equivalent to the mangled input.
*/
public char[][] parseNamespaceChain(inout char[] mangled){
	char[][] chain;
	uint ate;
	uint len;

	while(mangled.length > 0){
		ate = 0;
		len = 0;	
		while(mangled[ate] >= '0' && mangled[ate] <= '9'){
			len = (len*10) + (mangled[ate] - '0');
			ate++;
		}
		if(ate == 0) break;
		chain ~= mangled[ate..ate+len];
		mangled = mangled[ate+len..$];
	}
	return chain;
}

/**
	Combines a namespace chain into a dot ('.') separated namespace.
	
	Params:
		chain: A namespace chain to convert.
	
	Return: A dot-sepearated version of the original chain.
*/
public char[] toNamespace(char[][] chain){
	char[] result = chain[0];
	for(uint i=1; i<chain.length; i++){
		result ~= "." ~ chain[i];
	}
	return result;
}

