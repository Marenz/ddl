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
    Copyright: 2005-2006 Lars Ivar Igesund, Eric Anderton
*/
module ddl.elf.ELFBinary;

private import ddl.ExportSymbol;
private import ddl.Attributes;
private import ddl.Utils;
private import ddl.DDLException;

private import ddl.elf.ELFHeaders;
private import ddl.elf.ELFReader;
private import ddl.elf.ELFPrinter;

//private import tango.io.model.IBuffer;
//private import tango.io.model.IConduit;

private import tango.text.convert.Integer;


class ELFBinary
{
    public:
	Elf32_Ehdr* elfhdr;
	Elf32_Shdr[] sechdrs;
	Elf32_Phdr[] proghdrs;
	Elf32_Sym[char[]] globalSymbols, globalExternSymbols;
	Elf32_Sym[char[]] localSymbols;
	Elf32_Sym[char[]] weakSymbols;

	Elf32_Sym[] symbols;
	Elf32_Rel[][] relocations;
	void[][] secData;

	char[] shnames;
	char[] dynsymnames;
	char[] symtabnames;
	char[] moduleName;

	bool dynamic;
	bool isDModule;

	private void* bitslab;
	private uint slabsize;
	private uint symbolSectionIdx;

	this(){
	}


	// shim to help with array generation
	private T[] ptrArray(T)(uint offset,uint len){
	    return (cast(T*)(this.bitslab + offset))[0..len];
	}

