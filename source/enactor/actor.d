module enactor.actor;

import std.traits : hasMember;

// TODO: need to also ensure it has an ActorContext.
enum isActor(T) = hasMember!(T, "receive");

enum Supervise {
    AllowFail,
    RestartOnFail,
    RestartAllOnFail
}

mixin template Actor() {
    import sumtype : match, tryMatch; // TODO: Should I do this? Probably.

    static assert(is(typeof(this) == class),
            "Only classes can currently be part of an actor supervisory tree.");

    ActorCtx!(typeof(this)) _act_ctx = ActorCtx!(typeof(this))();
}

mixin template Supervisor() {
    import std.traits : _act_hasMember = hasMember;
    static if (! _act_hasMember!(typeof(this), "_act_ctx")) {
        mixin Actor;
    }

    void supervise(A)(A actor, Supervise policy) {
        assert(_act_hasMember!(A, "_act_ctx"), "Cannot supervise " ~ A.stringof ~ ". Maybe you need to `mixin Actor`?");
        assert(0, "Still need to implement supervise(actor, policy) function.");
    }
}

void send(A, M...)(A actor, M message) if (isActor!A) {
    // TODO: Deal with M array.
    actor._act_ctx.mailbox.put(message);
}

void send(M...)(string actorAddress, M message) {
    assert(0, "Still need to implement send(address, message) function.");
}

ref A register(A)(string address, ref return scope A actor) {
    assert(0, "Still need to implement register(address, actor) function.");
    //return actor;
}

struct ActorCtx(A) {
    private:
    Mailbox!A mailbox;
}

private:

@("Store messages in a mailbox")
unittest {
    import std.typecons : Tuple;
    import sumtype : tryMatch;
    class A {
        mixin Actor;
        void receive(string msg) {}
        void receive(int i) {}
    }

    auto box = Mailbox!A();
    box.put(7);
    box.put("hello");

    assert(box.moveFront().tryMatch!( (Tuple!int i) => i[0] ) == 7);
    assert(box.front().tryMatch!( (Tuple!string s) => s[0] ) == "hello");
}

struct Mailbox(A) {
    @property
    auto front()
        in(messages.length > 0)
    {
        return messages[0];
    }

    auto moveFront()
        in(messages.length > 0)
    {
        auto tmp = front();
        popFront();
        return tmp;
    }

    void popFront()
        in(messages.length > 0)
    {
        messages = messages[1..$];
    }

    @property
    bool empty() { return messages.length == 0; }

    /+ TODO
    int opApply(scope int delegate(Message)) {
    }
    int opApply(scope int delegate(size_t, Message)) {
    }
    +/

    void put(T)(T message) { // TODO: If in sumtype
        import std.typecons : tuple;
        messages ~= Message(tuple(message));
    }

    private:

    mixin(GenMessage!A());
    Message[] messages;
}

@("The registry stores actors")
unittest {
    class One {
        mixin Actor;
        void receive(int a, int b) {}
    }
    class Two {
        mixin Actor;
        void receive(string s) {}
    }

    auto r = Registry();
    auto one = new One();
    auto two = new Two();
    r.register("one", one);
    r.register("two", two);

    assert(r["one"] == one);
    assert(r["two"] == two);
}

struct Registry {
    auto opIndex(string name)
        in(name.length > 0)
    {
        return actors[name];
    }

    void register(A)(string name, A actor) if (isActor!A)
        in(name.length > 0)
    {
        // TODO: Disallow re-registering a name?
        actors[name] = actor;
    }

    private:

    Object[string] actors;
}

string GenMessage(A)() {
    import std.traits;
    auto gentype = `import std.typecons:_act_Tuple=Tuple;import sumtype:SumType;alias Message=SumType!(`;
    auto imports = ``;

    if (MemberFunctionsTuple!(A, "receive").length == 0) {
        assert(0, "Actor must have a receive method.");
    }

    foreach (func; MemberFunctionsTuple!(A, "receive")) {
        // TODO: error? if (Parameters!func.length == 0) return "";

        gentype ~= `_act_Tuple!(`;
        foreach (param; Parameters!func) {
            static if (isBuiltinType!param) {
                gentype ~= param.stringof ~ `,`;
            } else {
                gentype ~= `_act_` ~ param.stringof ~ `,`;
                imports ~= `import ` ~ moduleName!param ~ `:_act_`
                        ~ param.stringof ~ `=` ~ param.stringof ~ `;`;
            }
        }
        gentype = gentype[0..$-1] ~ `),`;
    }

    return imports ~ gentype[0..$-1] ~ `);`;
}
