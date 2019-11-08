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

    private ActorCtx!(typeof(this)) _act_ctx = ActorCtx!(typeof(this))();
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

void send(A, M...)(A actor, M message) {
    assert(0, "Still need to implement send(actor, message...) function.");
}

ref A register(A)(string address, ref return scope A actor) {
    assert(0, "Still need to implement register(address, actor) function.");
    //return actor;
}

struct ActorCtx(A) {
    private:
    Mailbox!A mailbox;
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

private string GenMessage(A)() {
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
