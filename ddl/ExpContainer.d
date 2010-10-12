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
	Array wrapper template that provides exponential reserve characteristics
	for tuning purposes.	
**/
module ddl.ExpContainer;

/**
	Exponential reserve array template.
	
	At times, the memory reserve behavior of the GC can actually create a
	very large number of temporaries within the memory pool.  In such cases,
	overriding this behavior by creating an artifical reserve can yield 
	dramatic improvments in memory consumption and performance.
	
	This container is optimized for opCatAssign() operations, as it will
	attempt to store elements into its reserve space before reallocating.
	
	Reallocation is performed by doubling the size of the reserve array
	each time the reserve is exhausted.  Therefore, the developer must be
	very careful to only apply this container under small memory usage 
	scenarios.
	
	TODO: use malloc()/realloc() here instead of new/GC.
	TODO: set gc.scanRoot() for BaseType.sizeof >= ptr_t.sizeof
**/
struct ExpContainer(T){
	alias T BaseType;
	alias T[] ArrayType;
	alias ExpContainer!(T) ContainerType;
	
	static DefaultReserve = 100;
	
	ArrayType data;
	uint len;
	
	public uint length(){
		return len;
	}
	
	public void length(uint value){
		this.len = value;
	}
	
	public void* ptr(){
		return data.ptr;
	}
	
	public ArrayType all(){
		return this.data[0..this.length];		
	}

	public ArrayType dup(){
		return this.data[0..this.length].dup;		
	}		
	
	public void reserve(uint length){
		data.length = length;
	}
	
	public void deleteData() {
		delete data;
		len = 0;
	}
	
	public ContainerType opCatAssign(BaseType elem){
		if(this.length < data.length){
			this.data[this.length] = elem;
		}
		else if((data.length * BaseType.sizeof) <= 4096){
			if(this.data.length == 0) this.data.length = DefaultReserve;
			else this.data.length = this.data.length * 2;
		}
		else{
			this.data ~= elem;
		}
		this.length = this.length + 1;
		
		return *this;
	}
	
	public ContainerType opCat(BaseType elem){
		ContainerType result;
		
		result.data = this.data ~ elem;
		result.length = result.data.length;
		
		return result;
	}	
	
	public ContainerType opSlice(uint start,uint end){
		ContainerType result;
		
		result.data = this.data[start..end];
		result.length = result.data.length;
		
		return result;
	}
	
	public BaseType opIndex(uint idx){
		return this.data[idx];
	}

	public int opApply(int delegate(inout int,inout BaseType) dg){
		int result = 0;

		for (int i = 0; i < this.length; i++){
		    result = dg(i,this.data[i]);
		    if (result)
			break;
		}
		return result;
	}
	
	public int opApply(int delegate(inout BaseType) dg){
		int result = 0;

		for (uint i = 0; i < this.length; i++){
		    result = dg(this.data[i]);
		    if (result)
			break;
		}
		return result;
	}	
}
