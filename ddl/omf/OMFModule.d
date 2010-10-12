/+
	Copyright (c) 2005-2007 Eric Anderton, Tomasz Stachowiak
        
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
module ddl.omf.OMFModule;

private import ddl.ExportSymbol;
private import ddl.DynamicModule;
private import ddl.FileBuffer;
private import ddl.Utils;
private import ddl.DDLReader;
private import ddl.ExpContainer;
private import ddl.SymbolLineNumber;

private import ddl.omf.OMFBinary;
private import ddl.omf.OMFException;

// HACK
private import tango.text.convert.Format : sprint = Format;

private import Text = tango.text.Util;
import tango.stdc.stdio;

version(Windows){
	private import ddl.omf.DLLProvider;
}

class OMFModule : DynamicModule{
	struct SegmentImage{
		void[] data;
	}
	
	struct Fixup{
		bool isExternStyleFixup;
		bool isSegmentRelative;
		uint targetSegmentIndex;
		ExportSymbolPtr targetSymbol;
		ExportSymbolPtr destSymbol;
		uint destSymbolOffset;
		void* destSegmentAddress;
	}
	
	alias ExportSymbol* ExportSymbolPtr;
	alias SegmentImage* SegmentImagePtr;

	debug (DDL) OMFBinary binary;
	Fixup[] fixups;
	//ExpContainer!(Fixup) fixups;
	SegmentImage[] segmentImages;
	ExportSymbol[] symbols;
	SymbolLineNumber[] symbolLineNumbers;
	char[] moduleName;
	char[] symNamesBuffer;
	bool resolved;


	public override void makePrivate() {
		delete fixups;
		delete symbols;
		delete symNamesBuffer;
	}

	/**
		TODO
	*/
	public override void unload() {
		foreach (ref seg; segmentImages) {
			delete seg.data;
		}
		delete segmentImages;
		delete moduleName;
	}
	
	
	this(FileBuffer buffer){
		resolved = false;
		loadBinary(new DDLReader(buffer));
	}
		
	this(DDLReader reader){
		resolved = false;
		loadBinary(reader);
	}
	
	public char[] getName(){
		return moduleName;
	}
	
	public ExportSymbol[] getSymbols(){
		return symbols;
	}
	
	public ExportSymbol* getSymbol(char[] name){
		/+if(name in symbolXref) return symbolXref[name];
		else return &ExportSymbol.NONE;+/
		foreach (ref sym; symbols) {
			if (sym.name == name) {
				return &sym;
			}
		}
		
		return &ExportSymbol.NONE;
	}
	
	public override SymbolLineNumber[] getSymbolLineNumbers() {
		return symbolLineNumbers;
	}

	
	protected bool containsAddress(void* addr){
		foreach(seg; this.segmentImages){
			debug (DDL) debugLog("checking addr: [%0.X] [%0.X] [%0.X]",seg.data.ptr,addr,(seg.data.ptr + seg.data.length));
			if(addr >= seg.data.ptr && addr <= (seg.data.ptr + seg.data.length)){
				return true;
			}
		}
		return false;
	}
	
