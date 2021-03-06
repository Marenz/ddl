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
module ddl.insitu.InSituModule;

private import ddl.ExportSymbol;
private import ddl.DynamicModule;
private import ddl.insitu.InSituModule;
private import ddl.SymbolLineNumber;


class InSituModule : DynamicModule{
	ExportSymbol[char[]] exports;
	
	public this(ExportSymbol[char[]] exports){
		this.exports = exports;
	}
	
	public char[] getName(){
		return "<in-situ>";
	}
		
	public ExportSymbol[] getSymbols(){
		return exports.values;
	}
	
	public ExportSymbolPtr getSymbol(char[] name){
		if(name in exports)	return &(exports[name]);
		else return &ExportSymbol.NONE;
	}

	public SymbolLineNumber[] getSymbolLineNumbers() {
		assert (false, `TODO`);
		return null;
	}
	
	public void resolveFixups(){
		//do nothing
	}
	
	public bool isResolved(){
		return true;
	}
}