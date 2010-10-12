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
    Authors: Lars Ivar Igesund, Eric Anderton
    License: BSD Derivative (see source for details)
    Copyright: 2005-2006 Lars Ivar Igesund
*/
module ddl.elf.ELFModule;

private import ddl.Utils;
private import ddl.DynamicModule;
private import ddl.ExportSymbol;
private import ddl.FileBuffer;
private import ddl.Attributes;
private import ddl.SymbolLineNumber;

private import ddl.elf.ELFBinary;
private import ddl.elf.ELFHeaders;
private import ddl.elf.ELFReader;
private import ddl.elf.ELFPrinter;

/**
	An implementation of the abstract class DynamicModule for use 
	with ELF (Executable and Linkable Format) object files. 
 */
class ELFModule : DynamicModule
{
	struct SegmentImage
	{
		void[] data;
	}

	alias ExportSymbol* ExportSymbolPtr;
	alias SegmentImage* SegmentImagePtr;

	struct Fixup
	{
		bool isSegmentRelative;
		uint destSectIdx;
		uint destSymbolOffset;
		uint fixupValue;
		ExportSymbolPtr targetSymbol;
		uint type;
	}

	Fixup[] fixups;
	SegmentImage[] segmentImages;
	ExportSymbol[] symbols;
	ExportSymbolPtr[char[]] symbolXref;
	char[] moduleName;
	bool resolved;

	debug (DDL) ELFBinary binary;

	this(FileBuffer buffer)
	{
		resolved = false;
		loadBinary(new ELFReader(buffer));
	}

	this(ELFReader reader)
	{
		resolved = false;
		loadBinary(reader);
	}

	public char[] getName()
	{
		return moduleName;
	}

	public void setName(char[] name)
	{
		if (moduleName is null)
			moduleName = name;
	}

	public ExportSymbol[] getSymbols()
	{
		return symbols;
	}

	public ExportSymbol* getSymbol(char[] name)
	{
		if (name in symbolXref) 
		{
			return symbolXref[name];
		}
		else 
		{
			return &ExportSymbol.NONE;
		}
	}


	public override SymbolLineNumber[] getSymbolLineNumbers() 
	{
		SymbolLineNumber[] ret = new SymbolLineNumber[1];
		return ret;
	}


	public void resolveFixups()
	{
		Fixup[] remainingFixups;

		/*
			 ubyte[] secUbyteData = cast(ubyte[])segmentImages[13].data;

			 debug (DDL) {
			 uint l = 0;
			 for (int j=0; j<8; j++) {
			 Stdout.format ("    {:x8}: ", cast(uint)(secUbyteData.ptr + j*16));
			 for (int i=j*16; i<(j+1)*16 && i < secUbyteData.length; i++) {
			 Stdout.format ("{:x2} ", secUbyteData[i]);
			 }
			 Stdout.newline();
			 }
			 }
		 */

		foreach (idx,fix; fixups) with(fix) 
		{
			if (fix.type == R_386_RELATIVE) 
			{
				debug (DDL) debugLog("relocation: in sect {:d3} at {:x8} using [base relative]", destSectIdx, destSymbolOffset);

			}
			else if (type == R_386_GLOB_DAT || type == R_386_JMP_SLOT || type == R_386_PLT32) 
			{
				debug (DDL) debugLog("relocation: in sect {:d3} at {:x8} using {:x8}", destSectIdx, destSymbolOffset, fixupValue); 

			}
			/+
			else if (type == R_386_GOT32 || type == R_386_GOTPC || type == R_386_GOTOFF) {
				// do nothing at all
				continue;

			} +/
			else 
			{
				debug (DDL) debugLog("relocation: in sect {:d3} at {:x8} using {:x8} {} {}", destSectIdx, destSymbolOffset, targetSymbol.address, targetSymbol.getTypeName, targetSymbol.name);
			}

			uint* dest = cast(uint*)(this.segmentImages[destSectIdx].data.ptr + destSymbolOffset);

			if (fix.type == R_386_32 || fix.type == R_386_PC32) 
			{
				if(targetSymbol.type != SymbolType.Strong)
				{
					remainingFixups ~= fix;
					continue;
				}				
			}

			if (type == R_386_32) 
			{
				*dest += cast(uint)targetSymbol.address;

			} 
			else if (type == R_386_PC32) 
			{
				//				debugLog("oh hi! {} {:x8}" cast(uint)(targetSymbol.address) + *dest - dest));
				*dest = cast(int)(targetSymbol.address) + *dest - cast(uint)(dest);

			} 
			else if (type == R_386_GLOB_DAT || type == R_386_JMP_SLOT || type == R_386_PLT32) {
				debug (DDL) debugLog("setting value {} ", fixupValue);
				*dest = fixupValue;

			}
			else if (type == R_386_RELATIVE) 
			{
				/* FIXME: check if this is ok */
				debug (DDL) debugLog("setting {:x8} {:x8} value {} ", this.segmentImages[destSectIdx].data.ptr, destSymbolOffset, this.segmentImages[0].data.ptr);
				*dest = cast(uint)(this.segmentImages[0].data.ptr); 
				/*} else if (type == R_386_TLS_LE) {
					debug (DDL) debugLog ("shit, dunno what to do, let's set to 0xCCCCCCCC :>");
				 *dest = 0xCCCCCCCC;
				 */
		}
			else 
			{
				assert(false, "whoa! I shouldn't be here!");
			}
		}

		/*
			 secUbyteData = cast(ubyte[])segmentImages[13].data;
			 debug (DDL) {
			 l = 0;
			 for (int j=0; j<8; j++) {
			 Stdout.format ("    {:x8}: ", cast(uint)(secUbyteData.ptr + j*16));
			 for (int i=j*16; i<(j+1)*16 && i < secUbyteData.length; i++) {
			 Stdout.format ("{:x2} ", secUbyteData[i]);
			 }
			 Stdout.newline();
			 }
			 }
		 */

		this.fixups = remainingFixups;
	}

