module variant_struct.variant_struct;

import std.variant : Algebraic;
import std.exception : enforce;

import std.typecons : Nullable;
import std.typetuple;

/**
 * Represents a generic Graph value.
 *
 * Wraps a $(D std.variant.Algebraic) to provide a way to represent a graph
 * of raw values.
 *
 * This is meant to be a little more expanisve than the general types held
 * by Json type structs and is aimed at field types commonly needed for 
 * databases.
 * 
 * Raw values can be one of: $(D null), $(D bool), $(D double), $(D string)
 * $(D Date), $(D SysTime)
 * Arrays are represented by $(D VS[]) 
 * and objects by $(D VS[string]).
*/
struct VariantStruct(T ...) {
	/**
     * Alias for a $(D std.variant.Algebraic) able to hold VariantStruct
     * value types.
     */

	private alias VS = VariantStruct!T;
	alias Types = T;
	alias Object = VS[string];
	alias Array = VS[];
	alias Variant = Algebraic!(TypeTuple!(Types, TypeTuple!(typeof(null), Object, Array)));

	Variant value;
	
	alias value this;
	
	/// Returns a VS encapsulating an empty object
	static emptyObject() { return (Object.init); }
	
	/// Returns a VS encapsulating an empty array
	static emptyArray() { return VS(Array.init); }
	
	/**
     * Constructs a VS from the given raw value.
     */
	this(T : Variant)(T v) { value = v; }
	/// ditto
	this(T)(T v) { value = Variant(v); }

	
	/**
     * Gets a descendant of this value.
     *
     * If any encountered VS along the path is not an object or does not
     * have a machting field, a null value is returned.
     */
	Nullable!VS getPath(scope string[] path...)
	{
		VS cur = this;
		foreach (name; path) {
			auto obj = cur.peek!(Object);
			if (!obj) return Nullable!VS.init;
			auto pv = name in *obj;
			if (pv is null) return Nullable!VS.init;
			cur = *pv;
		}
		return Nullable!VS(cur);
	}
	
	/// Returns true if this $(D VS) is of type T
	@property bool isType(T)() {
		auto asType = value.peek!(T);
		if (asType != null) return true;
		return false;
	}
	
	/// Returns true if this $(D VS) is an object
	@property bool isObject() {
		return isType!Object;
	}
	
	/// Returns true if this $(D VS) is an array
	@property bool isArray() {
		return isType!Array;
	}
	
	VS opAssign(T)(T value) {
		this.value = value;
		return this;
	}
	
	VS opAssign(T : VS)(T value) {
		this.value = value.value;
		return this;
	}
	
	ref VS opIndex(size_t idx)
	{
		auto asArray = value.peek!(Array);
		enforce(asArray != null, "not an array");
		return (*asArray)[idx];
	}
	
	ref VS opIndex(string key)
	{
		auto asObject = value.peek!(Object);
		enforce(asObject != null, "not an object");
		return (*asObject)[key];
	}
	
	/// Creates a recursed duplicate, ensuring arrays and objects are duplicates and not slices
	VS dup() {
		if (this.isArray) {
			Array array;
			foreach(v; value.get!Array) array ~= v.dup;
			return VS(array);
		}
		else if (this.isObject) {
			Object object;
			foreach(k, v; value.get!Object) object[k] = v.dup;
			return VS(object);
		}
		return VS(value);
	}
	
	/// Appends the given element to the array. If the element is an array, it will be nested
	void append(VS value)
	{
		enforce(isType!Array, "'append' can only be called on Array type, not " ~ value.type.stringof ~ ".");
		this.value ~= value;
	}
}

/// Shows the basic construction and operations on Graph values.
unittest
{
	alias VStruct = VariantStruct!(bool, int, string, double);

	VStruct a = 12;
	VStruct b = 13;
	
	assert(a == 12.0);
	assert(b == 13.0);
	// I'm sure this should work but alias this doesn't appear to be working when VariantStruct is a template struct
	// This line passes if variant tree is not a struct and the types are hard coded.
	//assert(a + b == 25.0);
	
	auto c = VStruct([a, b]);
	assert(c.isArray);
	assert(c.get!(VStruct.Array)[0] == 12.0);
	assert(c.get!(VStruct.Array)[1] == 13.0);
	assert(c[0] == a);
	assert(c[1] == b);
	static if (__VERSION__ < 2067) {
		assert(c[0] == 12.0);
		assert(c[1] == 13.0);
	}

	auto d = VStruct(["a": a, "b": b]);
	assert(d.isObject);
	assert(d.get!(VStruct.Object)["a"] == 12.0);
	assert(d.get!(VStruct.Object)["b"] == 13.0);
	assert(d["a"] == a);
	assert(d["b"] == b);
}

/// Using $(D opt) to quickly access a descendant value.
unittest
{
	alias VStruct = VariantStruct!(bool, int, string, double);

	VStruct subobj = ["b": VStruct(1.0), "c": VStruct(2.0)];
	VStruct obj = ["a": subobj];

	assert(obj.getPath("x").isNull);
	assert(obj.getPath("a", "b") == 1.0);
	assert(obj.getPath("a", "c") == 2.0);
	assert(obj.getPath("a", "x").isNull);
}