	/**
	  Loads an ELF object file from the provided reader.

Params: reader = an ELFReader object containing the data to
be read
	 */
	void parse(ELFReader reader){
	    void[] data;
	    reader.getAll(data);
	    this.slabsize = data.length;
	    this.bitslab = data.ptr;

	    // Read ELF Header
	    elfhdr = cast(Elf32_Ehdr*)bitslab;

	    // Checking sanity of ELF magic string
	    if(elfhdr.e_ident[0..4] != cast(ubyte[])"\x7fELF"){
		throw new DDLException("Not a valid ELF Object file");
	    }

	    // Check the ELFCLASS
	    switch (elfhdr.e_ident[EI_CLASS]) {
		case ELFCLASSNONE:
		    throw new DDLException("Invalid ELFCLASS");
		    break;
		case ELFCLASS32:
		    // Do nothing, it is the only currently supported path according to the docs, but it sounds strange ... maybe the document is old
		    break;
		case ELFCLASS64:
		    throw new DDLException("ELFCLASS64 is not implemented and currently not defined");
		    break;
		default:
		    throw new DDLException("Unknown ELFCLASS");
		    break;
	    }

	    // Check how data is encoded 
	    if (elfhdr.e_ident[EI_DATA] == ELFDATANONE) {
		throw new DDLException("Invalid data encoding.");
	    }

	    // Check the version of the specification the file use
	    uint elfversion = elfhdr.e_ident[EI_VERSION];
	    if (elfversion == EV_NONE || elfversion > EV_CURRENT) {
		throw new DDLException("Invalid specification version.");
	    }
	    else if (elfversion > DDL_ELFVERSION_SUPP) {
		throw new DDLException("This version of the specification is still to be implemented.");
	    }

	    version(X86){
		if ((elfhdr.e_ident[EI_CLASS] != ELFCLASS32) ||
			(elfhdr.e_ident[EI_DATA] != ELFDATA2LSB) ||
			(elfhdr.e_machine != EM_386)) {
		    throw new DDLException("Object file not supported on this platform.");
		} 
	    }
	    else{
		throw new DDLException("This hardware platform is not yet supported.");
	    }


	    this.proghdrs = ptrArray!(Elf32_Phdr)(elfhdr.e_phoff,elfhdr.e_phnum);
	    this.sechdrs = ptrArray!(Elf32_Shdr)(elfhdr.e_shoff,elfhdr.e_shnum);
	    /*
	       debug{
	       debugLog("type: %d",elfhdr.e_type);
	       debugLog("machine: %d",elfhdr.e_machine);
	       debugLog("flags: %0.8x",elfhdr.e_flags);
	       debugLog("section header size: %d",elfhdr.e_shentsize);
	       }
	     */

	    // section header index for symbol table
	    uint symtableidx = -1;

	    // Load section names
	    this.shnames = ptrArray!(char)(sechdrs[elfhdr.e_shstrndx].sh_offset,sechdrs[elfhdr.e_shstrndx].sh_size);

	    /* we allocate section data pointer and relocation data pointer
	     * there are of course less relocation sections, but this way
	     * we keep this simple :>
	     */
	    secData.length     = this.sechdrs.length;
	    relocations.length = this.sechdrs.length;

	    foreach(sectNum, thisSection; this.sechdrs){
		secData[sectNum] = ptrArray!(void)(thisSection.sh_offset, thisSection.sh_size);

		debug (DDL) debugLog("{} sec name {} ", thisSection.getTypeName, toDString(&this.shnames[thisSection.sh_name]));

		switch(thisSection.sh_type) {
		    case SHT_NULL: 
			/* This value marks the section header as inactive; it does not have an associated section.
			   Other members of the section header have undefined values */ 
			break;

		    case SHT_PROGBITS: 
			/* The section holds information defined by the program, whose format and meaning are
			   determined solely by the program.*/
			/* I assume that module name is placed as last string in one of progbits sections
			 * 
			 */
			if (!moduleName) {
			    if (thisSection.sh_size > 0) {
				char[] secCharData = cast(char[])secData[sectNum];
				if (0 == secCharData[$-1]) {
				    int i;
				    for (i = secCharData.length - 2; i > -1; i--) {
					//debug (DDL) debugLog ("[{}]", secCharData[i]);
					if (secCharData[i] == 0) {
					    break;
					}
				    }

				    debug (DDL) debugLog ("{} {}", i, secCharData.length - 2);
				    if (i != secCharData.length - 2 && i != - 1) {
					moduleName = secCharData[i+1 .. $ - 1];
					debug (DDL) debugLog ("  MODULE NAME: {}", moduleName);
				    }
				}
			    }
			}
			break;

		    case SHT_DYNSYM:
			/* symbol table - dynamic linking only */
			// fallthrough
		    case SHT_SYMTAB:
			/* symbol table - static symbols */
			// get associated string table
			if (symbols !is null) {
			    assert (false, "currently only one symbol table is handled");
			}

			debug (DDL) debugLog("  symbol table: {} {} ", thisSection.sh_offset, thisSection.sh_entsize);
			symbols = ptrArray!(Elf32_Sym)(thisSection.sh_offset, thisSection.sh_size/thisSection.sh_entsize);
			symbolSectionIdx = thisSection.sh_link;
			break;

		    case SHT_STRTAB: 
			/* The section holds a string table. An object file may have multiple string table sections. */
			break;

		    case SHT_RELA: 
			/* The section holds relocation entries with explicit addends, such as type Elf32_Rela
			   for the 32-bit class of object files. An object file may have multiple relocation sections.*/
			Elf32_Rela[] relaSet = ptrArray!(Elf32_Rela)(thisSection.sh_offset,thisSection.sh_info);

			debug{
			    foreach(rela; relaSet){
			    }
			}

			break;

		    case SHT_HASH:
			/* The section holds a symbol hash table. All objects participating in dynamic linking
			   must contain a symbol hash table. Currently, an object file may have only one hash
			   table, but this restriction may be relaxed in the future. See 'Hash Table' in Part 2
			   for details.*/
			break;

		    case SHT_DYNAMIC: 
			/* The section holds information for dynamic linking. Currently, an object file may have
			   only one dynamic section, but this restriction may be relaxed in the future. See
			   'Dynamic Section' in Part 2 for details.*/
			break;

		    case SHT_NOTE: 
			/* The section holds information that marks the file in some way. 
			   See "Note Section" in Part 2 for details.*/
			break;

		    case SHT_NOBITS:
			/* A section of this type occupies no space in the file but otherwise resembles
			   SHT_PROGBITS. Although this section contains no bytes, the sh_offset member
			   contains the conceptual file offset.*/ 
			break;

		    case SHT_REL: 
			/* The section holds relocation entries without explicit addends, such as type
			   Elf32_Rel for the 32-bit class of object files. An object file may have multiple relocation
			   sections. */
			relocations[sectNum] = ptrArray!(Elf32_Rel)(thisSection.sh_offset, thisSection.sh_size/thisSection.sh_entsize);

			break;

		    case SHT_SHLIB:
			/* This section type is reserved but has unspecified semantics. Programs that contain a
			   section of this type do not conform to the ABI.*/
			break;

		    default:
			//TODO: check to make sure that the id is between LOPROC and HIPROC or LOUSER and HIUSER
			/* do nothing */
			debug (DDL) debugLog("Unknown Section Type: {}", thisSection.sh_type);
		}
	    }

	    /* process symbols */
	    Elf32_Shdr stringSection = sechdrs[symbolSectionIdx];
	    char* stringTable = cast(char*)(bitslab + stringSection.sh_offset);
	    foreach(idx, sym; symbols) {
		char[] symName;

		if ((sym.st_name | sym.st_value | sym.st_size | sym.st_info | sym.st_other /* | sym.st_shndx */) == 0 ) {
		    debug (DDL) debugLog("skipping symbol: {} ", sym.st_shndx);
		    continue;
		}

		if (sym.type == STT_SECTION) {
		    auto sec = this.sechdrs[sym.st_shndx];
		    symName = toDString(&this.shnames[sec.sh_name]);
				assert(symName.length > 0);

		} else {
		    symName = toDString(&stringTable[sym.st_name]);
				assert(symName.length > 0);
		}

		// evil hax0rish stuff
		// try to distinguish D module 
		if (symName.length > 15 && symName[0..2] == "_D" && symName[$-15 .. $] == "12__ModuleInfoZ" &&
			sym.type == STT_OBJECT && sym.bind == STB_GLOBAL) {
		    isDModule = true;
		}

		debug (DDL) debugLog("sym: {:d4} sec: {:d6} oth: 0x{:x4} val: 0x{:x8} siz: {:d9} {} {} [{}]", idx, sym.st_shndx, sym.st_other, sym.st_value, sym.st_size, sym.getTypeName, sym.getBindName, symName);

		switch (sym.bind) {
		    case STB_LOCAL:
			localSymbols[symName] = sym;
			break;
		    case STB_GLOBAL:
			if (sym.type == STT_NOTYPE) {
			    globalExternSymbols[symName] = sym;

			} else {
			    globalSymbols[symName] = sym;
			}
			break;
		    case STB_WEAK:
			weakSymbols[symName] = sym;
			break;
		    default:
		}
	    }
	}

	char* getStringsTable() {
	    auto stringSec = this.sechdrs[symbolSectionIdx];
	    return cast(char*)(this.bitslab + stringSec.sh_offset);
	}

	/// Returns a slice of the zero-terminated cString passed in, as a D-String.
	protected char[] toDString(char* cString){
	    uint i = 0;
	    while(cString[i] != '\0') i++;
	    return cString[0..i];
	}

	char[] toString(){
	    char[] result = "";
	    ELFPrinter printer = new ELFPrinter();

	    result ~= "Header:\n" ~ printer.printElfHeader(*elfhdr);
	    result ~= "\n" ~ printer.printProgramHeaders(proghdrs);
	    result ~= "\n" ~ printer.printSectionHeaders(sechdrs);
	    result ~= "\n" ~ printer.printSymbols(globalSymbols);
	    result ~= "\n" ~ printer.printSymbols(localSymbols);
	    result ~= "\n" ~ printer.printSymbols(weakSymbols);

	    return result;
	}
}


