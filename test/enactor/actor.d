module test.enactor.actor;

import std.conv : text;
import enactor.actor;
import enactor.trace;

// Message declarations must be visible to / importable by enactor.
struct IntMessage { int a; }

@("Actors receive passed messages")
unittest {
    auto m = new MainActor();

    class A {
        mixin Actor;

        int val;
        void receive(IntMessage msg) {
            val = msg.a;
            send("main", Application.ExitSuccess);
        }
    }

    auto a = new A();
    register("a", a);
    send(a, IntMessage(5));
    m.start();
    assert(a.val == 5);
}

@("Pass message to actor via address")
unittest {
    auto m = new MainActor();

    class A {
        mixin Actor;

        int val;
        void receive(IntMessage msg) {
            val = msg.a;
            send("main", Application.ExitSuccess);
        }
    }

    auto a = new A();
    register("myname", a);
    send("myname", IntMessage(5));
    m.start();
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
            send("main", Application.ExitSuccess);
        }
    }

    auto a = new A();
    register("myname", a);
    send(a, 5, "my message");
    m.start();
    assert(a.val == 5);
    assert(a.message == "my message");
}

@("MainActor runs until told to stop")
unittest {
    auto m = new MainActor();

    class Act {
        mixin Actor;
        this(string other) {
            this.other = other;
        }

        void receive(int j) {
            trace(j);
            i += j;
            send(other, i);
            if (i > 10) send("main", Application.ExitSuccess);
        }

        private:

        int i = 0;
        string other;
    }

    auto a = new Act("b");
    auto b = new Act("a");
    register("a", a);
    register("b", b);
    send("a", 1);
    m.start();

    assert(a.i == 13);
    assert(b.i == 21);
}

/+
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
+/