	public void resolveFixups(){
		Fixup[] remainingFixups;
		//ExpContainer!(Fixup) remainingFixups;
		
		foreach(idx,fix; fixups) with(fix){
			/+if (targetSymbol) {
				printf("targetSymbol: %.*s"\n, targetSymbol.name);
			}+/
			
			uint fixupValue;
			uint destAddress;
			
			// get the dest address
			if(destSymbol){
				if(destSymbol.isExternal){
					// discard this fixup - it references a non-local symbol
					debug (DDL) debugLog("Discarded Fixup dest {0}:{1} [{2:X}] rel:{3}",destSymbol.name,destSymbol.getTypeName(),destAddress,cast(uint)isSegmentRelative);
					continue;
				}
				else{
					debug (DDL) debugLog("Fixup dest symbol: {0} [{1:X}] {2}",destSymbol.name,destSymbol.address,destSymbolOffset);
					destAddress = cast(uint)destSymbol.address + destSymbolOffset;
				}
			}
			else{
				destAddress = cast(uint)destSegmentAddress;
			}
			
			if(!containsAddress(cast(void*)destAddress)){
				debug (DDL) debugLog("Module does not contain the destination address for fixup. [{0:X}]",destAddress);
				debug (DDL) debugLog("dump: {0}",this.toString());
				assert(false);
			}
			//assert(containsAddress(cast(void*)destAddress),"Module does not contain the destination address for fixup.");
			
			// get the fixup value
			if(isExternStyleFixup){
				if(targetSymbol.type != SymbolType.Strong){
					// fixup cannot be resolved at this time, so save it for later
					remainingFixups ~= fix;
					//printf("fixup cannot be resolved at this time, so save it for later"\n);
					continue;
				}
				fixupValue = cast(uint)(targetSymbol.address);
			}
			else{
				fixupValue = cast(uint)(segmentImages[targetSegmentIndex].data.ptr);
			}
			
			debug (DDL) if(destSymbol){
				debugLog("fixup dest {0}:{1} [{2:X}] ({3:X}) = fixupValue [{4:X}] rel:{5}",destSymbol.name,destSymbol.getTypeName(),destAddress,*cast(uint*)destAddress,fixupValue,cast(uint)isSegmentRelative);
			}
			else{
				debugLog("fixup dest (null) [{0:X}] ({1:X}) = fixupValue [{2:X}] rel:{3}",destAddress,*cast(uint*)destAddress,fixupValue,cast(uint)isSegmentRelative);
			}
			
			// apply the fixup value
			if(fixupValue == 0){
				//HACK: there exists a very small class of symbols that point to zero at all times
				//NOTE: namely, this includes __except_list and __nullext, which point to the start
				// of their respective segments
				*cast(uint*)destAddress = fixupValue;
			}
			else if(!isSegmentRelative){ // relative fixup, offset by width of field
				*cast(uint*)destAddress = fixupValue - destAddress - 4; 
			}
			else{ // segment relative
				*cast(uint*)destAddress += fixupValue;		
			}
			
			debug (DDL) debugLog("\tfixed to: [{0:X}]",*cast(uint*)destAddress);
		}
		this.fixups = remainingFixups;
	}
	
	public bool isResolved(){
		if(resolved) return true;
		
		if(fixups.length > 0) return false;
		foreach(sym; symbols){
			if(sym.type != SymbolType.Strong) return false;
		}
		resolved = true;
		
		return true;
	}
		
