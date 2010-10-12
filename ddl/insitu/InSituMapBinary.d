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
module ddl.insitu.InSituMapBinary;

private import ddl.ExportSymbol;
private import ddl.FileBuffer;
private import ddl.insitu.InSituBinary;

private import Text = tango.text.Util;

debug (DDL) private import tango.io.Stdout;

/* Binary 'file' for DMD map files */

class InSituMapBinary : InSituBinary{
	ExportSymbol[char[]] allSymbols;

	struct LineIterator{
		char[][] lines;
		uint position;
		
		static LineIterator opCall(char[] data){
			LineIterator _this;
			_this.lines = Text.splitLines(data);
			_this.position = 0;
			return _this;
		}
		
		char[] getNext(){
			position++;
			return lines[position-1];
		}
		
		bool hasMore(){
			return position < lines.length;
		}
	}
		
	public this(){
		//do nothing
	}
		
	public void load(FileBuffer file){
		LineIterator iter = LineIterator(cast(char[])file.data);
				
		parseSegmentDefinitions(iter);
		parseExports(iter);
		parsePublicsByName(iter);	
		// throw away the publics by address
		
		version(Windows){
			//HACK: add in parts to make DMD/OMF linking work correctly
			//NOTE: blindly pulling in all 'Abs' symbols doesn't work as well as it should
			ExportSymbol sym;
			
			// __nullext - placeholder for the start of static init for modules
			sym.address = null;
			sym.name = "__nullext";
			sym.type = SymbolType.Strong;
			allSymbols[sym.name] = sym;
			
			// __except_list - placeholder for the start of the exception handling list in FS
			sym.address = null;
			sym.name = "__except_list";
			sym.type = SymbolType.Strong;
			allSymbols[sym.name] = sym;
		}
	}
	
	public ExportSymbol[char[]] getAllSymbols(){
		return allSymbols;
	}
	
	public void setAllSymbols(ExportSymbol[char[]] newSymbols){
		allSymbols = newSymbols;
	}
	
	protected void parseSegmentDefinitions(inout LineIterator iter){
		char[] line;
		line = iter.getNext(); // throw away the first line (blank)
		line = iter.getNext(); // throw away the second line (header)
		
		// read until there's a blank line
		while(iter.hasMore){
			line = iter.getNext(); 
			if(line.length == 0) break;
		}
	}
	
	protected void parseExports(inout LineIterator iter){
		char[] line;
		
		// parse exports section if the header matches correctly
		line = iter.getNext();
						
		//HACK: the difference between the presence of an exports section in the .map
		// file is determined by the token " Address" at the start of the line.
		// if no exports section is present, this is reliably output (probably by mistake)
		// as "   Address" (note the extra spaces) instead.
		if(line[0..8] == " Address"){			
			line = iter.getNext();  // throw away the second line (blank)
			while(iter.hasMore){ // throw out all non blank lines until a blank is encountered
				line = iter.getNext(); 
				if(line.length == 0) break;
			}
			line = iter.getNext(); // throw out the following header (publics)
		}
		line = iter.getNext();  // throw away the second line (blank)
	}
	
	protected void parsePublicsByName(inout LineIterator iter){
		char[] line;
		
		// read until there's a blank line
		while(iter.hasMore){
			line = iter.getNext();
			if(line.length == 0) break;
							
			uint rva;
					
			// throw away the address (first nine chars) 
			if(line[14..21] == "  Imp  ") continue; // throw this away! We want the '__imp__' version instead.
			if(line[14..21] == "  Abs  ") continue; // this isn't needed either
					
			// parse out the symbol
			line = line[21..$];
			uint pos = 0;
			while(line[pos] != ' ') pos++;
			char[] symbol = line[0..pos].dup; // get a copy
			
			// parse whitespace (variable length)
			while(line[pos] <= 32) pos++;
			
			// parse out the hexadecimal RVA (until newline)
			line = line[pos..$];
			assert(line.length == 8);
			pos = 0;
			while(pos < 8){
				char ch = line[pos];
				if(ch >= '0' && ch <='9'){
					rva = (rva * 16) + cast(uint)(ch - '0');
				}
				else if(ch >= 'a' && ch <= 'f'){
					rva = (rva * 16) + (cast(uint)(ch - 'a') + 10);
				}
				else if(ch >= 'A' && ch <= 'F'){
					rva = (rva * 16) + (cast(uint)(ch - 'A') + 10);
				}
				else{
					break;
				}
				pos++;
			}
			
			// add to all symbols
			ExportSymbol sym;
			sym.address = cast(void*)rva;
			sym.name = symbol;
			sym.type = SymbolType.Strong;
						
			allSymbols[sym.name] = sym;
			
			// break the symbol down to what we want if it is an implib symbol
			if(symbol.length > 6 && symbol[0..6] == "__imp_"){
				// get the 'friendly' name of the symbol
				pos = 0;
				while(symbol[pos] != '@') pos++;
				sym.name = symbol[6..pos];
				
				// redirect (hey, we're in-situ, right?) to the actual address	
				sym.address = cast(void*)rva;
				
				allSymbols[sym.name] = sym;				
			}			
		}		
	}
}