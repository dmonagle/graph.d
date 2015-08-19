module variant_struct.serializer;

import variant_struct.variant_struct;
import std.typetuple;

/**
	Serializer for a plain Json representation.

	See_Also: vibe.data.serialization.serialize, vibe.data.serialization.deserialize, serializeToVT, deserializeVT
*/
struct VariantStructSerializer(VT) {
	template isVariantType(T) { enum isVariantType = (staticIndexOf!(T, VT.Types) != -1); }
	
	template isSupportedValueType(T) { enum isSupportedValueType = isVariantType!T || is(T == VT); }

	private {
		VT m_current;
		VT.Array m_compositeStack;
	}

	this(VT data) { m_current = data; }

	@disable this(this);

	//
	// serialization
	//
	VT getSerializedResult() { return m_current; }
	void beginWriteDictionary(T)() { m_compositeStack ~= VT.emptyObject; }
	void endWriteDictionary(T)() { m_current = m_compositeStack[$-1]; m_compositeStack.length--; }
	void beginWriteDictionaryEntry(T)(string name) {}
	void endWriteDictionaryEntry(T)(string name) { m_compositeStack[$-1][name] = m_current; }

	void beginWriteArray(T)(size_t) { m_compositeStack ~= VT.emptyArray; }
	void endWriteArray(T)() { m_current = m_compositeStack[$-1]; m_compositeStack.length--; }
	void beginWriteArrayEntry(T)(size_t) {}
	void endWriteArrayEntry(T)(size_t) { m_compositeStack[$-1].append(m_current); }

	void writeValue(T)(in T value)
		if (!is(T == VT))
	{
		//static if (isGraphSerializable!T) m_current = value.toJson();
		//else m_current = Json(value);
		m_current = VT(value);
	}

	void writeValue(T)(VT value) if (is(T == VT)) { m_current = value; }
	void writeValue(T)(in VT value) if (is(T == VT)) { m_current = value.dup; }
//	
//	//
//	// deserialization
//	//
//	void readDictionary(T)(scope void delegate(string) field_handler)
//	{
//		enforceJson(m_current.type == Json.Type.object, "Expected JSON object, got "~m_current.type.to!string);
//		auto old = m_current;
//		foreach (string key, value; m_current) {
//			m_current = value;
//			field_handler(key);
//		}
//		m_current = old;
//	}
//	
//	void readArray(T)(scope void delegate(size_t) size_callback, scope void delegate() entry_callback)
//	{
//		enforceJson(m_current.type == Json.Type.array, "Expected JSON array, got "~m_current.type.to!string);
//		auto old = m_current;
//		size_callback(m_current.length);
//		foreach (ent; old) {
//			m_current = ent;
//			entry_callback();
//		}
//		m_current = old;
//	}
//	
//	T readValue(T)()
//	{
//		static if (is(T == Json)) return m_current;
//		else static if (isJsonSerializable!T) return T.fromJson(m_current);
//		else static if (is(T == float) || is(T == double)) {
//			switch (m_current.type) {
//				default: return cast(T)m_current.get!long;
//				case Json.Type.undefined: return T.nan;
//				case Json.Type.float_: return cast(T)m_current.get!double;
//				case Json.Type.bigInt: return cast(T)m_current.bigIntToLong();
//			}
//		}
//		else {
//			return m_current.get!T();
//		}
//	}
//	
//	bool tryReadNull() { return m_current.type == Json.Type.null_; }
}

unittest {
	alias VStruct = VariantStruct!(double, int, string);
	alias V = VariantStructSerializer!VStruct;
	assert(V.isVariantType!string);
	assert(V.isVariantType!string);
	assert(V.isVariantType!string);
	assert(!V.isVariantType!float);
}