	protected void loadBinary(DDLReader reader){
		ExportSymbolPtr[char[]] symbolXref;

		debug(DDL) {} else{
			OMFBinary binary;
		}
		binary.parse(reader);
								
		//TODO: alter this to zero in on D namespaces and C/asm namespaces
		this.moduleName = binary.libraryName.dup;
		this.moduleName = Text.replace(this.moduleName,'\\','.');
		//debug (DDL) debugLog(moduleName);
		
		// establish segment images and build the cross-reference
		segmentImages.length = binary.segments.length;
		foreach(idx,seg; binary.segments){
			if(idx == 0) continue;
			
			//BSS style segments have no explicit data, so give them some
			if(cast(char[])binary.names[seg.classNameIndex] == "BSS"){
				segmentImages[idx].data.length = seg.dataLength;
			}
		}
				
		//build up symbol table
		//NOTE: extern indicies match their OMF counterparts
		symbols.length = 
			binary.communalExterns.length + 			
			(binary.externs.length-1) + 
			binary.communalDefinitions.length +
			binary.publics.length;
			
		uint symbolIndex = 0; // offset by number of publics (handled later)
		
		// communal external symbols
		foreach(ext; binary.communalExterns){
			ExportSymbolPtr sym = &(symbols[symbolIndex]);
			
			sym.isExternal = false;
			sym.type = SymbolType.Weak;
			sym.name = binary.names[ext.nameIndex];
			symbolXref[sym.name] = sym;
			
			symbolIndex++;
		}		
						
		// external symbols
		foreach(idx,ext; binary.externs){
			if(idx == 0) continue;
			ExportSymbolPtr sym = &(symbols[symbolIndex]);
			
			sym.isExternal = true;
			sym.type = SymbolType.Unresolved;
			sym.name = ext.name;
			symbolXref[sym.name] = sym;
			
			symbolIndex++;
		}
				
		//1st pass for COMDEF records
		//build up the memory image of the referenced segments 
		foreach(idx,comdef; binary.communalDefinitions){	
			// add to the default memory image: segment #0
			segmentImages[0].data.length = segmentImages[0].data.length + comdef.length;			
		}
		
		//2nd pass for COMDEF records
		//establish extern addresses
		void* segZeroAddress = segmentImages[0].data.ptr;
		foreach(idx,comdef; binary.communalDefinitions){
			// create an export symbol
			ExportSymbolPtr sym = &(symbols[symbolIndex]);
			
			sym.isExternal = false;
			sym.type = SymbolType.Weak;
			sym.name = comdef.communalName;
			sym.address = segZeroAddress;
			symbolXref[sym.name] = sym;
			
			symbolIndex++;	
			
			segZeroAddress += comdef.length;
		}			
				
		// get data from iterated records	
		foreach(idx,lidata; binary.iteratedData){
			SegmentImagePtr image = &(segmentImages[lidata.segmentIndex]);
			uint dataLength = lidata.data.length;
			uint offset = lidata.offset;
			
		//	debugLog("lidata range: %0.X .. %0.X",lidata.data.ptr,lidata.data.ptr+dataLength);
			
			// reallocate if needed
			if(image.data.length < offset + dataLength){
				image.data.length = offset + dataLength;
			}
			// copy into the buffer
		//	debugLog("image range: %0.X .. %0.X",image.data.ptr,image.data.ptr+image.data.length);
			image.data[offset..offset+dataLength] = lidata.data;
		}
		
		// get data from enumerated data
		
		foreach(idx,ledata; binary.enumeratedData){
			SegmentImagePtr image = &(segmentImages[ledata.segmentIndex]);
			uint dataLength = ledata.data.length;
			uint offset = ledata.offset;
		//	debugLog("Img: %0.X Images: %0.X",image,segmentImages.ptr);
			
			// reallocate if needed
			if(image.data.length < offset + dataLength){
				image.data.length = offset + dataLength;
			}
			// copy into the bufferdebugLog("image range: %0.X .. %0.X",image.data.ptr,image.data.ptr+image.ata.dlength);
			image.data[offset..offset+dataLength] = ledata.data;
		}
								
		// establish COMDAT temporary address information and segment data
		foreach(idx,comdat; binary.communalData){
			// data to the segment
			SegmentImagePtr image = &(segmentImages[comdat.segmentIndex]);
						
			// set temporary address (offset into the segment image)
			if(!comdat.isContinuation){
				symbolXref[binary.names[comdat.nameIndex]].type = SymbolType.Weak;
				symbolXref[binary.names[comdat.nameIndex]].address = cast(void*)image.data.length;
			}
			
			image.data ~= comdat.data;
		}			

		// fix COMDAT addresses by adding the starting segment address
		foreach(idx,comdat; binary.communalData){
			SegmentImagePtr image = &(segmentImages[comdat.segmentIndex]);
			ExportSymbolPtr symbol = symbolXref[binary.names[comdat.nameIndex]];
			
			if(!comdat.isContinuation){
				symbol.address = cast(void*)(cast(uint)symbol.address + cast(uint)image.data.ptr);
			}
		}		
		
		version (TangoTrace3) {
			foreach (idx, lineSym; binary.comdatLineNumbers) {
				/+ExportSymbolPtr symbol = symbolXref[binary.names[lineSym.nameIndex]];
				assert (symbol !is null);
				symbol.lineNumber = lineSym.lineNumber;+/

				with(lineSym){
					char[] cont = isContinuation ? "(Continuation) " : "";
					char[] name = binary.names[nameIndex];
					
					/+printf("  %d: Line %d --> %.*s%.*s %x\n",
						idx,cast(uint)lineNumber,cont,name,cast(uint)baseOffset);+/
					
					// TODO: optimize my memory usage
					symbolLineNumbers ~= SymbolLineNumber(name.dup, baseOffset, lineSym.lineNumber);
				}
			}
		}

		// public symbols (done here so address offsets are valid)
		foreach(idx,pub; binary.publics){
			ExportSymbolPtr sym = &(symbols[symbolIndex]);
			
			sym.isExternal = false;
			sym.type = SymbolType.Strong;
			sym.name = pub.name;
			symbolXref[sym.name] = sym;
			
			if(segmentImages[pub.segmentIndex].data.length == 0){
				//NOTE: sometimes, a symbol points into an empty segment, and is really
				// attempting to reference the start of the next populated segment within
				// the same group.
				
				// search for the right group
				foreach(grpidx,grp; binary.groups){
					if(grpidx == 0) continue;
					bool tag = false;
					// search for the next populated segment
					foreach(segIndex; grp.segments){
						if(tag){
							if(segmentImages[segIndex].data.length > 0){
								sym.address = segmentImages[segIndex].data.ptr + pub.offset;
								goto done;
							}
						}
						else if(segIndex == pub.segmentIndex){
							tag = true; // tag! The next one is it.
						}
					}
				}
				//NOTE: you can't win them all.  It turns out that there are a family of
				// runtime libary only cases where symbols of this nature cannot be resolved as
				// they are basically pointers to the beginning of a special-use segment of some kind.
				// Thankfully, these symbols exist at runtime, so naming them as Extern here won't 
				// affect runtime linking.
				debug (DDL) debugLog("Cannot resolve segment address for public '{0}'.",cast(char[])pub.name);
				sym.isExternal = true;
				sym.type = SymbolType.Unresolved; // doesn't exist here
			}
			else{
				sym.address = segmentImages[pub.segmentIndex].data.ptr + pub.offset;
			}
			done:
			symbolIndex++;
		}
		
		// build up enough room for the impdef references
		uint zerospaceLength = segmentImages[0].data.length;
		segmentImages[0].data.length = zerospaceLength + binary.impdefs.length * (void*).sizeof;
		void* impSpace = segmentImages[0].data.ptr + zerospaceLength;
		
		version(Windows){
			// impdefs add to the given symbol table
			foreach(imp; binary.impdefs){
				//establish impdef address	
				void* impAddress;
				if(imp.entryName){
					impAddress = DLLProvider.loadModuleSymbol(cast(char[])imp.moduleName,cast(char[])imp.entryName);
				}
				else{
					impAddress = DLLProvider.loadModuleSymbol(cast(char[])imp.moduleName,imp.entryOrdinal);
				}
				
				if(impAddress){
					symbols.length = symbols.length + 1;
					ExportSymbolPtr sym = &(symbols[$-1]);				
					
					sym.isExternal = false;
					sym.type = SymbolType.Strong;
					sym.name = cast(char[])imp.internalName;
					sym.address = impAddress;
					symbolXref[sym.name] = sym;
					
					// establish impspace reference
					symbols.length = symbols.length + 1;
					sym = &(symbols[$-1]);
					
					*(cast(void**)impSpace) = impAddress;
								
					sym.type = SymbolType.Strong;
					sym.name = "__imp_" ~ cast(char[])imp.internalName;
					sym.address = impSpace; //TODO: point into impspace
					symbolXref[sym.name] = sym;
				}
				else{
					//debug (DDL) debugLog("Cannot load %s from %s",cast(char[])imp.internalName,cast(char[])imp.moduleName);
					//debug (DDL) debugLog("  %d %s",imp.entryOrdinal,cast(char[])imp.entryName);
				}
				impSpace += (void*).sizeof;
			}
		}
		
		// process WKEXT records
		foreach(idx,wkext; binary.weakExterns){
			ExportSymbolPtr sym = &(symbols[wkext.weakIndex-1]);
			symbols[wkext.weakIndex-1].type = SymbolType.Weak;
		}
		
		// pre-process FIXUPP records to be used later
		foreach(fix; binary.fixups){
			Fixup newFix;
			newFix.isSegmentRelative = fix.isSegmentRelative;
			newFix.isExternStyleFixup = fix.isExternStyleFixup;
			newFix.destSymbolOffset = 0;
			newFix.destSymbol = null;
			newFix.destSegmentAddress = null;
			
			// resolve the target to a symbol or segment index, dependeing on the fixup style
			if(fix.isExternStyleFixup){
				newFix.targetSymbol = symbolXref[cast(char[])binary.externNames[fix.targetIndex]];
				//printf("new fix %.*s"\n, newFix.targetSymbol.name);
			}
			else{
				newFix.targetSegmentIndex = fix.targetIndex;
			}
			
			if(fix.destNameIndex > 0){
				//TODO: this assumes that these fixups are strong - needs to be loosened so that weak symbols can be resolved (?)
				newFix.destSymbol = symbolXref[binary.names[fix.destNameIndex]];
				newFix.destSymbolOffset = fix.destOffset;
			}
			else{
				newFix.destSegmentAddress = cast(uint*)(segmentImages[fix.destSegmentIndex].data.ptr + fix.destOffset);
			}
			fixups ~= newFix;
		}
		
		// Pack all symbol names together into a new buffer
		
		size_t totalSymNameLength = 0;
		foreach (sym; symbols) {
			totalSymNameLength += sym.name.length;
		}
		
		symNamesBuffer.length = totalSymNameLength;
		size_t curSymNameLength = 0;
		foreach (ref sym; symbols) {
			char[] name2 = symNamesBuffer[curSymNameLength .. curSymNameLength + sym.name.length];
			curSymNameLength += sym.name.length;
			name2[] = sym.name[];
			sym.name = name2;
		}
		
		debug(DDL){} else{
			binary.deleteData();
		}
		
		//printf("%.*s"\n, toString);
	}
	
