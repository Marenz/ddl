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
module ddl.DynamicModule;

private import ddl.ExportSymbol;
private import ddl.Attributes;
private import ddl.Mangle;
private import ddl.SymbolLineNumber;

private import tango.util.log.Trace;


//TODO: change so that a module yields what modules namespaces it depends on, if possible.
//TODO: add a way to delay the actual resolution to a separate call, as to optimize the linker
//TODO: find a way for the module to return its namespace

/** 
	Represents a binary module within DDL.
	
	Once a module is loaded, it is techncially not usable until all of its internal fixups
	and external dependencies are resolved.  Resolution is performed via the resolveDependency and 
	resolveDependencies methods.  
*/
abstract class DynamicModule{
	
	/** 
	 	Returns the name of the module.
	
		While the result of getName() is largely compiler dependent for .asm or .c 
		based binary files, D compilers reliably use the file name with the '.d' file extension
		for the name of the module.
		
		For D modules, the name of the module should look like a module namespace followed 
		by .d (eg. "my.name.space.moduleName.d" or "ddl.DynamicModule.d")
	
		Returns: the module's name
	*/
	public char[] getName();

	/**
		This implementation depends on the behavior of getName().  Implementers may wish to 
		override this method if that is unacceptable or may yield unpredicable results.
		
		Returns: the namespace for this module, if there is one, or an empty string if not.
	*/
	public char[] getNamespace(){
		char[] name = getName();
		if(name.length > 2 && name[$-2..$] == ".d"){
			return name[0..$-2];
		}
		return "";
	}
		
	/**
		The value returned by this method is the raw namespace (eg. "3std6foobar"), which is the 
		same format used for all D symbols.  As D symbols are declared along with their namespace,
		the value returned by this method is intended to assist in the location of those symbols.	
		
		This implementation depends on the behavior of getNamespace() and consequently getName().  
		Implementers may wish to override this method if that is unacceptable or may yield 
		unpredicable results.
		
		Returns: the raw D namespace for this module, if there is one, or an empty string if not.
	*/
	public char[] getRawNamespace(){
		return mangleNamespace(getNamespace);
	}
	
	/**
		Looks for a symbol of the form "static const char[][char[]] {namespace}.DDLAttributes",
		and returns it if it exists.  Note that the module does not have to be resolved for this
		to work correctly.  However, the module author is trusted to not have populated the
		attribute map with references to static data not present in the module.
		
		Note: The current rendition of D, at the time of this documentation, does not support
		static intialization of associative arrays.  This feature is here as a placeholder for
		when D has support for such things.
	
		Returns: the DDLAttributes constant in the module if it exists.
	*/
	public Attributes getAttributes(){
		ExportSymbol* symbol = getSymbol("_D" ~ getRawNamespace() ~ "13DDLAttributesHAaAa");
		if(*symbol == ExportSymbol.NONE){
			return Attributes.init;
		}
		return *cast(Attributes*)symbol.address;
	}

	/**
		Returns the set of all symbols for the module.
	*/
	public ExportSymbol[] getSymbols();
	
	/**
		Gets a specific export by name.  If the export does not exist, the method returns ExportSymbol.init.
	*/
	public ExportSymbolPtr getSymbol(char[] name);
	
	/**
	*/
	public SymbolLineNumber[] getSymbolLineNumbers();
	
	/**
		Prods the module to resolve any pending fixups.  Used during linking.
	*/
	public void resolveFixups();
	
	/**
		Returns the current resolution state of the module.
		
		Generally speaking, isResolved is false if there are still external symbols (dependencies to 
		resolve.  If all these dependencies are resolved, then isResolved returns true.
		
		It is ill-advised to attempt to use any symbols returned from a DynamicModule in an interactive
		way (binding to functions and so-forth) if the module is not completely resolved.  To do otherwise
		is undefined and could easily result in a protection-fault/segmentation-fault.
	*/
	public bool isResolved(); 
	
	/**
		Determines if the module is being linked.
		
		This field determines the current link state of the module.
		It is used exclusively during link procedures as a stop-gap against revisiting the same module
		during a full link.
		
		If true, the module is being linked.  If false, the module is not being linked.
	*/
	public bool isLinking;
	

	/**
		TODO
	*/
	public void unload() {
	}

	
	/**
		Removes lookup data to reduce memory usage.
		
		It may be called when linking is done to free all lookup tables and only leave memory allocated
		for the module's code and data. It will not be possible to get any symbols from the module once 
		makePrivate has been called.
	*/
	public void makePrivate() {
	}


	/+~this() {
		Trace.formatln("* " ~ this.classinfo.name ~ " dtor called");
	}+/
}

