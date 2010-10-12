/+
	Copyright (c) 2005-2007 Eric Anderton
        
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
module ddl.omf.OMFLibrary;

private import ddl.ExportSymbol;
private import ddl.Attributes;
private import ddl.DynamicLibrary;
private import ddl.DynamicModule;
private import ddl.FileBuffer;
private import ddl.DDLReader;
private import ddl.Utils;

private import ddl.omf.OMFModule;

//private import tango.io.model.IBuffer;
//private import tango.io.model.IConduit;

import tango.io.Stdout;

class OMFLibrary : DynamicLibrary{
	DynamicModule[] modules;
	
	struct SymInfo {
		DynamicModule		mod;
		ExportSymbolPtr	sym;
	}
	SymInfo[char[]] crossReference;
	
	Attributes attributes;

	public this(){
		attributes["omf.filename"] = "<unknown>";
	}
	
	public this(FileBuffer file){
		attributes["omf.filename"] = file.getPath.toString();
		load(file);
	}
		
	public char[] getType(){
		return "OMF";
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
	
	/**
		TODO
	*/
	public override void unload() {
		makePrivate;
		foreach (mod; modules) {
			mod.unload;
		}
		delete modules;
	}

	public ExportSymbolPtr getSymbol(char[] name){
		auto sym = name in crossReference;
		if (sym) return sym.sym;
		else return &ExportSymbol.NONE;
	}
	
	public DynamicModule[] getModules(){
		return this.modules;
	}
		
	public DynamicModule getModuleForSymbol(char[] name){
		debug (DDL) debugLog("[OMF] looking for {0} in {1}",name,attributes["omf.filename"]);
		auto mod = name in crossReference;
		debug (DDL) debugLog("[OMF] Result: {0:X}",mod);
		if (mod) return mod.mod;
		return null;
	}
	
	public ubyte[] getResource(char[] name){
		return (ubyte[]).init;
	}
	
	
	public override void makePrivate() {
		foreach (mod; modules) {
			mod.makePrivate();
		}
		crossReference = crossReference.init;
	}

	
	package void addModule(OMFModule mod){
		this.modules ~= mod;
		auto symbols = mod.getSymbols();
		for(uint i=0; i<symbols.length; i++){
			ExportSymbolPtr exp = &(symbols[i]);
			if (auto found = exp.name in crossReference){
				switch(exp.type){
				case SymbolType.Weak: // replace extern only
					if (found.sym.type == SymbolType.Unresolved){
						found.mod = mod;
						found.sym = exp;
					}
					break;
				case SymbolType.Strong: // always overwrite
					crossReference[exp.name] = SymInfo(mod, exp);
					/+crossReference[exp.name] = mod;
					dictionary[exp.name] = exp;+/
					break;
				default:
					// do nothing
				}
			}
			else{
				/+crossReference[exp.name] = mod;
				dictionary[exp.name] = exp;+/
				crossReference[exp.name] = SymInfo(mod, exp);
			}
		}
	}
		
	protected void load(FileBuffer data){
		ubyte type;
		ushort recordLength;
		uint dictionaryOffset;
		ushort dictionarySize; // size in 512 byte blocks
		ubyte flags;
				
		DDLReader reader = new DDLReader(data);
		
		// read the header section (much of this is thrown out)
		reader.get(type);
				
		assert(type == 0xF0);  // assert OMF library
		
		reader.get(recordLength);
		reader.get(dictionaryOffset);
		reader.get(dictionarySize);
		reader.get(dictionarySize); //NOTE: this is delibarate
		reader.get(flags);
		
		//debug (DDL) debugLog("Dictionary: %0.8X\n",dictionaryOffset);
		
		uint pageSize = recordLength += 3; // adjusted for the first 3 bytes in the header
		
		//debug (DDL) debugLog("recordLength: %d bytes",recordLength);
				
		// skip the padding and proceed to the first page boundary
		reader.seek(pageSize);
		
		// read in object files, and add them to the modules listing
		OMFModule mod;
		while(reader.hasMore()){
			//debug (DDL) debugLog("offset: %0.8X\n",reader.getPosition);
		
			mod = new OMFModule(reader);
			this.addModule(mod);
				
			// advance the remainder of a page
			ulong position = reader.getPosition();
			ulong delta = pageSize - (position % pageSize);
			if(delta != pageSize){
				reader.seek(position + delta);
			}

			// determine if we're at the end of the module list			
			ubyte next;
			reader.peek(next);
			//debug (DDL) debugLog("next: %0.2X\n",next);
			if(next == 0xF1) break; 
		}
		//skip the dictionary (redundant)
	}
	
	public char[] toString(){
		char[] result = "";
		foreach(DynamicModule mod; modules){
			result ~= mod.toString();
		}
		return result;
	}
}