	char[] toString(){
		char[] result = "";
		//ExtSprintClass sprint = new ExtSprintClass(1024);
		
		debug (DDL) {
			result ~= "\n--OMFBinary Data--\n";
			result ~= binary.toString();
		}
		result ~= "\n--OMFModule Data--\n";
		result ~= "Module: " ~ moduleName ~ "\n\n";
		
		debug(DDL){
			result ~= "Segment Images:\n";		
			foreach(idx,seg; segmentImages){
				if(idx == 0) continue;
				char[] name = binary.names[binary.segments[idx].nameIndex];
				result ~= sprint("  {0}: {1} {2} bytes [{3:X}]\n",idx,name,seg.data.length,seg.data.ptr);
			}
		}
		
		result ~= "Symbols:\n";
		foreach(idx,sym; symbols){
			char[] ext = sym.isExternal ? "external" : "local";
			result ~= sprint("  {0}: [{1:X}] {2} {3} {4}\n",idx,cast(uint)sym.address,sym.getTypeName(),ext,sym.name);
		}
		
		result ~= sprint("Fixups ({0}):\n",fixups.length);
		if(fixups.length > 0){
			foreach(idx,fix; fixups){
				with(fix){
					char[] rel = isSegmentRelative ? "segmentRelative" : "selfRelative";
					char[] ext = isExternStyleFixup ? "externStyle" : "segmentStyle";
							
					result ~= sprint("  {0}: {1} {2}",idx,rel,ext);

					if(destSymbol){
						result ~= sprint(" | {0} [{1:X}]",destSymbol.name,cast(uint)destSymbol.address+destSymbolOffset);
					}
					else{
						result ~= sprint(" | [{0:X}]",cast(uint)destSegmentAddress);
					}					
						
					if(isExternStyleFixup){
						result ~= sprint(" | {0} [{1:X}]",targetSymbol.name,targetSymbol.address);
					}
					else{
						result ~= sprint(" | segment #{0} [{1:X}]",targetSegmentIndex,segmentImages[targetSegmentIndex].data.ptr);
					}
					result ~= "\n";
				}
			}			
		}
		
		result ~= "DATA: \n";
		foreach(idx,segdef; segmentImages){
			char[] buf2 = "";
			result ~= sprint("segment {0} data ({1} bytes): ",idx,segdef.data.length);
			foreach(byteidx,b; cast(ubyte[])(segdef.data)){
				if(byteidx % 16 == 0){
					 result ~= sprint(" |  {0}\n  [{1:X}] ",buf2,segdef.data.ptr+byteidx);
					 buf2 = "";
				}
				if(b < 16) result ~= "0"; //HACK: sprint doesn't left-pad correctly
				result ~= sprint("{0:2X} ",b);
				if(b >= 32 && b <= 126){
					buf2 ~= cast(char)b;
				}
				else{
					buf2 ~= ".";
				}
			}
			result ~= buf2 ~ "\n";
		}
				
		return result;
	}
}
