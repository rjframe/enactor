module enactor.actor;

import std.traits : hasMember;

import enactor.trace;

enum Application {
    Run,
    ExitSuccess
}

/** The top-level actor of the supervisory tree. */
class MainActor {
    mixin Actor;
    mixin Supervisor;


    void receive(Application state) {
        final switch (state) {
            case Application.Run:
                foreach (actor; registry) {
                    processMessage(actor);
                }
                send(this, Application.Run);
                break;
            case Application.ExitSuccess:
                trace("Exiting.");
                exit = true;
                break;
        }
    }

    void start() {
        registry.register("main", this);
        send(this, Application.Run);
        while(!exit) processMessage(this);
    }

    private:

    static Registry registry = Registry();
    bool exit = false;

    void processMessage(Object actor) {
        class CX {
            mixin Actor ACT;
            void receive(int throwaway) { assert(0); }
            alias _act_receiver = ACT._act_receiver;
        }
        auto act = actor.reinterpret!CX();
        act._act_receiver();
    }
}

enum isActor(T) = hasMember!(T, "receive") && hasMember!(T, "_act_ctx");

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

    extern(C) void _act_receiver() {
        if (this._act_ctx.mailbox.empty) return;

        auto msg = this._act_ctx.mailbox.moveFront();
        //pragma(msg, "**ParamHandler:\n" ~ GenParamHandler!(typeof(this)));
        mixin(GenParamHandler!(typeof(this)));
        trace(tup);
        receive(tup.expand);
    }
}

mixin template Supervisor() {
    import std.traits : _act_hasMember = hasMember;
    static if (! _act_hasMember!(typeof(this), "_act_ctx")) {
        mixin Actor;
    }

    A supervise(A)(A actor, Supervise policy) {
        assert(_act_hasMember!(A, "_act_ctx"), "Cannot supervise " ~ A.stringof ~ ". Maybe you need to `mixin Actor`?");
        assert(0, "Still need to implement supervise(actor, policy) function.");
        //return actor;
    }
}

void send(A, M...)(A actor, M message) if (isActor!A) {
    actor._act_ctx.mailbox.put(message);
}

void send(M...)(string actorAddress, M message)
    in(MainActor.registry.isRegistered(actorAddress), actorAddress)
{
    class CX {
        mixin Actor ACT;
        void receive(M msg) { assert(0); }
        alias _act_ctx = ACT._act_ctx;
    }
    auto actor = MainActor.registry[actorAddress].reinterpret!CX();
    actor._act_ctx.mailbox.put(message);
}

@("Add actors to the global registry")
unittest {
    class One { mixin Actor; void receive(int i) {} }
    class Two { mixin Actor; void receive(string s) {} }
    auto one = new One();
    auto two = new Two();

    register("one", one);
    register("two", two);

    assert(MainActor.registry["one"] == one);
    assert(MainActor.registry["two"] == two);
}

ref A register(A)(string address, ref return scope A actor) {
    MainActor.registry.register(address, actor);
    return actor;
}

struct ActorCtx(A) {
    Mailbox!A mailbox;
}

string GenParamHandler(T)() {
    import std.traits;
    auto imports = ImportBuilder()
            .put("std.typecons", "Tuple", "_act_Tuple");

    foreach (func; MemberFunctionsTuple!(T, "receive")) {
        assert(Parameters!func.length > 0,
                "Empty receive() parameter list is not allowed.");

        auto tup = GenericTypeBuilder!"_act_Tuple"();
        foreach (param; Parameters!func) {
            static if (isBuiltinType!param) {
                tup.put(param.stringof);
            } else {
                tup.put("_act_" ~ param.stringof);
                imports.put(
                        moduleName!param,
                        param.stringof,
                        "_act_" ~ param.stringof);
            }
        }
        return imports.code ~ `auto tup=msg.tryMatch!((` ~ tup.code ~ ` t)=>t);`;
    }
}

private:

/* Evil... */
/* Reinterpret the provided value as another type. */
T reinterpret(T, V)(V value) {
    union Reinterpret {
        V val;
        T newType;
    }
    return Reinterpret(value).newType;
}

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
    import sumtype : canMatch;

    //pragma(msg, "***GenMessage:\n" ~ GenMessage!A());
    mixin(GenMessage!A());

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

    int opApply(scope int delegate(Message) dg) {
        int res = 0;

        for (size_t i = 0; i < messages.length; ++i) {
            res = dg(messages[i]);
            if (res) break;
        }
        return res;
    }

    int opApply(scope int delegate(size_t, Message) dg) {
        int res = 0;

        for (size_t i = 0; i < messages.length; ++i) {
            res = dg(i, messages[i]);
            if (res) break;
        }
        return res;
    }

    void put(T...)(T message) if (canMatch!((t => t), Message)) {
        import std.typecons : tuple;
        messages ~= Message(tuple(message));
    }

    private:

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

    int opApply(scope int delegate(Object) dg) {
        int res = 0;

        foreach (actor; actors.byValue()) {
            res = dg(actor);
            if (res) break;
        }
        return res;
    }

    int opApply(scope int delegate(size_t, Object) dg) {
        import std.range : enumerate;
        int res = 0;

        foreach (i, actor; actors.byValue().enumerate) {
            res = dg(i, actor);
            if (res) break;
        }
        return res;
    }

    void register(A)(string name, A actor) if (isActor!A)
        in(name.length > 0)
    {
        // TODO: Disallow re-registering a name.
        // TODO: Hash the name. Create custom container so we don't hash a hash?
        actors[name] = actor;
    }

    bool isRegistered(string name) { return !!(name in actors); }

    private:

    Object[string] actors;
}

string GenMessage(A)() {
    import std.traits;
    assert(MemberFunctionsTuple!(A, "receive").length > 0,
            "Actor must have a receive method.");

    auto imports = ImportBuilder()
            .put("std.typecons", "Tuple", "_act_Tuple")
            .put("sumtype", "SumType");

    auto sumt = GenericTypeBuilder!"alias Message=SumType"();
    foreach (func; MemberFunctionsTuple!(A, "receive")) {
        assert(Parameters!func.length > 0,
                "Empty receive() parameter list is not allowed.");

        auto tup = GenericTypeBuilder!"_act_Tuple"();
        foreach (param; Parameters!func) {
            static if (isBuiltinType!param) {
                tup.put(param.stringof);
            } else {
                tup.put("_act_" ~ param.stringof);
                imports.put(
                        moduleName!param,
                        param.stringof,
                        "_act_" ~ param.stringof);
            }
        }
        sumt.put(tup.code);
    }
    return imports.code ~ sumt.code ~ `;`;
}

struct ImportBuilder {
    auto put(string moduleFqdn, string type, string alias_ = "") {
        code ~= ("import " ~ moduleFqdn ~ ":" ~ alias_ ~
                (alias_.length ? "=" : "") ~ type ~ ";");
        return this;
    }
    string code;
}

struct GenericTypeBuilder(string name) {
    void put(string memberType) {
        _code ~= memberType ~ ",";
    }

    @property
    string code() { return _code[0..$-1] ~ ")"; }

    private string _code = name ~ "!(";
}
