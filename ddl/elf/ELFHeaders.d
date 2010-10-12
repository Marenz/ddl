/+
    Copyright (c) 2005-2006 Lars Ivar Igesund

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
module ddl.elf.ELFHeaders;

/**
    Constants from the ELF specification.
*/

/** Size of the e_ident array. */
const uint EI_NIDENT = 16;

/** Indices in the e_ident array. */
const uint EI_MAG0 = 0;
const uint EI_MAG1 = 1;
const uint EI_MAG2 = 2;
const uint EI_MAG3 = 3;
const uint EI_CLASS = 4;
const uint EI_DATA = 5;
const uint EI_VERSION = 6;
const uint EI_PAD = 7;

/** Values defining the class of the file. */
const uint ELFCLASSNONE = 0;
const uint ELFCLASS32 = 1;
const uint ELFCLASS64 = 2;

/** Values defining the encoding of data. */
const uint ELFDATANONE = 0;
const uint ELFDATA2LSB = 1;
const uint ELFDATA2MSB = 2;

/** Defined version of the ELF specification. */
const uint EV_NONE = 0;
const uint EV_CURRENT = 1; // This can change!

/** The version currently supported by DDL */
const uint DDL_ELFVERSION_SUPP = 1;

/** Values defining the object file type. */
const uint ET_NONE = 0;
const uint ET_REL = 1;
const uint ET_EXEC = 2;
const uint ET_DYN = 3;
const uint ET_CORE = 4;
const uint ET_LOPROC = 0xff00;
const uint ET_HIPROC = 0xffff;

/** Values defining machine architectures. */
const uint EM_NONE = 0;
const uint EM_M32 = 1;
const uint EM_SPARC = 2;
const uint EM_386 = 3;
const uint EM_68K = 4;
const uint EM_88K = 5;
const uint EM_860 = 7;
const uint EM_MIPS = 8;



/** Values defining section types. */
const uint SHT_NULL = 0;
const uint SHT_PROGBITS = 1;
const uint SHT_SYMTAB = 2;
const uint SHT_STRTAB = 3;
const uint SHT_RELA = 4;
const uint SHT_HASH = 5;
const uint SHT_DYNAMIC = 6;
const uint SHT_NOTE = 7;
const uint SHT_NOBITS = 8;
const uint SHT_REL = 9;
const uint SHT_SHLIB = 10;
const uint SHT_DYNSYM = 11;
const uint SHT_LOPROC = 0x70000000;
const uint SHT_HIPROC = 0x7fffffff;
const uint SHT_LOUSER = 0x80000000;
const uint SHT_HIUSER = 0xffffffff;

/** Values defining segment types. */
const uint PT_NULL = 0;
const uint PT_LOAD = 1;
const uint PT_DYNAMIC = 2;
const uint PT_INTERP = 3;
const uint PT_NOTE = 4;
const uint PT_SHLIB = 5;
const uint PT_PHDR = 6;
const uint PT_LOPROC = 0x70000000;
const uint PT_HIPROC = 0x7fffffff;


alias uint Elf32_Addr;
alias ushort Elf32_Half;
alias uint Elf32_Off;
alias int Elf32_SWord;
alias uint Elf32_Word;
alias ushort Elf32_Sword;

/**
    This struct can hold an ELF object file header.
*/

struct Elf32_Ehdr{

     ubyte [EI_NIDENT] e_ident;
     Elf32_Half e_type;
     Elf32_Half e_machine;
     Elf32_Word e_version;
     Elf32_Addr e_entry;
     Elf32_Off e_phoff;
     Elf32_Off e_shoff;
     Elf32_Word e_flags;
     Elf32_Half e_ehsize;
     Elf32_Half e_phentsize;
     Elf32_Half e_phnum;
     Elf32_Half e_shentsize;
     Elf32_Half e_shnum;
     Elf32_Half e_shstrndx;

}

/**
    This struct can hold a section header table entry from an ELF object
    file.
*/
const int SHF_WRITE = 0x1;
const int SHF_ALLOC = 0x2;
const int SHF_EXECINSTR = 0x4;

private static char[][] sectionTypes = [
	"SHT_NULL    ", "SHT_PROGBITS", "SHT_SYMTAB  ",
	"SHT_STRTAB  ", "SHT_RELA    ", "SHT_HASH    ",
	"SHT_DYNAMIC ", "SHT_NOTE    ", "SHT_NOBITS  ",
	"SHT_REL     ", "SHT_SHLIB   ", "SHT_DYNSYM  "];

struct Elf32_Shdr{
    Elf32_Word sh_name;
    Elf32_Word sh_type;
    Elf32_Word sh_flags;
    Elf32_Addr sh_addr;
    Elf32_Off sh_offset;
    Elf32_Word sh_size;
    Elf32_Word sh_link;
    Elf32_Word sh_info;
    Elf32_Word sh_addralign;
    Elf32_Word sh_entsize;

    char[] getFlags() {
    	char[] ret;
    	if (this.sh_flags & SHF_WRITE)     ret ~= "[W";
    	else                               ret ~= "[-";
    	
    	if (this.sh_flags & SHF_ALLOC)     ret ~= "A";
    	else                               ret ~= "-";
    	
    	if (this.sh_flags & SHF_EXECINSTR) ret ~= "X]";
    	else                               ret ~= "-]";
    
    	return ret;
    }

    char[] getTypeName() {
    	uint n = this.sh_type;
		if (n <= SHT_DYNSYM) {
		    return sectionTypes[n];
		}
		else if (n >= SHT_LOPROC && n <= SHT_HIPROC) {
		    return "[SHT_LOPROC..SHT_HIPROC]";
		}
		else if(n >= SHT_LOUSER && n <= SHT_HIUSER) {
		    return "[SHT_LOUSER..SHT_HIUSER]";
		}
		return "unknown section type";
	}
}

