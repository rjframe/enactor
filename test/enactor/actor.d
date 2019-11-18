module test.enactor.actor;

import enactor.actor;
import std.conv : text;

// Message declarations must be visible to / importable by enactor.
struct IntMessage { int a; }

@("Actors receive passed messages")
unittest {
    auto m = new MainActor();

    class A {
        mixin Actor;

        int val;
        void receive(IntMessage msg) { val = msg.a; }
    }

    auto a = new A();
    send(a, IntMessage(5));
    m.receive(a);
    assert(a.val == 5);
}

@("Pass message to actor via address")
unittest {
    auto m = new MainActor();

    class A {
        mixin Actor;

        int val;
        void receive(IntMessage msg) { val = msg.a; }
    }

    auto a = new A();
    register("myname", a);
    send("myname", IntMessage(5));
    m.receive(a);
    assert(a.val == 5);
}

@("Messages can be complex")
unittest {
    auto m = new MainActor();

    class A {
        mixin Actor;

        int val;
        string message;
        void receive(int code, string msg) {
            val = code;
            message = msg;
        }
    }

    auto a = new A();
    register("myname", a);
    send(a, 5, "my message");
    m.receive(a);
    assert(a.val == 5);
    assert(a.message == "my message");
}

@("Supervise can manage actors")
unittest {
    class S {
        mixin Supervisor;

        void receive(int msg) {}
    }
    int started = 0;

    class A {
        mixin Actor;

        this() { ++started; }
        void receive(int msg) { throw new Exception("Oh no!"); }
    }

    auto s = new S();
    // TODO: something like:
    //auto actor = s.supervise(new A(), Supervise.RestartOnFail);

    //assert(started == 1);
    //send(actor, 5);
    //assert(started == 2);
}