	import tango.util.log.Trace;

	/// Returns a slice of the zero-terminated cString passed in, as a D-String.
	protected char[] toDString(char* cString)
	{
		uint i = 0;
		while(cString[i] != '\0') i++;

		//			Trace.formatln("==={}",cString[0..i]);

		return cString[0..i];
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

	protected void loadBinary(ELFReader reader){
		debug(DDL){} else{
			ELFBinary binary;
		}
		binary = new ELFBinary();
		binary.parse(reader);

		//		debug (DDL) debugLog(binary.toString());

		if (binary.isDModule) 
		{
			moduleName = binary.moduleName.dup ~ ".d";
		} 
		else 
		{
			moduleName = null;
		}

		debug (DDL) debugLog("rawBinName: {}", this.getRawNamespace);

		debug (DDL) debugLog("allocating segments: {} ", binary.sechdrs.length);

		// additional segment for external undefined symbols
		this.segmentImages.length =  binary.sechdrs.length + 1;
		foreach (idx, sect; binary.sechdrs) {
			// first section is always SHT_NULL, skip it
			if (idx == 0) continue;

			if (sect.sh_size) {
				this.segmentImages[idx].data = binary.secData[idx];
			}
		}

		// that '4' should be rather pointer size on specific architecture
		int extSymbolsSegmentIdx = binary.sechdrs.length;
		this.segmentImages[extSymbolsSegmentIdx].data.length = binary.globalExternSymbols.length * 4; 

		/* allocate space and setup symbols */
		uint symbolIndex = 0;
		symbols.length =
			binary.globalSymbols.length +
			binary.globalExternSymbols.length +
			binary.localSymbols.length +
			binary.weakSymbols.length;

		debug (DDL) debugLog ("allocated space for symbols: {}", symbols.length);
		debug (DDL) debugLog ("adding local symbols");

		/* all local symbols are strong */
		foreach(localName, localSymbol; binary.localSymbols)
		{
			ExportSymbolPtr sym = &(symbols[symbolIndex]);

			sym.isExternal = false;
			sym.type = SymbolType.Strong;
			sym.name = localName;

			if (localSymbol.st_shndx < extSymbolsSegmentIdx) 
			{
				sym.address = this.segmentImages[localSymbol.st_shndx].data.ptr + localSymbol.st_value;
			}

			debug (DDL) debugLog (" --+ adding local symbol: {:x8} {}", sym.address, localName);

			symbolXref[sym.name] = sym;
			symbolIndex++;
		}

		foreach(weakName, weakSymbol; binary.weakSymbols){
			ExportSymbolPtr sym = &(symbols[symbolIndex]);

			sym.isExternal = false;
			sym.name = weakName;
			sym.type = SymbolType.Weak;

			if (weakSymbol.st_shndx < extSymbolsSegmentIdx) {
				sym.address = this.segmentImages[weakSymbol.st_shndx].data.ptr + weakSymbol.st_value;
			}

			debug (DDL) debugLog (" --+ adding weak symbol: {:x8} {}", sym.address, weakName);

			symbolXref[sym.name] = sym;
			symbolIndex++;
		}

		foreach(globalName, globalSymbol; binary.globalSymbols){
			ExportSymbolPtr sym = &(symbols[symbolIndex]);

			sym.isExternal = false;
			sym.name = globalName;
			//sym.address = globalSymbol.

			if (globalSymbol.type == STT_NOTYPE) {
				sym.type = SymbolType.Unresolved;

			} else {
				sym.type = SymbolType.Strong;

				// FIXME !!! XXX !!! FIXME
				if (globalSymbol.st_shndx < extSymbolsSegmentIdx) {
					sym.address = this.segmentImages[globalSymbol.st_shndx].data.ptr + globalSymbol.st_value;
				} 
			}

			debug (DDL) debugLog(" --+ nam: {:d4} {:x8} val: {:x8} siz: {:d4} nfo: {} oth: {} ndx: {:d2} {} {} {}", 
					globalSymbol.st_name,
					sym.address,
					globalSymbol.st_value,
					globalSymbol.st_size,
					globalSymbol.st_info,
					globalSymbol.st_other,
					globalSymbol.st_shndx,
					globalSymbol.getBindName,
					globalSymbol.getTypeName,
					globalName);

			symbolXref[sym.name] = sym;
			symbolIndex++;
		}

		int globalExternSymbolIdx = 0;
		foreach(globalName, globalSymbol; binary.globalExternSymbols){
			ExportSymbolPtr sym = &(symbols[symbolIndex]);

			sym.isExternal = false;
			sym.name = globalName;
			//			sym.address = segmentImages[extSymbolsSegmentIdx].data.ptr + globalExternSymbolIdx*4; 

			debug (DDL) debugLog(" --+ EXT nam: {:d4} {:x8} val: {:x8} siz: {:d4} nfo: {} oth: {} ndx: {:d2} {} {} {}", 
					globalSymbol.st_name,
					sym.address,
					globalSymbol.st_value,
					globalSymbol.st_size,
					globalSymbol.st_info,
					globalSymbol.st_other,
					globalSymbol.st_shndx,
					globalSymbol.getBindName,
					globalSymbol.getTypeName,
					globalName);

			globalExternSymbolIdx++;

			symbolXref[sym.name] = sym;
			symbolIndex++;
		}

		auto stringTable = binary.getStringsTable();
		foreach(sectNum, thisSection; binary.sechdrs){
			if (binary.relocations[sectNum] !is null) {
				auto bindNum = thisSection.sh_info;
				debug (DDL) debugLog ("relocation section {} is binded with section {}", sectNum, bindNum);
				//debugLog ("binded section starts at: {:x8} {} ", secData[bindNum].ptr);
				//debugLog ("section {} starts at: {:x8} {}", sectNum, secData[sectNum].ptr, toDString(&this.shnames[thisSection.sh_name]));
				//      		get associated section
				/*
					 ubyte[] secUbyteData = cast(ubyte[])segmentImages[bindNum].data;
					 uint l = 0;
					 for (int j=0; j<8; j++) {
					 Stdout ("    ");
					 for (int i=j*16; i<(j+1)*16 && i < secUbyteData.length; i++) {
					 Stdout.format ("{:x2} ", secUbyteData[i]);
					 }
					 Stdout.newline();
					 }
				 */

				debug (DDL) debugLog("analyzing relocations...");
				foreach(rel; binary.relocations[sectNum])
				{
					Fixup newFix;

					newFix = Fixup.init;

					debug (DDL) debugLog("{} {} ", rel.type, rel.getType);
					assert(rel.type == R_386_32 ||
							rel.type == R_386_PC32 ||
							rel.type == R_386_RELATIVE ||
							rel.type == R_386_GLOB_DAT ||
							rel.type == R_386_JMP_SLOT
							//|| rel.type == R_386_GOT32 || rel.type == R_386_GOTPC || rel.type == R_386_GOTOFF || rel.type == R_386_PLT32,
							//|| rel.type == R_386_TLS_LE,
							, "unhandled relocation type");

					char* symName;
					auto sym = binary.symbols[rel.sym];
					uint temp;
					if (sym.type == STT_SECTION) 
					{
						symName = &binary.shnames[binary.sechdrs[sym.st_shndx].sh_name];
						temp = rel.sym;

					} else 
					{
						symName = &stringTable[sym.st_name];
						if(*symName  == '\0')
						{	
							debugLog("smy index: {}, binding {},type {} index: {}, val: {} ",sym.st_name,sym.getBindName,sym.getTypeName,sym.getIndex,sym.st_value);
							continue;
						}
						temp = sym.st_shndx; 
					}

					debug (DDL) debugLog("{:x8} {} sym: {:d6} {} {} ", rel.r_offset, rel.getType, rel.sym, temp, toDString(symName));

					if (rel.type == R_386_RELATIVE) 
					{
						newFix.isSegmentRelative = true;
					} 
					else if (rel.type == R_386_GLOB_DAT || rel.type == R_386_JMP_SLOT || rel.type == R_386_PLT32) 
					{
						newFix.fixupValue = sym.st_value;
					}
					/* else if (rel.type == R_386_GOT32 || rel.type == R_386_GOTPC || rel.type == R_386_GOTOFF) {
					// let's skip it

					} */
					else 
					{
						/* @html symName is '\0' when the Array index out of bounds happens.
						         adding the commented lines fixes _this_ error, but
						         an other one shows up. and I have the feeling that this 
						         is just a sympthom error and the source lies somewhere
						         else.
						*/
						if(auto s = toDString(symName) in symbolXref)
							newFix.targetSymbol = *s;
						else
							assert(false,toDString(symName));
//					newFix.targetSymbol = symbolXref[toDString(symName)];

					}
					newFix.destSectIdx = bindNum;
					newFix.destSymbolOffset = rel.r_offset;
					newFix.type = rel.type;

					fixups ~= newFix;
				}

			}

		}
	}


	char[] toString()
	{
		char[] result = "";

		debug(DDL)
			result = "ELF Binary Data: \n" ~ binary.toString();

		return result;
	}
}
