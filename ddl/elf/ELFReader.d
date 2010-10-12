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
module ddl.elf.ELFReader;

private import ddl.DDLReader;
private import ddl.FileBuffer;
private import ddl.elf.ELFHeaders;


// reader class
class ELFReader: DDLReader{
	public this(FileBuffer buffer){
		super(buffer);
	}	
	
	public void setPosition(uint position){
   		super.seek(position,Anchor.Begin);
	}
		
	alias _get!(Elf32_Ehdr) get;
	alias _get!(Elf32_Shdr) get;
	alias _get!(Elf32_Phdr) get;
	alias _get!(Elf32_Sym) get;
	alias _get!(Elf32_Rel) get;
	alias _get!(Elf32_Rela) get;
}