/**
	* Graph Storage Classes
	*
	* Copyright: © 2015 David Monagle
	* License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	* Authors: David Monagle
*/
module graph.graph;

import graph.value.serializer;
import graph.value.value;
import vibe.data.serialization;

import std.algorithm;
import std.array;

/// Adds a property to a class that will return the class name at runtime. Works on base classes to return the child class type
/// Eg. const graph.graph.Graph is returned as Graph
mixin template GraphTypeProperty() {
	/// Returns a string representation of the class name
	/// Removes const and namespaceing so it should match the name of the class called with stringof
	@ignore @property string graphType() const {
		import std.string;
		import std.regex;
		
		auto constMatch = ctRegex!`^const\((.*)\)$`;
		auto typeString = typeid(this).toString();

		// Remove the const qualifier 
		if (auto matches = typeString.matchFirst(constMatch)) typeString = matches[1];
		
		// Return the text after the last .
		return typeString.split(".")[$ - 1];
	}
}


interface GraphModelInterface {
	@property string graphType() const;

	@property bool graphPersisted() const;
	@property void graphPersisted(bool value);

	@property bool graphSynced() const;
	void graphTouch();
	void graphUntouch();

	@property bool graphDeleted() const;
	void graphDelete();
	void graphUndelete();

	@property inout(Graph) graphInstance() inout;
	@property void graphInstance(Graph value);

	GraphValue toGraphValue();
	bool graphHasSnapshot() const;
	void clearGraphSnapshot();
	@property ref GraphValue graphSnapshot();
	@property GraphValue graphSnapshot() const;
}

/// Mixin to implement basic functionality to a `GraphModelInterface`
mixin template GraphModelImplementation() {
	mixin GraphTypeProperty;

	@ignore bool graphPersisted() const { return _graphPersisted; }
	void graphPersisted(bool value) { _graphPersisted = value;}

	@ignore @property bool graphSynced() const { return _graphSynced; }
	void graphTouch() { _graphSynced = false; }
	void graphUntouch() { _graphSynced = true; }

	bool graphDeleted() const { return _graphDeleted; }
	void graphDelete() { _graphDeleted = true; }
	void graphUndelete() { _graphDeleted = false; }

	@ignore @property inout(Graph) graphInstance() inout { return _graphInstance; }
	@property Graph graphInstance() { return _graphInstance; }
	@property void graphInstance(Graph value) { _graphInstance = value; }

	GraphValue toGraphValue() { 
		return serialize!GraphValueSerializer(this);
	}

	bool graphHasSnapshot() const {
		return _snapshot.isNull ? false : true;
	}

	void clearGraphSnapshot() {
		_snapshot = null;
	}

	@ignore @property ref GraphValue graphSnapshot() {
		return _snapshot;
	}

	@property GraphValue graphSnapshot() const {
		return _snapshot;
	}

private:
	Graph _graphInstance;
	GraphValue _snapshot;
	bool _graphPersisted;
	bool _graphSynced;
	bool _graphDeleted;
}

/// Main storage class for Graph
class Graph {
	static GraphValue serializeModel(M : GraphModelInterface)(M model) {
		return serialize!GraphValueSerializer(model);
	}
	
	static M deserializeModel(M : GraphModelInterface)(GraphValue value) {
		return deserialize!(GraphValueSerializer, M)(value);
	}
	
	M inject(M : GraphModelInterface)(M model, bool snapshot = true) 
	in {
		assert (model.graphType == M.stringof, "class " ~ M.stringof ~ "'s graphType does not match the classname: " ~ model.graphType);
	}
	body {
		if (model.graphInstance !is this) {
			model.graphInstance = this;
			modelStore!M ~= model;
		}
		if (snapshot) model.graphSnapshot = serializeModel(model);
		return model;
	}

	/// Reverts the model back to the snapshot state if the snapshot exists
	void revert(M : GraphModelInterface)(ref M model) 
	in {
		assert (model.graphType == M.stringof, "class " ~ M.stringof ~ "'s graphType does not match the classname: " ~ model.graphType);
	}
	body {
		if (model.graphInstance !is this) return;
		if (!model.graphHasSnapshot) return;
		auto reverted = deserializeModel!M(model.graphSnapshot);
		model.copyGraphAttributes(reverted);
	}