/**
    This struct can hold a program header table entry from an ELF object
    file.
*/

struct Elf32_Phdr{
    Elf32_Word p_type;
    Elf32_Off p_offset;
    Elf32_Addr p_vaddr;
    Elf32_Addr p_paddr;
    Elf32_Word p_filesz;
    Elf32_Word p_memsz;
    Elf32_Word p_flags;
    Elf32_Word p_align;
}

/** Values defining special section indices */
enum: ushort {
	SHN_UNDEF  = 0,
	SHN_ABS    = 0xfff1,
	SHN_COMMON = 0xfff2
}

/** Values defining symbol types */
enum: ubyte {
	STT_NOTYPE  = 0,
	STT_OBJECT  = 1,
	STT_FUNC    = 2,
	STT_SECTION = 3,
	STT_FILE    = 4,
	STT_LOPROC  = 13,
	STT_HIPROC  = 15,
}

/** Values defining symbol binding. */
enum: ubyte{
	STB_LOCAL = 0,
	STB_GLOBAL = 1,
	STB_WEAK = 2,
	STB_LOPROC = 13,
	STB_HIPROC = 15
}


/**
    This struct can hold a symbol table entry from an ELF object file.
*/ 
struct Elf32_Sym{
    Elf32_Word    st_name;
    Elf32_Addr    st_value;
    Elf32_Word    st_size;
    ubyte     	  st_info;
    ubyte         st_other;
    Elf32_Half    st_shndx;

    ubyte bind(){
	return this.st_info >> 4;
    }

    ubyte type(){
	return this.st_info & 0xf;
    }

    char[] getBindName(){
	    switch(this.bind){
		case STB_LOCAL:   return("Local ");
		case STB_GLOBAL:  return("Global");
		case STB_WEAK:    return("Weak  ");
		default:
	    }
	    return "Unknown";
    }	

    char[] getTypeName(){
	switch(this.type) {
	    case STT_NOTYPE:  return("None   ");
	    case STT_OBJECT:  return("Object ");
	    case STT_FUNC:    return("Func   ");
	    case STT_SECTION: return("Section");
	    case STT_FILE:    return("File   ");
	    default:
	}
	return "Unknown";
    }

    char[] getIndex() {
    	switch(this.st_shndx) {
	    case SHN_UNDEF:   return("undefined");
	    case SHN_ABS:     return("absolute ");
	    case SHN_COMMON:  return("common   ");
	    default:
	}

    	char[] value;
    	auto temp = this.st_shndx;
    	while (temp) {
    		value ~= ('0' + (temp % 10));
    		temp /= 10;
    	}
    	return value.reverse;
    }
}

private ubyte ELF32_ST_BIND(ubyte i){
    return i >> 4;
}

private ubyte ELF32_ST_TYPE(ubyte i){
    return i & 0xf;
}

private ubyte ELF32_ST_INFO(ubyte b, ubyte t){
    return (b << 4) + (t & 0xf);
}

/**
  Relocation types
 */
enum: byte {
	R_386_NONE  = 0,
	R_386_32,
	R_386_PC32,
	R_386_GOT32,
	R_386_PLT32,
	R_386_COPY,
	R_386_GLOB_DAT,
	R_386_JMP_SLOT,
	R_386_RELATIVE,
	R_386_GOTOFF,
	R_386_GOTPC,

	R_386_TLS_IE = 15,
	R_386_TLS_LE = 17
}

/**
    This struct can hold a relocation entry from an ELF object file.
 */
struct Elf32_Rel
{
    Elf32_Addr r_offset;
    Elf32_Word r_info;

    ubyte sym()
    {
	return ELF32_R_SYM(this.r_info);
    }

    ubyte type()
    {
	return ELF32_R_TYPE(this.r_info);
    }

    char[] getType()
    {
	switch (this.type()) {
	    case R_386_NONE:     // 0 none none
		return "R_386_NONE    ";
	    case R_386_32:       // 1 word32 S + A
		return "R_386_32      ";
	    case R_386_PC32:     // 2 word32 S + A - P
		return "R_386_PC32    ";
	    case R_386_GOT32:    // 3 word32 G + A - P
		return "R_386_GOT32   ";
	    case R_386_PLT32:    // 4 word32 L + A - P
		return "R_386_PLT32   ";
	    case R_386_COPY:     // 5 none none
		return "R_386_COPY    ";
	    case R_386_GLOB_DAT: // 6 word32 S
		return "R_386_GLOB_DAT";
	    case R_386_JMP_SLOT: // 7 word32 S
		return "R_386_JMP_SLOT";
	    case R_386_RELATIVE: // 8 word32 B + A
		return "R_386_RELATIVE";
	    case R_386_GOTOFF:   // 9 word32 S + A - GOT
		return "R_386_GOTOFF  ";
	    case R_386_GOTPC:    // 10 word32 GOT + A - P
		return "R_386_GOTPC   ";
	    case R_386_TLS_IE:
		return "R_386_TLS_IE  ";
	    case R_386_TLS_LE:
		return "R_386_TLS_LE  ";
	    default:
		return "Unknown relocation type";
	}
    }
}

private uint ELF32_R_SYM(uint i) {
    return i >> 8;
}

private ubyte ELF32_R_TYPE(uint i) {
    return i & 0xff;
}

/**
    This struct can hold a relocation entry from an ELF object file,
    including an addend.
*/

struct Elf32_Rela{
    Elf32_Addr r_offset;
    Elf32_Word r_info;
    Elf32_Sword r_addend;

    ubyte symbol(){
	    return this.r_info >> 8;
    }

    ubyte type(){
	    return cast(ubyte)this.r_info;
    }
}

