module graph.value;

import std.variant : Algebraic;
import std.exception : enforce;

import std.typecons : Nullable;
import std.bigint;
import std.datetime : Date, SysTime;

import std.typetuple;
import variant_struct.variant_struct;

alias GraphBasicTypes = TypeTuple!(
	bool,
	double,
	int,
	long,
	BigInt,
	string,
	Date,
	SysTime,
	);

alias GraphValue = VariantStruct!GraphBasicTypes;