	ref GraphModelInterface[] modelStore(M)() {
		if (M.stringof !in _store) return (_store[M.stringof] = []);
		return _store[M.stringof];
	}

private:
	GraphModelInterface[][string] _store;
}

M[] findInGraph(M : GraphModelInterface, alias predicate = (m) => true)(Graph graph) {
	auto results = array(graph.modelStore!M.filter!((m) => predicate(cast(M)m)));
	return array(results.map!((m) => cast(M)m));
}


version (unittest) {
	class GraphModel : GraphModelInterface {
		mixin GraphModelImplementation;

		string id;
	}

	class Animal : GraphModel {
		string name;
	}

	class Human : Animal {
		string title;
	}

	unittest {
		auto graph = new Graph();

		auto david = graph.inject(new Human());
		david.name = "David";
		david.title = "Mr";
		assert(graph.modelStore!Human.length == 1);

		auto ginny = graph.inject(new Human());
		ginny.name = "Ginny";
		ginny.title = "Mrs";
		assert(graph.modelStore!Human.length == 2);

		auto mia = graph.inject(new Animal());
		mia.name = "Mia";
		assert(graph.modelStore!Animal.length == 1);

		auto person = cast(Human)graph.modelStore!Human[0];
		assert(person.name == "David");

		assert(graph.findInGraph!(Human, (m) => m.name == "David").length == 1);
	}

	// Test snapshots
	unittest {
		auto graph = new Graph();
		
		auto david = graph.inject(new Human());
		david.name = "David";
		david.title = "Mr";
		assert(graph.modelStore!Human.length == 1);
		
		auto ginny = graph.inject(new Human(), false);
		ginny.name = "Ginny";
		ginny.title = "Miss";
		assert(graph.modelStore!Human.length == 2);
		
		auto mia = graph.inject(new Animal());
		mia.name = "Mia";
		assert(graph.modelStore!Animal.length == 1);

		assert(david.graphHasSnapshot);

		assert(!ginny.graphHasSnapshot);
		graph.inject(ginny, true); // Take a snapshot
		ginny.title = "Mrs";
		assert(ginny.graphSnapshot["title"] == "Miss");
		auto oldGinny = ginny;
		graph.revert(ginny);
		assert(ginny.title == "Miss");
		assert(oldGinny is ginny);
	}
}

/*
// Would like to get this working but tonnes of edge cases...
M merge(M : GraphModelInterface)(ref M model, const ref GraphValue data, typeof(__FILE__) file = __FILE__, typeof(__LINE__) line = __LINE__) {
	import graph.serialization;
	assert(data.isObject, "Merging only works with objects (" ~ file ~ ":" ~ line.to!string ~ ")");
	foreach (i, mname; SerializableFields!M) {
		if (data.hasKey(mname)) __traits(getMember, model, mname) = fromGraphValue!(typeof(__traits(getMember, model, mname)))(data[mname]);
	}
	return model;
}
*/

/// Copy the serializable attributes from source to destination
M copyGraphAttributes(M : GraphModelInterface)(ref M dest, const ref M source) {
	import graph.value.serialization;
	foreach (i, mname; SerializableFields!M) {
		__traits(getMember, dest, mname) = __traits(getMember, source, mname);
	}
	return dest;
}

/// Merge the GraphValue data into the given model
M merge(M : GraphModelInterface)(ref M model, GraphValue data) {
	auto attributes = Graph.serializeModel(model);
	auto newModel = Graph.deserializeModel!M(graph.value.merge(attributes, data));
	model.copyGraphAttributes(newModel);

	return model;
}

version (unittest) {
	class Person : GraphModelInterface {
		mixin GraphModelImplementation;
		
		string firstName;
		string surname;
		int age;
		double wage;
	}

	unittest {
		auto person = new Person;
		person.surname = "Monagle";
		auto data = GraphValue.emptyObject;
		data["firstName"] = "David";
		person.merge(data);
		assert(person.surname == "Monagle");
		assert(person.firstName == "David");
	}
}